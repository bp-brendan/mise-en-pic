import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/motion_config.dart';
import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../../../core/widgets/letterpress_card.dart';
import '../../../camera/domain/models/dietary_modifier.dart';
import '../../data/gemini_service.dart';
import '../../domain/models/recipe_result.dart';
import '../providers/recipe_providers.dart';

/// The illustrated cookbook page.
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({
    super.key,
    required this.imageBytes,
    required this.modifier,
  });

  final Uint8List imageBytes;
  final DietaryModifier modifier;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(recipeNotifierProvider.notifier).generate(
            imageBytes: widget.imageBytes,
            modifier: widget.modifier,
          );
    });
  }

  Future<void> _save() async {
    final ok =
        await ref.read(recipeNotifierProvider.notifier).save(widget.imageBytes);
    if (ok && mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Recipe',
          style: CookbookTheme.headlineStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          if (state is RecipeSuccess)
            IconButton(
              onPressed: _saved ? null : _save,
              icon: Icon(
                _saved ? Icons.bookmark : Icons.bookmark_border,
                color: _saved
                    ? CookbookPalette.lightAccent
                    : theme.colorScheme.onSurface,
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: MotionConfig.routeTransition,
        switchInCurve: MotionConfig.routeCurve,
        child: state.when(
          loading: () => const _LoadingView(key: ValueKey('loading')),
          error: (message) => _ErrorView(
            key: const ValueKey('error'),
            message: message,
            onRetry: () {
              ref.read(recipeNotifierProvider.notifier).generate(
                    imageBytes: widget.imageBytes,
                    modifier: widget.modifier,
                  );
            },
          ),
          success: (recipe, dishImage, gridImage) => _CookbookPage(
            key: const ValueKey('success'),
            recipe: recipe,
            photoBytes: widget.imageBytes,
            dishImage: dishImage,
            gridImage: gridImage,
          ),
        ),
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: CookbookPalette.lightAccent),
          const SizedBox(height: 20),
          Text(
            'Reverse-engineering your dish...',
            style: CookbookTheme.bodyStyle(
              color: CookbookPalette.lightInk.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: CookbookPalette.error.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: CookbookTheme.bodyStyle()),
            const SizedBox(height: 20),
            OutlinedButton(
                onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

// ── Cookbook Page ───────────────────────────────────────────────────

class _CookbookPage extends StatelessWidget {
  const _CookbookPage({
    super.key,
    required this.recipe,
    required this.photoBytes,
    this.dishImage,
    this.gridImage,
  });

  final RecipeResult recipe;
  final Uint8List photoBytes;
  final Uint8List? dishImage;
  final Uint8List? gridImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Dish illustration (or photo fallback) ──
          LetterpressCard(
            padding: const EdgeInsets.all(6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _DishHero(
                dishImage: dishImage,
                photoBytes: photoBytes,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Dish title ──
          Center(
            child: Text(
              recipe.dishName,
              textAlign: TextAlign.center,
              style: CookbookTheme.displayStyle(
                fontSize: 34,
                fontWeight: 760,
                color: ink,
              ).copyWith(
                shadows: CookbookTheme.letterpressShadows(ink),
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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

          // ── Ingredients with inline sprite illustrations ──
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
                  // Sprite crop from grid, or emoji fallback
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: gridImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: _IngredientSprite(
                              gridImage: gridImage!,
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
                        style:
                            CookbookTheme.bodyStyle(fontSize: 13, color: ink),
                        children: [
                          TextSpan(
                            text: '${ing.amount} ',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
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

          // ── Method ──
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
    );
  }
}

// ── Dish hero with crossfade from photo to illustration ───────────

class _DishHero extends StatelessWidget {
  const _DishHero({this.dishImage, required this.photoBytes});

  final Uint8List? dishImage;
  final Uint8List photoBytes;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 600),
      crossFadeState: dishImage != null
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstCurve: Curves.easeOut,
      secondCurve: Curves.easeOut,
      firstChild: Image.memory(
        photoBytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
      secondChild: dishImage != null
          ? Image.memory(
              dishImage!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            )
          : const SizedBox.shrink(),
    );
  }
}

// ── Ingredient sprite — crops one cell from the grid image ──────────

class _IngredientSprite extends StatelessWidget {
  const _IngredientSprite({
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

    // FractionalTranslation + OverflowBox to show just this cell.
    // The image is scaled so each cell maps to the widget size,
    // then translated to bring the target cell into view.
    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        alignment: Alignment.topLeft,
        child: FractionalTranslation(
          translation: Offset(-col.toDouble(), -row.toDouble()),
          child: SizedBox(
            width: 52.0 * cols,
            height: 52.0 * rows,
            child: Image.memory(
              gridImage,
              fit: BoxFit.fill,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────

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
