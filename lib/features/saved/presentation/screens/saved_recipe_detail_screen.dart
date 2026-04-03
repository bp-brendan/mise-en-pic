import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../../recipe/data/gemini_service.dart';
import '../../../recipe/domain/models/recipe_result.dart';

/// Displays a previously saved recipe with its illustrations.
class SavedRecipeDetailScreen extends StatelessWidget {
  const SavedRecipeDetailScreen({super.key, required this.recipe});

  final RecipeResult recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final gridBytes = _loadGridBytes();
    final steps = recipe.steps;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          recipe.dishName,
          style: CookbookTheme.headlineStyle(fontSize: 18, color: ink),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dish illustration or photo fallback
            if (recipe.dishImagePath != null)
              Image.file(
                File(recipe.dishImagePath!),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _photoFallback(),
              )
            else
              _photoFallback(),
            const SizedBox(height: 24),

            // Title
            Center(
              child: Text(
                recipe.dishName,
                textAlign: TextAlign.center,
                style: CookbookTheme.displayStyle(
                  fontSize: 34,
                  fontWeight: 760,
                  color: ink,
                ).copyWith(shadows: CookbookTheme.letterpressShadows(ink)),
              ),
            ),
            if (recipe.tagline.isNotEmpty) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  recipe.tagline,
                  textAlign: TextAlign.center,
                  style: CookbookTheme.bodyStyle(
                    fontSize: 14,
                    fontWeight: 430,
                    color: ink.withValues(alpha: 0.6),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Meta row
            _MetaRow(recipe: recipe, ink: ink),

            const SizedBox(height: 28),

            // Ingredients
            _SectionLabel(label: 'INGREDIENTS', ink: ink),
            const SizedBox(height: 12),
            ...recipe.ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ing = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: gridBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: _SpriteCell(
                                gridImage: gridBytes,
                                index: index,
                                totalItems: recipe.ingredients.length,
                              ),
                            )
                          : Center(
                              child: Text(ing.emoji,
                                  style: const TextStyle(fontSize: 28)),
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
              final matches = recipe.ingredientIndicesForStep(stepText);
              final spriteIdx = matches.isNotEmpty ? matches.first : null;

              return _MethodStep(
                stepNumber: stepIndex + 1,
                text: stepText,
                ink: ink,
                gridImage: gridBytes,
                spriteIndex: spriteIdx,
                totalIngredients: recipe.ingredients.length,
                layoutVariant: stepIndex % 3,
              );
            }),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Uint8List? _loadGridBytes() {
    final path = recipe.gridImagePath;
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytesSync();
  }

  Widget _photoFallback() {
    if (recipe.imagePath != null) {
      return Image.file(File(recipe.imagePath!), fit: BoxFit.cover);
    }
    return const SizedBox(
      height: 200,
      child: Center(child: Text('🍽️', style: TextStyle(fontSize: 48))),
    );
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
          icon: Icons.content_cut, label: recipe.prepTime, ink: ink));
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
    required this.layoutVariant,
  });

  final int stepNumber;
  final String text;
  final Color ink;
  final Uint8List? gridImage;
  final int? spriteIndex;
  final int totalIngredients;
  final int layoutVariant;

  @override
  Widget build(BuildContext context) {
    final hasSprite = gridImage != null && spriteIndex != null;
    const spriteSize = 72.0;

    final stepNumWidget = Text(
      '$stepNumber',
      style: CookbookTheme.displayStyle(
        fontSize: 32,
        fontWeight: 760,
        color: ink.withValues(alpha: 0.1),
      ),
    );

    final textWidget = Text(
      text,
      style: CookbookTheme.bodyStyle(fontSize: 16, color: ink)
          .copyWith(height: 1.55),
    );

    final spriteWidget = hasSprite
        ? SizedBox(
            width: spriteSize,
            height: spriteSize,
            child: _SpriteCell(
              gridImage: gridImage!,
              index: spriteIndex!,
              totalItems: totalIngredients,
            ),
          )
        : null;

    Widget content;
    if (!hasSprite) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 36, child: stepNumWidget),
          const SizedBox(width: 8),
          Expanded(child: textWidget),
        ],
      );
    } else if (layoutVariant == 0) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 36, child: stepNumWidget),
          const SizedBox(width: 8),
          Expanded(child: textWidget),
          const SizedBox(width: 8),
          spriteWidget!,
        ],
      );
    } else if (layoutVariant == 1) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          spriteWidget!,
          const SizedBox(width: 8),
          SizedBox(width: 36, child: stepNumWidget),
          const SizedBox(width: 4),
          Expanded(child: textWidget),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 36, child: stepNumWidget),
              const SizedBox(width: 12),
              spriteWidget!,
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: textWidget,
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: content,
    );
  }
}

// ── Sprite cell — crops one cell from the grid image ────────────

class _SpriteCell extends StatelessWidget {
  const _SpriteCell({
    required this.gridImage,
    required this.index,
    required this.totalItems,
  });

  final Uint8List gridImage;
  final int index;
  final int totalItems;

  @override
  Widget build(BuildContext context) {
    const cols = GeminiService.gridColumns;
    final rows = (totalItems / cols).ceil();
    final col = index % cols;
    final row = index ~/ cols;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth;
        final cellH = constraints.maxHeight;
        final fullW = cellW * cols;
        final fullH = cellH * rows;

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: fullW,
            maxHeight: fullH,
            child: Transform.translate(
              offset: Offset(-col * cellW, -row * cellH),
              child: Image.memory(
                gridImage,
                width: fullW,
                height: fullH,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          ),
        );
      },
    );
  }
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
