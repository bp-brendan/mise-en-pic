import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../../../core/widgets/letterpress_card.dart';
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
              LetterpressCard(
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(recipe.dishImagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _photoFallback(),
                  ),
                ),
              )
            else
              LetterpressCard(
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _photoFallback(),
                ),
              ),
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
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: CookbookPalette.lightAccent.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(CookbookTheme.brutalRadius),
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
            ),

            const SizedBox(height: 28),

            // Ingredients with inline sprite illustrations
            _SectionLabel(label: 'INGREDIENTS', ink: ink),
            const SizedBox(height: 12),
            _IngredientsWithSprites(recipe: recipe, ink: ink),

            const SizedBox(height: 28),

            // Method
            _SectionLabel(label: 'METHOD', ink: ink),
            const SizedBox(height: 12),
            LetterpressCard(
              padding: const EdgeInsets.all(16),
              lift: 0.3,
              child: Text(
                recipe.method,
                style: CookbookTheme.bodyStyle(fontSize: 14, color: ink),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _photoFallback() {
    if (recipe.imagePath != null) {
      return Image.file(
        File(recipe.imagePath!),
        fit: BoxFit.cover,
      );
    }
    return const SizedBox(
      height: 200,
      child: Center(child: Text('🍽️', style: TextStyle(fontSize: 48))),
    );
  }
}

class _IngredientsWithSprites extends StatelessWidget {
  const _IngredientsWithSprites({required this.recipe, required this.ink});
  final RecipeResult recipe;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    // Load grid image bytes if available.
    final gridPath = recipe.gridImagePath;
    final Uint8List? gridBytes =
        gridPath != null ? File(gridPath).readAsBytesSync() : null;

    return Column(
      children: recipe.ingredients.asMap().entries.map((entry) {
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
                        child: _SavedIngredientSprite(
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
                    style: CookbookTheme.bodyStyle(fontSize: 13, color: ink),
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
      }).toList(),
    );
  }
}

class _SavedIngredientSprite extends StatelessWidget {
  const _SavedIngredientSprite({
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

    final ax = cols > 1 ? -1.0 + 2.0 * col / (cols - 1) : 0.0;
    final ay = rows > 1 ? -1.0 + 2.0 * row / (rows - 1) : 0.0;

    return ClipRect(
      child: Align(
        alignment: Alignment(ax, ay),
        widthFactor: 1.0 / cols,
        heightFactor: 1.0 / rows,
        child: Image.memory(
          gridImage,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

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
