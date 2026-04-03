import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Direct REST client for Gemini image generation.
///
/// The Dart `google_generative_ai` SDK (v0.4.x) does not expose
/// `responseModalities`, so we call the REST API directly for image output.
class GeminiImageClient {
  GeminiImageClient({required this.apiKey});

  final String apiKey;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _model = 'gemini-2.5-flash-image';

  /// Generate an image from a text prompt.
  ///
  /// Returns the raw PNG/JPEG bytes of the generated image, or null if
  /// the model returned no image.
  Future<Uint8List?> generateImage({
    required String prompt,
    String? systemInstruction,
  }) async {
    final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');

    final body = <String, dynamic>{
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['IMAGE', 'TEXT'],
        'temperature': 0.8,
        'maxOutputTokens': 4096,
      },
    };

    if (systemInstruction != null) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemInstruction},
        ],
      };
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini image API error ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null) return null;

    // Find the first inline image part.
    for (final part in parts) {
      final inlineData = part['inlineData'] as Map<String, dynamic>?;
      if (inlineData != null) {
        final data = inlineData['data'] as String?;
        if (data != null) {
          return base64Decode(data);
        }
      }
    }

    return null;
  }
}
