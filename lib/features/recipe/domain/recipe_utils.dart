import 'models/recipe_result.dart';

/// Shared utilities for recipe display, extracted from the former GeminiService.
class RecipeUtils {
  RecipeUtils._();

  /// Grid layout: 4 columns for ingredient sprites (used by UI).
  static const gridColumns = 4;

  /// Pantry staples that don't need a sprite illustration.
  static const _staples = {
    'salt', 'pepper', 'black pepper', 'oil', 'olive oil', 'vegetable oil',
    'canola oil', 'cooking oil', 'water', 'ice', 'flour', 'all-purpose flour',
    'sugar', 'granulated sugar', 'brown sugar', 'butter', 'unsalted butter',
    'garlic', 'kosher salt', 'sea salt', 'cornstarch', 'baking powder',
    'baking soda',
  };

  /// Returns indices of ingredients worth illustrating (non-staples, max 6).
  static List<int> featuredIndices(List<Ingredient> ingredients) {
    final indices = <int>[];
    for (var i = 0; i < ingredients.length; i++) {
      final name = ingredients[i].name.toLowerCase().trim();
      if (!_staples.contains(name)) indices.add(i);
      if (indices.length >= 6) break;
    }
    return indices;
  }
}
