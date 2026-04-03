import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../../../core/widgets/letterpress_card.dart';
import '../../../recipe/domain/models/recipe_result.dart';
import '../../../recipe/presentation/providers/recipe_providers.dart';

/// Displays all saved recipes as a scrollable card list with swipe-to-burn
/// delete and pin-to-top functionality.
class SavedRecipesScreen extends ConsumerStatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  ConsumerState<SavedRecipesScreen> createState() =>
      _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends ConsumerState<SavedRecipesScreen> {
  List<RecipeResult> _recipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recipes = await ref.read(recipeRepositoryProvider).loadAll();
    if (mounted) setState(() { _recipes = recipes; _loading = false; });
  }

  Future<void> _togglePin(int index) async {
    final repo = ref.read(recipeRepositoryProvider);
    await repo.togglePin(_recipes[index]);
    HapticFeedback.selectionClick();
    final recipes = await repo.loadAll();
    if (mounted) setState(() => _recipes = recipes);
  }

  Future<void> _deleteRecipe(int index) async {
    final recipe = _recipes[index];
    final repo = ref.read(recipeRepositoryProvider);
    setState(() => _recipes.removeAt(index));
    await repo.delete(recipe);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${recipe.dishName} burned')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved Recipes',
          style: CookbookTheme.headlineStyle(color: ink),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📖', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text('No saved recipes yet',
                          style: CookbookTheme.titleStyle(
                              color: ink.withValues(alpha: 0.5))),
                      const SizedBox(height: 6),
                      Text('Snap a dish and it will appear here',
                          style: CookbookTheme.bodyStyle(
                              fontSize: 13,
                              color: ink.withValues(alpha: 0.35))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: _recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _recipes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _BurnDismissible(
                        key: ValueKey(
                            recipe.jsonPath ?? '${recipe.dishName}_$index'),
                        onBurned: () => _deleteRecipe(index),
                        child: _RecipeCard(
                          recipe: recipe,
                          ink: ink,
                          onTap: () async {
                            await context.push('/saved/view',
                                extra: {'recipe': recipe});
                            _load();
                          },
                          onTogglePin: () => _togglePin(index),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ── Recipe card ──────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.ink,
    required this.onTap,
    required this.onTogglePin,
  });

  final RecipeResult recipe;
  final Color ink;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final thumbPath = recipe.dishImagePath ?? recipe.imagePath;

    return GestureDetector(
      onTap: onTap,
      child: LetterpressCard(
        padding: EdgeInsets.zero,
        lift: 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CookbookTheme.brutalRadius),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(5)),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: thumbPath != null
                          ? Image.file(
                              File(thumbPath),
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _emojiThumb(),
                            )
                          : _emojiThumb(),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 36, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.dishName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CookbookTheme.titleStyle(
                                fontSize: 15, color: ink),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (recipe.prepTime.isNotEmpty ||
                                  recipe.cookTime.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.schedule,
                                          size: 11,
                                          color: ink.withValues(alpha: 0.35)),
                                      const SizedBox(width: 2),
                                      Text(
                                        recipe.cookTime.isNotEmpty
                                            ? recipe.cookTime
                                            : recipe.prepTime,
                                        style: CookbookTheme.labelStyle(
                                          fontSize: 10,
                                          color: ink.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: CookbookPalette.lightAccent
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  recipe.modifier.label,
                                  style: CookbookTheme.labelStyle(
                                    fontSize: 9,
                                    color: CookbookPalette.lightAccent,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (recipe.tagline.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              recipe.tagline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CookbookTheme.bodyStyle(
                                fontSize: 11,
                                color: ink.withValues(alpha: 0.4),
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Pin icon — top right
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onTogglePin,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      recipe.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      size: 16,
                      color: recipe.isPinned
                          ? CookbookPalette.lightAccent
                          : ink.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emojiThumb() {
    return Container(
      color: CookbookPalette.lightStroke.withValues(alpha: 0.2),
      child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 28))),
    );
  }
}

// ── Burn dismissible — swipe left to delete with flame effect ────

class _BurnDismissible extends StatefulWidget {
  const _BurnDismissible({
    super.key,
    required this.child,
    required this.onBurned,
  });

  final Widget child;
  final VoidCallback onBurned;

  @override
  State<_BurnDismissible> createState() => _BurnDismissibleState();
}

class _BurnDismissibleState extends State<_BurnDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burnController;
  bool _isBurning = false;

  @override
  void initState() {
    super.initState();
    _burnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _burnController.dispose();
    super.dispose();
  }

  Future<void> _commitBurn() async {
    HapticFeedback.mediumImpact();
    setState(() => _isBurning = true);
    await _burnController.forward();
    widget.onBurned();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: widget.key!,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _commitBurn();
        return true;
      },
      dismissThresholds: const {DismissDirection.endToStart: 0.4},
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CookbookTheme.brutalRadius),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFCC2D1A)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -math.pi / 12,
              child: const Text('🔥', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 2),
            Text(
              'BURN',
              style: CookbookTheme.labelStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
      child: _isBurning
          ? AnimatedBuilder(
              animation: _burnController,
              builder: (context, child) {
                final t = _burnController.value;
                return Opacity(
                  opacity: 1.0 - t,
                  child: Transform.scale(
                    scale: 1.0 - (t * 0.05),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Color.lerp(
                              Colors.transparent,
                              const Color(0xFFFF6B35),
                              t * 0.6,
                            ) ??
                            Colors.transparent,
                        BlendMode.srcATop,
                      ),
                      child: widget.child,
                    ),
                  ),
                );
              },
            )
          : widget.child,
    );
  }
}
