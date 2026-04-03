import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models/recipe_result.dart';
import '../../camera/domain/models/dietary_modifier.dart';
import 'gemini_image_client.dart';

/// Thrown when the image doesn't contain food.
class NotFoodException implements Exception {
  NotFoodException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Two-call pipeline:
///   1. Text call (SDK) — recipe JSON from photo analysis.
///   2. Image call (REST) — watercolor illustrations of dish + ingredients.
class GeminiService {
  GeminiService({required String apiKey})
      : _textModel = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system(_textSystemPrompt),
          generationConfig: GenerationConfig(
            temperature: 0.5,
            maxOutputTokens: 4096,
            responseMimeType: 'application/json',
          ),
        ),
        _imageClient = GeminiImageClient(apiKey: apiKey);

  final GenerativeModel _textModel;
  final GeminiImageClient _imageClient;

  // ── Style constants ────────────────────────────────────────────
  static const _bgColor = '#E8EFE6';

  /// Pantry staples that don't need a sprite illustration.
  static const _staples = {
    'salt', 'pepper', 'black pepper', 'oil', 'olive oil', 'vegetable oil',
    'canola oil', 'cooking oil', 'water', 'ice', 'flour', 'all-purpose flour',
    'sugar', 'granulated sugar', 'brown sugar', 'butter', 'unsalted butter',
    'garlic', 'kosher salt', 'sea salt', 'cornstarch', 'baking powder',
    'baking soda',
  };

  /// Returns indices of ingredients worth illustrating (non-staples, max 6).
  static List<int> featuredIndices(List<Ingredient> ingredients) {
    final indices = <int>[];
    for (var i = 0; i < ingredients.length; i++) {
      final name = ingredients[i].name.toLowerCase().trim();
      if (!_staples.contains(name)) indices.add(i);
      if (indices.length >= 6) break;
    }
    return indices;
  }

  // ── Text pipeline prompt ──────────────────────────────────────
  static const _textSystemPrompt =
      'You identify food from photos and return structured JSON recipes.\n'
      'NOT FOOD? Return ONLY: {"notFood":true,"message":"<witty one-liner>"}.\n'
      'IS FOOD: Create a recipe FOR the item shown (hot sauce→hot sauce recipe, '
      'bread→bread recipe). Be specific — name the exact dish, cuisine, variant. '
      'Never refuse. No brand names. Give fun, evocative dish names.\n'
      'Each ingredient: short visual tag (2-4 words, e.g. "golden slab, soft"). '
      'Julia Child style: precise, warm. '
      '8-10 method steps, 1 line each, action-oriented with sensory cues.';

  /// Call 1: Analyze photo → structured recipe JSON.
  Future<RecipeResult> generateRecipe({
    required Uint8List imageBytes,
    required DietaryModifier modifier,
  }) async {
    final prompt = TextPart(
      'Identify the specific food/dish and create a recipe for it.\n'
      'Diet: ${modifier.label}.\n'
      'JSON: {"dishName":"CAPS NAME","tagline":"one line",'
      '"prepTime":"20 min","cookTime":"35 min","servings":"4",'
      '"caloriesPerServing":450,'
      '"ingredients":[{"emoji":"🧈","amount":"2 tbsp","name":"unsalted butter",'
      '"visual":"golden, soft"}],'
      '"method":"1. Step... 2. Step..."}\n'
      'Keep visuals to 2-4 words. Method steps: 1 line max.\n'
      '8-15 ingredients. 8-10 method steps. Adjust for ${modifier.label} diet.',
    );

    // Downscale for API — 512px is enough to identify dishes.
    final smallBytes = await _downscaleJpeg(imageBytes, maxDimension: 512);
    // _downscaleJpeg returns PNG when it resizes, original JPEG otherwise.
    final mimeType = smallBytes == imageBytes ? 'image/jpeg' : 'image/png';
    final image = DataPart(mimeType, smallBytes);

    final response = await _textModel.generateContent([
      Content.multi([prompt, image]),
    ]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw GenerativeAIException('Empty response from model.');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw GenerativeAIException('Invalid JSON from model: $e');
    }

    // Check if the model determined this isn't food.
    if (json['notFood'] == true) {
      final message = json['message'] as String? ?? 'That doesn\'t look like food!';
      throw NotFoodException(message);
    }

    json['modifier'] = modifier.name;

    return RecipeResult.fromJson(json);
  }

  /// Grid layout: 4 columns for ingredient sprites (used by UI).
  static const gridColumns = 4;

  // ── Illustration cache ──────────────────────────────────────────
  static Future<Directory> _cacheDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/illustration_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _slug(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  /// Check the cache for a previously generated illustration.
  static Future<Uint8List?> _loadCached(String key) async {
    final file = File('${(await _cacheDir()).path}/$key.png');
    if (await file.exists()) return file.readAsBytes();
    return null;
  }

  /// Save an illustration to the cache.
  static Future<void> _saveToCache(String key, Uint8List bytes) async {
    final file = File('${(await _cacheDir()).path}/$key.png');
    await file.writeAsBytes(bytes);
  }

  /// Generate dish hero and ingredient grid as separate images.
  /// Returns (dishImage, gridImage). Either may be null on failure.
  Future<(Uint8List?, Uint8List?)> generateRecipeIllustration(
      RecipeResult recipe) async {
    final slug = _slug(recipe.dishName);
    final featured = featuredIndices(recipe.ingredients);

    // Check cache first.
    final cachedDish = await _loadCached('${slug}_dish');
    final cachedGrid = await _loadCached('${slug}_grid');
    if (cachedDish != null && cachedGrid != null) {
      return (cachedDish, cachedGrid);
    }

    // Build ingredient names for the grid prompt.
    final ingredientNames =
        featured.map((i) => recipe.ingredients[i].name).join(', ');

    // Generate both images in parallel.
    final results = await Future.wait([
      if (cachedDish == null)
        _imageClient.generateImage(
          prompt:
              'Watercolor & ink illustration of "${recipe.dishName}": '
              'the finished dish, vibrant and appetizing, centered on a '
              'solid $_bgColor background. Bold ink outlines, gouache '
              'watercolor fills, charming folk-art recipe-journal style. '
              'No text, no borders, no photorealism.',
        )
      else
        Future.value(cachedDish),
      if (cachedGrid == null)
        _imageClient.generateImage(
          prompt:
              'Watercolor & ink ingredient sprites on solid $_bgColor '
              'background: $ingredientNames. Each ingredient drawn separately '
              'with space between them, arranged in a loose grid. Bold ink '
              'outlines, gouache fills, folk-art recipe-journal style. '
              'No text, no labels, no borders, no photorealism.',
        )
      else
        Future.value(cachedGrid),
    ]);

    final dishImage = results[0];
    final gridImage = results[1];

    // Cache successful results.
    if (dishImage != null) await _saveToCache('${slug}_dish', dishImage);
    if (gridImage != null) await _saveToCache('${slug}_grid', gridImage);

    return (dishImage, gridImage);
  }

  /// Downscale a JPEG so its longest side is at most [maxDimension].
  /// Returns the original bytes if already small enough.
  static Future<Uint8List> _downscaleJpeg(
    Uint8List bytes, {
    required int maxDimension,
  }) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final w = image.width;
    final h = image.height;
    if (w <= maxDimension && h <= maxDimension) return bytes;

    final scale = maxDimension / (w > h ? w : h);
    final targetW = (w * scale).round();
    final targetH = (h * scale).round();

    final resized = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final resizedFrame = await resized.getNextFrame();
    final byteData = await resizedFrame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }
}
