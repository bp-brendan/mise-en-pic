import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../../../core/widgets/letterpress_card.dart';
import '../../../recipe/domain/models/recipe_result.dart';
import '../../../recipe/presentation/providers/recipe_providers.dart';

/// Displays all saved recipes as a scrollable list.
class SavedRecipesScreen extends ConsumerStatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  ConsumerState<SavedRecipesScreen> createState() =>
      _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends ConsumerState<SavedRecipesScreen> {
  late Future<List<RecipeResult>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _recipesFuture = ref.read(recipeRepositoryProvider).loadAll();
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
      body: FutureBuilder<List<RecipeResult>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final recipes = snapshot.data ?? [];

          if (recipes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📖', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    'No saved recipes yet',
                    style: CookbookTheme.titleStyle(
                      color: ink.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Snap a dish and save its recipe here',
                    style: CookbookTheme.bodyStyle(
                      fontSize: 13,
                      color: ink.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return _SavedRecipeCard(
                recipe: recipe,
                ink: ink,
                onTap: () {
                  context.push('/saved/view', extra: {'recipe': recipe});
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedRecipeCard extends StatelessWidget {
  const _SavedRecipeCard({
    required this.recipe,
    required this.ink,
    required this.onTap,
  });

  final RecipeResult recipe;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Prefer dish illustration, fall back to photo, fall back to emoji.
    final thumbPath = recipe.dishImagePath ?? recipe.imagePath;

    return GestureDetector(
      onTap: onTap,
      child: LetterpressCard(
        padding: const EdgeInsets.all(0),
        lift: 0.4,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(5),
              ),
              child: SizedBox(
                width: 88,
                height: 88,
                child: thumbPath != null
                    ? Image.file(
                        File(thumbPath),
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _emojiThumb(),
                      )
                    : _emojiThumb(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.dishName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CookbookTheme.titleStyle(
                        fontSize: 15,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
                        const SizedBox(width: 8),
                        Text(
                          '${recipe.ingredients.length} ingredients',
                          style: CookbookTheme.bodyStyle(
                            fontSize: 11,
                            color: ink.withValues(alpha: 0.4),
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
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: ink.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiThumb() {
    return Container(
      color: CookbookPalette.lightStroke.withValues(alpha: 0.2),
      child: const Center(
        child: Text('🍽️', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}
