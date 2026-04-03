import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/image_post_processor.dart';
import '../../../camera/domain/models/dietary_modifier.dart';
import '../../data/gemini_service.dart';
import '../../data/recipe_repository.dart';
import '../../domain/models/recipe_result.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  if (apiKey.isEmpty) {
    throw StateError(
      'GEMINI_API_KEY not set. Pass via --dart-define=GEMINI_API_KEY=<key>',
    );
  }
  return GeminiService(apiKey: apiKey);
});

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository();
});

// ── State ─────────────────────────────────────────────────────────

sealed class RecipeState {
  const RecipeState();
}

class RecipeLoading extends RecipeState {
  const RecipeLoading();
}

class RecipeError extends RecipeState {
  const RecipeError(this.message);
  final String message;
}

/// The image wasn't food — carries a witty message from the model.
class RecipeNotFood extends RecipeState {
  const RecipeNotFood(this.message);
  final String message;
}

class RecipeSuccess extends RecipeState {
  const RecipeSuccess(this.recipe, {this.dishImage, this.gridImage, this.featuredIndices});
  final RecipeResult recipe;
  final Uint8List? dishImage;
  final Uint8List? gridImage;
  /// Indices into recipe.ingredients that have sprites in the grid image.
  final List<int>? featuredIndices;
}

// ── Notifier ──────────────────────────────────────────────────────

class RecipeNotifier extends StateNotifier<RecipeState> {
  RecipeNotifier(this._service, this._repository)
      : super(const RecipeLoading());

  final GeminiService _service;
  final RecipeRepository _repository;

  /// Full pipeline: text first → auto-save → images load async → update save.
  Future<void> generate({
    required Uint8List imageBytes,
    required DietaryModifier modifier,
  }) async {
    state = const RecipeLoading();

    // Call 1: Get recipe text (fast).
    RecipeResult recipe;
    try {
      recipe = await _service.generateRecipe(
        imageBytes: imageBytes,
        modifier: modifier,
      );
    } on NotFoodException catch (e) {
      state = RecipeNotFood(e.message);
      return;
    } catch (e) {
      state = RecipeError(e.toString());
      return;
    }

    // Auto-save immediately with text only.
    try {
      recipe = await _repository.save(recipe, imageBytes);
    } catch (_) {
      // Save failure shouldn't block the UI.
    }

    // Compute which ingredients get sprites.
    final featured = GeminiService.featuredIndices(recipe.ingredients);

    // Show recipe text immediately while image generates.
    state = RecipeSuccess(recipe, featuredIndices: featured);

    // Call 2: Separate dish hero + ingredient grid images.
    Uint8List? dishImage;
    Uint8List? gridImage;
    try {
      final (dish, grid) = await _service.generateRecipeIllustration(recipe);
      if (dish != null) dishImage = await ImagePostProcessor.fixBackground(dish);
      if (grid != null) gridImage = await ImagePostProcessor.fixBackground(grid);
    } catch (_) {}

    // Re-save with images now included.
    if (dishImage != null || gridImage != null) {
      try {
        // Delete the text-only save, re-save with images.
        await _repository.delete(recipe);
        recipe = await _repository.save(
          recipe,
          imageBytes,
          dishImage: dishImage,
          gridImage: gridImage,
        );
      } catch (_) {}
    }

    // Update state with images.
    if (mounted) {
      state = RecipeSuccess(recipe, dishImage: dishImage, gridImage: gridImage, featuredIndices: featured);
    }
  }

  /// Toggle pin on the current recipe.
  Future<void> togglePin() async {
    final current = state;
    if (current is! RecipeSuccess) return;
    try {
      final updated = await _repository.togglePin(current.recipe);
      state = RecipeSuccess(
        updated,
        dishImage: current.dishImage,
        gridImage: current.gridImage,
        featuredIndices: current.featuredIndices,
      );
    } catch (_) {}
  }
}

final recipeNotifierProvider =
    StateNotifierProvider<RecipeNotifier, RecipeState>((ref) {
  final service = ref.watch(geminiServiceProvider);
  final repository = ref.watch(recipeRepositoryProvider);
  return RecipeNotifier(service, repository);
});
