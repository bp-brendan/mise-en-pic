import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// REST client for Imagen 4 Fast image generation.
///
/// Uses the `:predict` endpoint on Google AI, which is significantly cheaper
/// than Gemini's native image generation (no thinking-token overhead).
class GeminiImageClient {
  GeminiImageClient({required this.apiKey});

  final String apiKey;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _model = 'imagen-4.0-fast-generate-001';

  /// Generate an image from a text prompt.
  ///
  /// [aspectRatio] defaults to `"1:1"`. Supported values:
  /// `"1:1"`, `"3:4"`, `"4:3"`, `"9:16"`, `"16:9"`.
  ///
  /// Returns the raw PNG bytes of the generated image, or null on failure.
  Future<Uint8List?> generateImage({
    required String prompt,
    String? systemInstruction, // ignored — Imagen has no system instruction
    String aspectRatio = '1:1',
  }) async {
    final url = Uri.parse('$_baseUrl/$_model:predict?key=$apiKey');

    final body = {
      'instances': [
        {'prompt': prompt},
      ],
      'parameters': {
        'sampleCount': 1,
        'aspectRatio': aspectRatio,
        'personGeneration': 'dont_allow',
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Imagen API error ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final predictions = json['predictions'] as List<dynamic>?;
    if (predictions == null || predictions.isEmpty) return null;

    final data =
        predictions[0]['bytesBase64Encoded'] as String?;
    if (data == null) return null;

    return base64Decode(data);
  }
}
