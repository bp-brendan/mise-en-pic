import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  T when<T>({
    required T Function() loading,
    required T Function(String message) error,
    required T Function(RecipeResult recipe, Uint8List? dishImage,
            Uint8List? gridImage)
        success,
  }) {
    return switch (this) {
      RecipeLoading() => loading(),
      RecipeError(message: final m) => error(m),
      RecipeSuccess(
        recipe: final r,
        dishImage: final d,
        gridImage: final g,
      ) =>
        success(r, d, g),
    };
  }
}

class RecipeLoading extends RecipeState {
  const RecipeLoading();
}

class RecipeError extends RecipeState {
  const RecipeError(this.message);
  final String message;
}

class RecipeSuccess extends RecipeState {
  const RecipeSuccess(this.recipe, {this.dishImage, this.gridImage});
  final RecipeResult recipe;
  final Uint8List? dishImage;
  final Uint8List? gridImage;
}

// ── Notifier ──────────────────────────────────────────────────────

class RecipeNotifier extends StateNotifier<RecipeState> {
  RecipeNotifier(this._service, this._repository)
      : super(const RecipeLoading());

  final GeminiService _service;
  final RecipeRepository _repository;

  /// Full pipeline: text first (shows immediately), then images load async.
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
    } catch (e) {
      state = RecipeError(e.toString());
      return;
    }

    // Show recipe text immediately while images generate.
    state = RecipeSuccess(recipe);

    // Call 2: Generate illustrations in parallel.
    final results = await Future.wait([
      _service.generateDishIllustration(recipe).catchError((_) => null),
      _service.generateIngredientsGrid(recipe).catchError((_) => null),
    ]);

    final dishImage = results[0];
    final gridImage = results[1];

    // Update state with images.
    if (mounted) {
      state = RecipeSuccess(recipe, dishImage: dishImage, gridImage: gridImage);
    }
  }

  /// Save the current recipe with all assets.
  Future<bool> save(Uint8List photoBytes) async {
    final current = state;
    if (current is! RecipeSuccess) return false;
    try {
      final updated = await _repository.save(
        current.recipe,
        photoBytes,
        dishImage: current.dishImage,
        gridImage: current.gridImage,
      );
      state = RecipeSuccess(
        updated,
        dishImage: current.dishImage,
        gridImage: current.gridImage,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final recipeNotifierProvider =
    StateNotifierProvider<RecipeNotifier, RecipeState>((ref) {
  final service = ref.watch(geminiServiceProvider);
  final repository = ref.watch(recipeRepositoryProvider);
  return RecipeNotifier(service, repository);
});
