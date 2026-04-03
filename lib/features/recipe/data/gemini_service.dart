import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_generative_ai/google_generative_ai.dart';

import '../domain/models/recipe_result.dart';
import '../../camera/domain/models/dietary_modifier.dart';
import 'gemini_image_client.dart';

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

  // ── Style anchor (shared across all image prompts) ────────────
  // Background color must match CookbookPalette.lightBackground (#E8EFE6)
  // so illustrations blend seamlessly onto the app page.
  static const _bgColor = '#E8EFE6';

  static const _styleAnchor =
      'Hand-painted watercolor and ink illustration style, like a personal '
      'culinary sketchbook or illustrated recipe journal. Bold confident ink '
      'outlines with vibrant saturated watercolor fills. Slightly naive, '
      'charming, folk-art quality — each item has personality and character. '
      'Warm, inviting colors. FLAT SOLID BACKGROUND COLOR: exactly $_bgColor '
      '(a muted sage green). Fill the entire background with this single flat '
      'color — no paper texture, no shadows, no checkerboard, no white. '
      'NO photorealism, NO 3D rendering, NO flat vector art, NO digital look, '
      'NO gradients. Think hand-painted gouache and ink recipe zine.';

  // ── Text pipeline prompt ──────────────────────────────────────
  static const _textSystemPrompt =
      'You identify food items from photos and return structured JSON recipes. '
      'IMPORTANT: Create a recipe FOR the item shown — not a recipe that uses '
      'it as an ingredient. A photo of hot sauce means a hot sauce recipe. '
      'A photo of bread means a bread recipe. A plated dish means that dish. '
      'Be as SPECIFIC as possible about what you see. Try to identify the '
      'exact dish, cuisine, and preparation style. If you can tell it\'s pad '
      'thai vs lo mein, say so. If it looks like a specific regional variant, '
      'name it. Favor giving your best specific match over a vague generic '
      'guess — but always give a recipe, never refuse. '
      'NEVER use brand names — generalize everything. '
      'Give dishes fun, evocative names. '
      'For each ingredient, include a brief visual description of its raw '
      'state (e.g. "halved, showing rings" for an onion). '
      'Write in the style of Julia Child: precise, sensory, warm. '
      'Method steps should be numbered, concise (1-2 lines each), and '
      'action-oriented. Include sensory cues (color, sound, smell) and brief '
      'WHY explanations inline. Aim for 10-16 steps. Think handwritten recipe '
      'card — punchy, not paragraphs.';

  /// Call 1: Analyze photo → structured recipe JSON.
  Future<RecipeResult> generateRecipe({
    required Uint8List imageBytes,
    required DietaryModifier modifier,
  }) async {
    final prompt = TextPart(
      'Look at this photo carefully and identify the SPECIFIC food or dish '
      'shown. Be as precise as possible — identify the exact dish, cuisine, '
      'and preparation style. Then create a recipe FOR THAT EXACT ITEM — '
      'not a recipe that merely uses it as an ingredient. If the photo shows '
      'hot sauce, give me a hot sauce recipe. If it shows bread, give me a '
      'bread recipe. If it shows a plated dish, give me that dish\'s recipe. '
      'Always give your best specific match — never refuse.\n'
      'Diet: ${modifier.label}.\n'
      'Return JSON: {"dishName":"CAPS NAME","tagline":"one line",'
      '"prepTime":"20 min","cookTime":"35 min","servings":"4",'
      '"ingredients":[{"emoji":"🧈","amount":"2 tbsp","name":"unsalted butter",'
      '"visual":"a golden slab, slightly soft"}],'
      '"method":"1. First step... 2. Second step..."}\n'
      '8-15 ingredients with exact amounts. Include prepTime, cookTime, and '
      'servings. Method: a single string of 10-16 numbered steps, each 1-2 '
      'lines max. Concise and action-oriented with inline sensory cues. '
      'Reference specific ingredient names in each step so they can be '
      'linked. Adjust all for ${modifier.label} diet.',
    );

    // Downscale for API — saves input tokens while display stays crisp.
    final smallBytes = await _downscaleJpeg(imageBytes, maxDimension: 768);
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

    final json = jsonDecode(text) as Map<String, dynamic>;
    json['modifier'] = modifier.name;

    return RecipeResult.fromJson(json);
  }

  /// Call 2a: Generate watercolor illustration of the finished dish.
  Future<Uint8List?> generateDishIllustration(RecipeResult recipe) async {
    // Include key ingredients so the dish illustration is visually coherent
    // with the ingredient sprites.
    final keyIngredients = recipe.ingredients
        .take(6)
        .map((ing) => ing.name)
        .join(', ');

    final prompt =
        'Illustrate "${recipe.dishName}": ${recipe.tagline}. '
        'Key ingredients visible: $keyIngredients. '
        'Show the completed dish in a bold, vibrant, slightly naive style — '
        'like a hand-painted recipe journal page. The dish should be in a '
        'colorful bowl or plate, viewed from a slight angle. Confident thick '
        'ink outlines, saturated watercolor/gouache fills, warm and inviting. '
        'The dish should look delicious and have personality. '
        'Background must be FLAT SOLID $_bgColor (muted sage green) — '
        'no texture, no shadows, no other colors in the background area. '
        '$_styleAnchor';

    return _imageClient.generateImage(
      prompt: prompt,
      systemInstruction:
          'You are an illustrator for a personal hand-painted recipe journal. '
          'Bold ink outlines, vibrant gouache/watercolor fills, charming and '
          'slightly naive folk-art style. The ENTIRE background must be filled '
          'with flat solid color $_bgColor (muted sage green). '
          'No text, no labels, no words — just the dish illustration.',
    );
  }

  /// Grid layout: 4 columns, rows as needed.
  static const gridColumns = 4;

  /// Call 2b: Generate a strict grid of ingredient illustrations (sprite sheet).
  Future<Uint8List?> generateIngredientsGrid(RecipeResult recipe) async {
    final n = recipe.ingredients.length;
    final rows = (n / gridColumns).ceil();

    // Build a numbered list so the model places them in order.
    final numberedList = recipe.ingredients.asMap().entries.map((e) {
      final i = e.key + 1;
      final ing = e.value;
      final visual = ing.visual.isNotEmpty ? ' (${ing.visual})' : '';
      return '$i. ${ing.name}$visual';
    }).join('\n');

    final prompt =
        'Create a sprite sheet of ingredient illustrations for the recipe '
        '"${recipe.dishName}". Arrange them in a STRICT $gridColumns-column '
        'by $rows-row grid. Each cell is the same size. Place exactly one '
        'ingredient per cell, in this order (left to right, top to bottom):\n'
        '$numberedList\n\n'
        'REQUIREMENTS:\n'
        '- Each ingredient CENTERED in its cell, large and filling most of '
        'the cell space.\n'
        '- NO labels, NO text, NO numbers — just the illustrations.\n'
        '- Even spacing, uniform cell sizes, clean separation between cells.\n'
        '- If there are fewer items than cells in the last row, leave the '
        'remaining cells empty (filled with $_bgColor).\n'
        '- ENTIRE background must be flat solid $_bgColor (muted sage green).\n'
        '- Use the SAME illustration style you would use for the finished '
        'dish — these ingredients should look like they belong together.\n'
        '$_styleAnchor';

    return _imageClient.generateImage(
      prompt: prompt,
      systemInstruction:
          'You are an illustrator creating a sprite sheet for a recipe app. '
          'Bold ink outlines, vibrant gouache/watercolor fills, charming and '
          'slightly naive folk-art style. Each ingredient must be large, '
          'centered in its grid cell, and clearly recognizable. '
          'ENTIRE background must be flat solid color $_bgColor (muted sage '
          'green). NO text or labels anywhere.',
    );
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
