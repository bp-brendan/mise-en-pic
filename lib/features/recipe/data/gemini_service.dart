import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

/// Dietary modifiers that adjust how Gemini interprets and reformulates
/// the recipe for the photographed dish.
enum DietaryModifier {
  standard('Standard'),
  vegan('Vegan'),
  glutenFree('Gluten-Free'),
  healthier('Healthier');

  const DietaryModifier(this.label);
  final String label;
}

/// Isolated service for communicating with the Gemini 1.5 Flash model.
///
/// Accepts raw JPEG bytes from the camera and a [DietaryModifier], then
/// returns a Markdown-formatted recipe string.
class GeminiService {
  GeminiService({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system(_systemPrompt),
          generationConfig: GenerationConfig(
            temperature: 0.4,
            maxOutputTokens: 2048,
          ),
        );

  final GenerativeModel _model;

  static const _systemPrompt =
      'You are an expert culinary assistant and master chef. '
      'Analyze provided images of food and produce structured recipes.';

  /// Sends [imageBytes] (JPEG) to Gemini with the selected [modifier] and
  /// returns the model's Markdown response.
  ///
  /// Throws [GenerativeAIException] on API errors.
  Future<String> generateRecipe({
    required Uint8List imageBytes,
    required DietaryModifier modifier,
  }) async {
    final prompt = TextPart(
      'Analyze the provided image of food.\n\n'
      '1. Identify the likely dish and its core macro-ingredients.\n'
      '2. Provide a structured, step-by-step recipe to recreate the dish '
      'from scratch.\n'
      '3. STRICTLY adjust the ingredients, substitutions, and cooking methods '
      'to adhere to the following dietary modifier: ${modifier.label}. '
      'Ensure substitutions (like vegan cheeses or gluten-free binders) are '
      'chemically and structurally sound for cooking.\n\n'
      'Format your output strictly using Markdown headings, bullet points for '
      'ingredients, and numbered lists for instructions.',
    );

    final image = DataPart('image/jpeg', imageBytes);

    final response = await _model.generateContent([
      Content.multi([prompt, image]),
    ]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw GenerativeAIException('Empty response from model.');
    }
    return text;
  }
}
