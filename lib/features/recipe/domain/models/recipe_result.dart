import 'dart:typed_data';

import '../../../camera/domain/models/dietary_modifier.dart';

/// The result of a Gemini recipe generation request.
class RecipeResult {
  const RecipeResult({
    required this.imageBytes,
    required this.modifier,
    required this.markdown,
  });

  final Uint8List imageBytes;
  final DietaryModifier modifier;
  final String markdown;
}
