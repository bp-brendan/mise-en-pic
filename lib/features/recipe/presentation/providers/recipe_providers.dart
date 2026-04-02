import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../camera/domain/models/dietary_modifier.dart';
import '../../data/gemini_service.dart' as svc;

/// Provides the [svc.GeminiService] singleton.
///
/// The API key should be supplied at app startup via a provider override
/// or environment variable.
final geminiServiceProvider = Provider<svc.GeminiService>((ref) {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  if (apiKey.isEmpty) {
    throw StateError(
      'GEMINI_API_KEY not set. Pass it via --dart-define=GEMINI_API_KEY=<key>',
    );
  }
  return svc.GeminiService(apiKey: apiKey);
});

/// The async state for a recipe generation request.
sealed class RecipeState {
  const RecipeState();

  T when<T>({
    required T Function() loading,
    required T Function(String message) error,
    required T Function(String markdown) success,
  }) {
    return switch (this) {
      RecipeLoading() => loading(),
      RecipeError(message: final m) => error(m),
      RecipeSuccess(markdown: final md) => success(md),
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
  const RecipeSuccess(this.markdown);
  final String markdown;
}

/// Notifier that drives the recipe generation flow.
class RecipeNotifier extends StateNotifier<RecipeState> {
  RecipeNotifier(this._service) : super(const RecipeLoading());

  final svc.GeminiService _service;

  Future<void> generate({
    required Uint8List imageBytes,
    required DietaryModifier modifier,
  }) async {
    state = const RecipeLoading();
    try {
      // Map our UI enum to the service's enum.
      final svcModifier = svc.DietaryModifier.values.firstWhere(
        (m) => m.name == modifier.name,
      );
      final markdown = await _service.generateRecipe(
        imageBytes: imageBytes,
        modifier: svcModifier,
      );
      state = RecipeSuccess(markdown);
    } catch (e) {
      state = RecipeError(e.toString());
    }
  }
}

final recipeNotifierProvider =
    StateNotifierProvider<RecipeNotifier, RecipeState>((ref) {
  final service = ref.watch(geminiServiceProvider);
  return RecipeNotifier(service);
});
