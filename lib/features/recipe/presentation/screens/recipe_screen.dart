import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/motion_config.dart';
import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../../../core/utils/recipe_sharer.dart';
import '../../../camera/domain/models/dietary_modifier.dart';
import '../../domain/recipe_utils.dart';
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

    // If not food, show toast and go home.
    ref.listen<RecipeState>(recipeNotifierProvider, (prev, next) {
      if (next is RecipeNotFood) {
        _showNotFoodToast(context, next.message);
        context.go('/');
      }
    });

    // Don't render anything if we're about to navigate away.
    if (state is RecipeNotFood) {
      return const Scaffold(backgroundColor: CookbookPalette.lightBackground);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
      backgroundColor: CookbookPalette.lightBackground,
      appBar: AppBar(
        backgroundColor: CookbookPalette.lightBackground,
        // Back goes all the way home, not back through camera/confirm.
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          'Your Recipe',
          style: CookbookTheme.headlineStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          if (state case RecipeSuccess(
            :final recipe,
            :final dishImage,
            :final gridImage,
          )) ...[
            IconButton(
              onPressed: () => RecipeSharer.share(
                context: context,
                recipe: recipe,
                dishImage: dishImage,
                gridImage: gridImage,
                photoBytes: widget.imageBytes,
              ),
              icon: Icon(
                Icons.ios_share,
                color: theme.colorScheme.onSurface,
              ),
            ),
            IconButton(
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
            ),
            IconButton(
              onPressed: () => _confirmDelete(context, ref, recipe),
              icon: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
      body: AnimatedSwitcher(
        duration: MotionConfig.routeTransition,
        switchInCurve: MotionConfig.routeCurve,
        child: switch (state) {
          RecipeLoading() =>
            const _LoadingView(key: ValueKey('loading')),
          RecipeError(:final message) => _ErrorView(
            key: const ValueKey('error'),
            message: message,
            onRetry: () {
              ref.read(recipeNotifierProvider.notifier).generate(
                    imageBytes: widget.imageBytes,
                    modifier: widget.modifier,
                  );
            },
          ),
          RecipeSuccess(:final recipe, :final dishImage, :final gridImage, :final featuredIndices) =>
            _CookbookPage(
              key: const ValueKey('success'),
              recipe: recipe,
              dishImage: dishImage,
              gridImage: gridImage,
              featuredIndices: featuredIndices ?? [],
            ),
          RecipeNotFood() => const SizedBox.shrink(),
        },
      ),
    ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, RecipeResult recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Remove "${recipe.dishName}" permanently?'),
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
      await ref.read(recipeRepositoryProvider).delete(recipe);
      if (context.mounted) context.go('/');
    }
  }

  void _showNotFoodToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _NotFoodToast(
        message: message,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
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
    this.dishImage,
    this.gridImage,
    this.featuredIndices = const [],
  });

  final RecipeResult recipe;
  final Uint8List? dishImage;
  final Uint8List? gridImage;
  final List<int> featuredIndices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final steps = recipe.steps;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Dish illustration — square, edge to edge ──
          _DishHero(dishImage: dishImage),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),

                // ── Meta row: prep time, cook time, servings, modifier ──
                _MetaRow(recipe: recipe, ink: ink),

                const SizedBox(height: 28),

                // ── Ingredients ──
                _SectionLabel(label: 'INGREDIENTS', ink: ink),
                const SizedBox(height: 12),
                ...recipe.ingredients.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ing = entry.value;
                  // Find this ingredient's position in the sprite grid (if featured).
                  final spritePos = featuredIndices.indexOf(index);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: gridImage != null && spritePos >= 0
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: _IngredientSprite(
                                    gridImage: gridImage!,
                                    index: spritePos,
                                    totalItems: featuredIndices.length,
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

                // ── Method ──
                _SectionLabel(label: 'METHOD', ink: ink),
                const SizedBox(height: 16),
                ...steps.asMap().entries.map((entry) {
                  final stepIndex = entry.key;
                  final stepText = entry.value;
                  final matches =
                      recipe.ingredientIndicesForStep(stepText);
                  // Map ingredient index to featured sprite position.
                  int? spritePos;
                  for (final m in matches) {
                    final pos = featuredIndices.indexOf(m);
                    if (pos >= 0) { spritePos = pos; break; }
                  }

                  return _MethodStep(
                    stepNumber: stepIndex + 1,
                    text: stepText,
                    ink: ink,
                    gridImage: gridImage,
                    spriteIndex: spritePos,
                    totalIngredients: featuredIndices.length,
                  );
                }),

                const SizedBox(height: 40),
              ],
            ),
          ),
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
      chips.add(_MetaChip(icon: Icons.restaurant, label: recipe.prepTime, ink: ink));
    }
    if (recipe.cookTime.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.local_fire_department, label: recipe.cookTime, ink: ink));
    }
    if (recipe.servings.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.people_outline, label: 'Serves ${recipe.servings}', ink: ink));
    }
    if (recipe.caloriesPerServing != null) {
      chips.add(_MetaChip(icon: Icons.whatshot_outlined, label: '${recipe.caloriesPerServing} cal', ink: ink));
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

// ── Method step with ingredient illustration ─────────────────────

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
              child: _IngredientSprite(
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

// ── Dish hero — illustration or quirky loading placeholder ────────

class _DishHero extends StatelessWidget {
  const _DishHero({this.dishImage});

  final Uint8List? dishImage;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (dishImage != null) {
      return SizedBox(
        width: screenWidth,
        height: screenWidth, // square
        child: Image.memory(
          dishImage!,
          fit: BoxFit.cover, // crop to fill the square
          gaplessPlayback: true,
        ),
      );
    }

    // Quirky placeholder while illustration generates.
    return SizedBox(
      width: screenWidth,
      height: screenWidth,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎨', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'Painting your dish...',
              style: TextStyle(
                fontFamily: 'SourceSerif4',
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: CookbookPalette.lightInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ingredient sprite — crops one cell from the grid image ──────────

class _IngredientSprite extends StatefulWidget {
  const _IngredientSprite({
    required this.gridImage,
    required this.index,
    required this.totalItems,
  });

  final Uint8List gridImage;
  final int index;
  final int totalItems;

  @override
  State<_IngredientSprite> createState() => _IngredientSpriteState();
}

class _IngredientSpriteState extends State<_IngredientSprite> {
  ui.Image? _decoded;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(_IngredientSprite old) {
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

    const cols = RecipeUtils.gridColumns;
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

// ── Not-food toast — auto-dismisses, hold to keep ───────────────

class _NotFoodToast extends StatefulWidget {
  const _NotFoodToast({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  State<_NotFoodToast> createState() => _NotFoodToastState();
}

class _NotFoodToastState extends State<_NotFoodToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  bool _held = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..value = 0.0;

    // Fade in.
    _fadeController.forward();

    // Start auto-dismiss timer.
    _startDismissTimer();
  }

  void _startDismissTimer() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_held && !_dismissed) _dismiss();
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _fadeController.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 20,
      right: 20,
      bottom: bottomPadding + 24,
      child: FadeTransition(
        opacity: _fadeController,
        child: GestureDetector(
          onLongPressStart: (_) => setState(() => _held = true),
          onLongPressEnd: (_) {
            setState(() => _held = false);
            // Dismiss shortly after release.
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && !_held && !_dismissed) _dismiss();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: CookbookPalette.lightInk.withValues(alpha: 0.92),
              borderRadius:
                  BorderRadius.circular(CookbookTheme.brutalRadius * 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: CookbookTheme.bodyStyle(
                fontSize: 15,
                color: CookbookPalette.lightCard,
              ).copyWith(height: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}
