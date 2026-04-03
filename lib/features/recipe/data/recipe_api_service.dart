import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/models/recipe_result.dart';

/// Thrown when the image doesn't contain food.
class NotFoodException implements Exception {
  NotFoodException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when the user has no credits remaining.
class NoCreditsException implements Exception {
  const NoCreditsException();
  @override
  String toString() => 'No credits remaining.';
}

/// Result bundle from the backend generation endpoint.
class GenerationResult {
  const GenerationResult({
    required this.recipe,
    this.dishImage,
    this.gridImage,
    this.featuredIndices,
  });

  final RecipeResult recipe;
  final Uint8List? dishImage;
  final Uint8List? gridImage;
  final List<int>? featuredIndices;
}

/// HTTP client for the generate_recipe Cloud Function.
///
/// Replaces direct Gemini SDK calls — the API key lives on the server.
class RecipeApiService {
  RecipeApiService({required this.functionUrl});

  final String functionUrl;

  /// Send a photo to the backend for recipe generation.
  ///
  /// Throws [NoCreditsException] if the user is out of credits.
  /// Throws [NotFoodException] if the image isn't food.
  Future<GenerationResult> generateRecipe({
    required Uint8List imageBytes,
    required String modifier,
    required String idToken,
  }) async {
    final response = await http.post(
      Uri.parse(functionUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'photo': base64Encode(imageBytes),
        'modifier': modifier,
      }),
    );

    if (response.statusCode == 403) {
      throw const NoCreditsException();
    }

    if (response.statusCode == 401) {
      throw Exception('Authentication failed. Please restart the app.');
    }

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? body['error'] ?? 'Generation failed.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // Check for not-food response.
    final recipeJson = json['recipe'] as Map<String, dynamic>;
    if (recipeJson['notFood'] == true) {
      final message =
          recipeJson['message'] as String? ?? "That doesn't look like food!";
      throw NotFoodException(message);
    }

    final recipe = RecipeResult.fromJson(recipeJson);

    // Decode base64 images if present.
    Uint8List? dishImage;
    Uint8List? gridImage;
    final dishB64 = json['dishImage'] as String?;
    final gridB64 = json['gridImage'] as String?;
    if (dishB64 != null) dishImage = base64Decode(dishB64);
    if (gridB64 != null) gridImage = base64Decode(gridB64);

    final featuredRaw = json['featuredIndices'] as List<dynamic>?;
    final featured = featuredRaw?.cast<int>();

    return GenerationResult(
      recipe: recipe,
      dishImage: dishImage,
      gridImage: gridImage,
      featuredIndices: featured,
    );
  }
}
