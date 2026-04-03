import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../camera/domain/models/dietary_modifier.dart';
import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../../../core/utils/recipe_sharer.dart';
import '../../../recipe/data/gemini_service.dart';
import '../../../recipe/domain/models/recipe_result.dart';
import '../../../recipe/presentation/providers/recipe_providers.dart';

/// Displays a previously saved recipe with its illustrations.
class SavedRecipeDetailScreen extends ConsumerStatefulWidget {
  const SavedRecipeDetailScreen({super.key, required this.recipe});

  final RecipeResult recipe;

  @override
  ConsumerState<SavedRecipeDetailScreen> createState() =>
      _SavedRecipeDetailScreenState();
}

class _SavedRecipeDetailScreenState
    extends ConsumerState<SavedRecipeDetailScreen> {
  late RecipeResult _recipe;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Remove "${_recipe.dishName}" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: CookbookPalette.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(recipeRepositoryProvider).delete(_recipe);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _togglePin() async {
    final repo = ref.read(recipeRepositoryProvider);
    final updated = await repo.togglePin(_recipe);
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _recipe = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final gridBytes = _loadGridBytes();
    final steps = _recipe.steps;
    final featured = GeminiService.featuredIndices(_recipe.ingredients);

    return Scaffold(
      backgroundColor: CookbookPalette.lightBackground,
      appBar: AppBar(
        backgroundColor: CookbookPalette.lightBackground,
        title: Text(
          _recipe.dishName,
          style: CookbookTheme.headlineStyle(fontSize: 18, color: ink),
        ),
        actions: [
          IconButton(
            onPressed: () => RecipeSharer.share(
              context: context, recipe: _recipe),
            icon: Icon(Icons.ios_share, color: ink),
          ),
          IconButton(
            onPressed: _togglePin,
            icon: Icon(
              _recipe.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _recipe.isPinned
                  ? CookbookPalette.lightAccent
                  : ink.withValues(alpha: 0.4),
            ),
          ),
          IconButton(
            onPressed: () => _confirmDelete(context),
            icon: Icon(Icons.delete_outline,
                color: ink.withValues(alpha: 0.6)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dish illustration — square crop, edge to edge
            if (_recipe.dishImagePath != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth;
                  return SizedBox(
                    width: size,
                    height: size,
                    child: Image.file(
                      File(_recipe.dishImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  );
                },
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),

                  // Meta row
                  _MetaRow(recipe: _recipe, ink: ink),

                  const SizedBox(height: 28),

                  // Ingredients
                  _SectionLabel(label: 'INGREDIENTS', ink: ink),
                  const SizedBox(height: 12),
                  ..._recipe.ingredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ing = entry.value;
                    final spritePos = featured.indexOf(index);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: gridBytes != null && spritePos >= 0
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: _SpriteCell(
                                      gridImage: gridBytes,
                                      index: spritePos,
                                      totalItems: featured.length,
                                    ),
                                  )
                                : Center(
                                    child: Text(ing.emoji,
                                        style:
                                            const TextStyle(fontSize: 28)),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: CookbookTheme.bodyStyle(
                                    fontSize: 15, color: ink),
                                children: [
                                  TextSpan(
                                    text: '${ing.amount} ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(text: ing.name),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 28),

                  // Method
                  _SectionLabel(label: 'METHOD', ink: ink),
                  const SizedBox(height: 16),
                  ...steps.asMap().entries.map((entry) {
                    final stepIndex = entry.key;
                    final stepText = entry.value;
                    final matches =
                        _recipe.ingredientIndicesForStep(stepText);
                    int? spritePos;
                    for (final m in matches) {
                      final pos = featured.indexOf(m);
                      if (pos >= 0) { spritePos = pos; break; }
                    }

                    return _MethodStep(
                      stepNumber: stepIndex + 1,
                      text: stepText,
                      ink: ink,
                      gridImage: gridBytes,
                      spriteIndex: spritePos,
                      totalIngredients: featured.length,
                    );
                  }),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Uint8List? _loadGridBytes() {
    final path = _recipe.gridImagePath;
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytesSync();
  }

}

// ── Meta row ─────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.recipe, required this.ink});
  final RecipeResult recipe;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (recipe.prepTime.isNotEmpty) {
      chips.add(_MetaChip(
          icon: Icons.restaurant, label: recipe.prepTime, ink: ink));
    }
    if (recipe.cookTime.isNotEmpty) {
      chips.add(_MetaChip(
          icon: Icons.local_fire_department, label: recipe.cookTime, ink: ink));
    }
    if (recipe.servings.isNotEmpty) {
      chips.add(_MetaChip(
          icon: Icons.people_outline,
          label: 'Serves ${recipe.servings}',
          ink: ink));
    }
    if (recipe.caloriesPerServing != null) {
      chips.add(_MetaChip(
          icon: Icons.whatshot_outlined,
          label: '${recipe.caloriesPerServing} cal',
          ink: ink));
    }
    if (recipe.modifier != DietaryModifier.standard) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              fontSize: 10,
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
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.ink});
  final IconData icon;
  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CookbookTheme.brutalRadius),
        border: Border.all(color: ink.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ink.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: CookbookTheme.labelStyle(
              fontSize: 11,
              color: ink.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Method step ──────────────────────────────────────────────────

class _MethodStep extends StatelessWidget {
  const _MethodStep({
    required this.stepNumber,
    required this.text,
    required this.ink,
    this.gridImage,
    this.spriteIndex,
    required this.totalIngredients,
  });

  final int stepNumber;
  final String text;
  final Color ink;
  final Uint8List? gridImage;
  final int? spriteIndex;
  final int totalIngredients;

  @override
  Widget build(BuildContext context) {
    final hasSprite = gridImage != null && spriteIndex != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$stepNumber',
              style: CookbookTheme.displayStyle(
                fontSize: 28,
                fontWeight: 760,
                color: ink.withValues(alpha: 0.1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: CookbookTheme.bodyStyle(fontSize: 15, color: ink)
                  .copyWith(height: 1.5),
            ),
          ),
          if (hasSprite) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 56,
              height: 56,
              child: _SpriteCell(
                gridImage: gridImage!,
                index: spriteIndex!,
                totalItems: totalIngredients,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sprite cell — crops one cell from the grid image ────────────

class _SpriteCell extends StatefulWidget {
  const _SpriteCell({
    required this.gridImage,
    required this.index,
    required this.totalItems,
  });

  final Uint8List gridImage;
  final int index;
  final int totalItems;

  @override
  State<_SpriteCell> createState() => _SpriteCellState();
}

class _SpriteCellState extends State<_SpriteCell> {
  ui.Image? _decoded;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(_SpriteCell old) {
    super.didUpdateWidget(old);
    if (!identical(old.gridImage, widget.gridImage)) _decode();
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.gridImage);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _decoded = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    if (_decoded == null) return const SizedBox.shrink();

    const cols = GeminiService.gridColumns;
    final rows = (widget.totalItems / cols).ceil();
    final col = widget.index % cols;
    final row = widget.index ~/ cols;

    final cellW = _decoded!.width / cols;
    final cellH = _decoded!.height / rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _SpritePainter(
            image: _decoded!,
            srcRect: Rect.fromLTWH(
                col * cellW, row * cellH, cellW, cellH),
          ),
        );
      },
    );
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

// ── Section label ────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.ink});
  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
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
              fontSize: 11,
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
