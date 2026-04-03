import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/motion_config.dart';
import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: CookbookPalette.lightBackground,
      appBar: AppBar(
        backgroundColor: CookbookPalette.lightBackground,
        title: Text(
          'Your Recipe',
          style: CookbookTheme.headlineStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          if (state case RecipeSuccess(:final recipe)) ...[
            Builder(builder: (context) {
              return IconButton(
                onPressed: () =>
                    ref.read(recipeNotifierProvider.notifier).togglePin(),
                icon: Icon(
                  recipe.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  color: recipe.isPinned
                      ? CookbookPalette.lightAccent
                      : theme.colorScheme.onSurface,
                ),
              );
            }),
          ],
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
    final steps = recipe.steps;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Dish illustration (or photo fallback) ──
          _DishHero(dishImage: dishImage, photoBytes: photoBytes),
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

          // ── Meta row: prep time, cook time, servings, modifier ──
          _MetaRow(recipe: recipe, ink: ink),

          const SizedBox(height: 28),

          // ── Ingredients ──
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
                            CookbookTheme.bodyStyle(fontSize: 15, color: ink),
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
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final stepIndex = entry.key;
            final stepText = entry.value;
            final ingredientMatches =
                recipe.ingredientIndicesForStep(stepText);
            // Pick the first matched ingredient for illustration.
            final spriteIndex =
                ingredientMatches.isNotEmpty ? ingredientMatches.first : null;

            return _MethodStep(
              stepNumber: stepIndex + 1,
              text: stepText,
              ink: ink,
              gridImage: gridImage,
              spriteIndex: spriteIndex,
              totalIngredients: recipe.ingredients.length,
              layoutVariant: stepIndex % 3, // cycle through layouts
            );
          }),

          const SizedBox(height: 40),
        ],
      ),
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
      chips.add(_MetaChip(icon: Icons.content_cut, label: recipe.prepTime, ink: ink));
    }
    if (recipe.cookTime.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.local_fire_department, label: recipe.cookTime, ink: ink));
    }
    if (recipe.servings.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.people_outline, label: 'Serves ${recipe.servings}', ink: ink));
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

// ── Method step with ingredient illustration ─────────────────────

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
  final int layoutVariant; // 0, 1, 2 — cycles through layouts

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
      style: CookbookTheme.bodyStyle(
        fontSize: 16,
        color: ink,
      ).copyWith(height: 1.55),
    );

    final spriteWidget = hasSprite
        ? SizedBox(
            width: spriteSize,
            height: spriteSize,
            child: _IngredientSprite(
              gridImage: gridImage!,
              index: spriteIndex!,
              totalItems: totalIngredients,
            ),
          )
        : null;

    // Vary layout based on step for cookbook feel.
    Widget content;
    if (!hasSprite) {
      // No sprite — simple layout with big step number.
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 36, child: stepNumWidget),
          const SizedBox(width: 8),
          Expanded(child: textWidget),
        ],
      );
    } else if (layoutVariant == 0) {
      // Sprite on the right, text on the left.
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
      // Sprite on the left, text on the right.
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
      // Sprite centered above the text.
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
