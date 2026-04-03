import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/image_post_processor.dart';
import '../../../camera/domain/models/dietary_modifier.dart';
import '../../data/recipe_api_service.dart';
import '../../data/recipe_repository.dart';
import '../../domain/models/recipe_result.dart';

final recipeApiServiceProvider = Provider<RecipeApiService>((ref) {
  const functionUrl = String.fromEnvironment('FUNCTION_URL');
  if (functionUrl.isEmpty) {
    throw StateError(
      'FUNCTION_URL not set. Pass via --dart-define=FUNCTION_URL=<url>',
    );
  }
  return RecipeApiService(functionUrl: functionUrl);
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
  const RecipeSuccess(this.recipe,
      {this.dishImage, this.gridImage, this.featuredIndices});
  final RecipeResult recipe;
  final Uint8List? dishImage;
  final Uint8List? gridImage;

  /// Indices into recipe.ingredients that have sprites in the grid image.
  final List<int>? featuredIndices;
}

// ── Notifier ──────────────────────────────────────────────────────

class RecipeNotifier extends StateNotifier<RecipeState> {
  RecipeNotifier(this._apiService, this._repository)
      : super(const RecipeLoading());

  final RecipeApiService _apiService;
  final RecipeRepository _repository;

  /// Full pipeline: call backend → save locally.
  Future<void> generate({
    required Uint8List imageBytes,
    required DietaryModifier modifier,
  }) async {
    state = const RecipeLoading();

    // Get Firebase ID token for backend auth.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = const RecipeError('Not authenticated. Please restart the app.');
      return;
    }

    final idToken = await user.getIdToken();
    if (idToken == null) {
      state = const RecipeError('Failed to get auth token.');
      return;
    }

    // Single backend call returns recipe + images.
    GenerationResult result;
    try {
      result = await _apiService.generateRecipe(
        imageBytes: imageBytes,
        modifier: modifier.label,
        idToken: idToken,
      );
    } on NotFoodException catch (e) {
      state = RecipeNotFood(e.message);
      return;
    } on NoCreditsException {
      state = const RecipeError('no_credits');
      return;
    } catch (e) {
      state = RecipeError(e.toString());
      return;
    }

    var recipe = result.recipe;

    // Post-process illustration backgrounds.
    Uint8List? dishImage = result.dishImage;
    Uint8List? gridImage = result.gridImage;
    if (dishImage != null) {
      dishImage = await ImagePostProcessor.fixBackground(dishImage);
    }
    if (gridImage != null) {
      gridImage = await ImagePostProcessor.fixBackground(gridImage);
    }

    // Auto-save with images.
    try {
      recipe = await _repository.save(
        recipe,
        imageBytes,
        dishImage: dishImage,
        gridImage: gridImage,
      );
    } catch (_) {
      // Save failure shouldn't block the UI.
    }

    if (mounted) {
      state = RecipeSuccess(
        recipe,
        dishImage: dishImage,
        gridImage: gridImage,
        featuredIndices: result.featuredIndices,
      );
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
  final apiService = ref.watch(recipeApiServiceProvider);
  final repository = ref.watch(recipeRepositoryProvider);
  return RecipeNotifier(apiService, repository);
});
