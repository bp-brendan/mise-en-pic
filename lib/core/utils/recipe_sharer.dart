import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/camera/domain/models/dietary_modifier.dart';
import '../../features/recipe/domain/models/recipe_result.dart';
import '../theme/cookbook_palette.dart';
import '../theme/cookbook_theme.dart';

/// Captures the full recipe as a shareable image and opens the system share
/// sheet. Uses an Overlay-mounted RepaintBoundary for reliable rendering.
class RecipeSharer {
  RecipeSharer._();

  /// Share a recipe as an image. Must be called with a mounted BuildContext.
  static Future<void> share({
    required BuildContext context,
    required RecipeResult recipe,
    Uint8List? dishImage,
    Uint8List? gridImage,
    Uint8List? photoBytes,
  }) async {
    // Resolve images: prefer passed bytes, fall back to saved files.
    dishImage ??= _loadFile(recipe.dishImagePath);
    gridImage ??= _loadFile(recipe.gridImagePath);
    photoBytes ??= _loadFile(recipe.imagePath);

    final imageBytes = await _captureRecipe(
      context: context,
      recipe: recipe,
      dishImage: dishImage,
      gridImage: gridImage,
      photoBytes: photoBytes,
    );

    if (imageBytes == null) return;

    // Write to temp file for sharing.
    final dir = await getTemporaryDirectory();
    final name = recipe.dishName
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    final file = File('${dir.path}/mise_en_pic_$name.png');
    await file.writeAsBytes(imageBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '${recipe.dishName} — made with Mise en Pic',
      ),
    );
  }

  /// Mount the recipe widget in an offscreen Overlay, capture via
  /// RepaintBoundary, then remove. This avoids GPU texture limits that
  /// plague the screenshot package for tall widgets.
  static Future<Uint8List?> _captureRecipe({
    required BuildContext context,
    required RecipeResult recipe,
    Uint8List? dishImage,
    Uint8List? gridImage,
    Uint8List? photoBytes,
  }) async {
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context);

    // Build the shareable widget at a fixed width, positioned offscreen.
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -5000, // offscreen
        top: 0,
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: 700,
            child: _ShareableRecipePage(
              recipe: recipe,
              dishImage: dishImage,
              gridImage: gridImage,
              photoBytes: photoBytes,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Wait for layout + paint.
    await Future.delayed(const Duration(milliseconds: 200));
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Capture at 2x for good quality. The widget is 700 logical px wide,
      // so the output is 1400px — well within GPU limits even for tall recipes.
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  static Uint8List? _loadFile(String? path) {
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytesSync();
  }
}

// ── The full recipe rendered as a single tall widget for capture ──

class _ShareableRecipePage extends StatelessWidget {
  const _ShareableRecipePage({
    required this.recipe,
    this.dishImage,
    this.gridImage,
    this.photoBytes,
  });

  final RecipeResult recipe;
  final Uint8List? dishImage;
  final Uint8List? gridImage;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    const ink = CookbookPalette.lightInk;
    final steps = recipe.steps;

    return Material(
      color: CookbookPalette.lightBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dish illustration or photo
            if (dishImage != null)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: Image.memory(dishImage!, fit: BoxFit.contain),
                ),
              )
            else if (photoBytes != null)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(photoBytes!, fit: BoxFit.cover),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Title
            Center(
              child: Text(
                recipe.dishName,
                textAlign: TextAlign.center,
                style: CookbookTheme.displayStyle(
                  fontSize: 32,
                  fontWeight: 760,
                  color: ink,
                ).copyWith(shadows: CookbookTheme.letterpressShadows(ink)),
              ),
            ),
            if (recipe.tagline.isNotEmpty) ...[
              const SizedBox(height: 5),
              Center(
                child: Text(
                  recipe.tagline,
                  textAlign: TextAlign.center,
                  style: CookbookTheme.bodyStyle(
                    fontSize: 13,
                    fontWeight: 430,
                    color: ink.withValues(alpha: 0.6),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Meta row
            _ShareMetaRow(recipe: recipe),
            const SizedBox(height: 22),

            // Ingredients — compact two-column grid
            _shareSectionLabel('INGREDIENTS'),
            const SizedBox(height: 10),
            _ingredientsGrid(recipe, gridImage),

            const SizedBox(height: 22),

            // Method
            _shareSectionLabel('METHOD'),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) {
              final stepIndex = entry.key;
              final stepText = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${stepIndex + 1}',
                        style: CookbookTheme.displayStyle(
                          fontSize: 24,
                          fontWeight: 760,
                          color: ink.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stepText,
                        style: CookbookTheme.bodyStyle(
                          fontSize: 13,
                          color: ink,
                        ).copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // Watermark
            Center(
              child: Text(
                'Mise en Pic',
                style: CookbookTheme.labelStyle(
                  fontSize: 10,
                  color: ink.withValues(alpha: 0.2),
                  letterSpacing: 4.0,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Two-column ingredient layout to keep the image compact.
  static Widget _ingredientsGrid(RecipeResult recipe, Uint8List? gridImage) {
    final items = recipe.ingredients;
    final rows = <Widget>[];

    for (var i = 0; i < items.length; i += 2) {
      final left = _ingredientCell(items[i], i, items.length, gridImage);
      final right = (i + 1 < items.length)
          ? _ingredientCell(items[i + 1], i + 1, items.length, gridImage)
          : const Expanded(child: SizedBox.shrink());

      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: IntrinsicHeight(
          child: Row(children: [left, const SizedBox(width: 8), right]),
        ),
      ));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  static Widget _ingredientCell(
    Ingredient ing,
    int index,
    int total,
    Uint8List? gridImage,
  ) {
    const ink = CookbookPalette.lightInk;
    return Expanded(
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: gridImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _ShareSpriteCell(
                      gridImage: gridImage,
                      index: index,
                      totalItems: total,
                    ),
                  )
                : Center(
                    child:
                        Text(ing.emoji, style: const TextStyle(fontSize: 22)),
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: CookbookTheme.bodyStyle(fontSize: 12, color: ink),
                children: [
                  TextSpan(
                    text: '${ing.amount} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: ing.name),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _shareSectionLabel(String label) {
    const ink = CookbookPalette.lightInk;
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: ink.withValues(alpha: 0.15),
            thickness: CookbookTheme.strokeWidth,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: CookbookTheme.labelStyle(
              fontSize: 10,
              color: ink.withValues(alpha: 0.4),
              letterSpacing: 3.0,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: ink.withValues(alpha: 0.15),
            thickness: CookbookTheme.strokeWidth,
          ),
        ),
      ],
    );
  }
}

// ── Meta row for share image ─────────────────────────────────────

class _ShareMetaRow extends StatelessWidget {
  const _ShareMetaRow({required this.recipe});
  final RecipeResult recipe;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (recipe.prepTime.isNotEmpty) {
      chips.add(_shareChip(Icons.restaurant, recipe.prepTime));
    }
    if (recipe.cookTime.isNotEmpty) {
      chips.add(_shareChip(Icons.local_fire_department, recipe.cookTime));
    }
    if (recipe.servings.isNotEmpty) {
      chips.add(_shareChip(Icons.people_outline, 'Serves ${recipe.servings}'));
    }
    if (recipe.caloriesPerServing != null) {
      chips.add(
          _shareChip(Icons.whatshot_outlined, '${recipe.caloriesPerServing} cal'));
    }
    if (recipe.modifier != DietaryModifier.standard) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: CookbookPalette.lightAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(CookbookTheme.brutalRadius),
            border: Border.all(
              color: CookbookPalette.lightAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            recipe.modifier.label,
            style: CookbookTheme.labelStyle(
              fontSize: 9,
              color: CookbookPalette.lightAccent,
              letterSpacing: 1.8,
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: chips,
    );
  }

  static Widget _shareChip(IconData icon, String label) {
    const ink = CookbookPalette.lightInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CookbookTheme.brutalRadius),
        border: Border.all(color: ink.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ink.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: CookbookTheme.labelStyle(
              fontSize: 10,
              color: ink.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sprite cell for share image ──────────────────────────────────

class _ShareSpriteCell extends StatelessWidget {
  const _ShareSpriteCell({
    required this.gridImage,
    required this.index,
    required this.totalItems,
  });

  final Uint8List gridImage;
  final int index;
  final int totalItems;

  @override
  Widget build(BuildContext context) {
    // Use FutureBuilder to get the actual image dimensions for correct
    // aspect-ratio-aware cropping.
    return FutureBuilder<ui.Image>(
      future: _decodeImage(gridImage),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return _buildCropped(snapshot.data!);
      },
    );
  }

  Widget _buildCropped(ui.Image decoded) {
    const cols = 4;
    final rows = (totalItems / cols).ceil();
    final col = index % cols;
    final row = index ~/ cols;

    // Source cell rect in image pixels.
    final cellW = decoded.width / cols;
    final cellH = decoded.height / rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final displayW = constraints.maxWidth;
        final displayH = constraints.maxHeight;

        return ClipRect(
          child: CustomPaint(
            size: Size(displayW, displayH),
            painter: _SpritePainter(
              image: decoded,
              srcRect: Rect.fromLTWH(
                  col * cellW, row * cellH, cellW, cellH),
            ),
          ),
        );
      },
    );
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter({required this.image, required this.srcRect});

  final ui.Image image;
  final Rect srcRect;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      srcRect,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image != image || old.srcRect != srcRect;
}
