import '../../../camera/domain/models/dietary_modifier.dart';

/// A single ingredient with its emoji and visual description.
class Ingredient {
  const Ingredient({
    required this.emoji,
    required this.amount,
    required this.name,
    this.visual = '',
  });

  final String emoji;
  final String amount;
  final String name;

  /// Brief visual description of the raw ingredient state
  /// (e.g. "halved, showing rings"). Used to drive image generation.
  final String visual;

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      emoji: json['emoji'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      name: json['name'] as String? ?? '',
      visual: json['visual'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'amount': amount,
        'name': name,
        'visual': visual,
      };
}

/// Structured recipe result from Gemini.
class RecipeResult {
  const RecipeResult({
    required this.dishName,
    required this.tagline,
    required this.modifier,
    required this.ingredients,
    required this.method,
    this.prepTime = '',
    this.cookTime = '',
    this.servings = '',
    this.caloriesPerServing,
    this.isPinned = false,
    this.savedAt,
    this.jsonPath,
    this.imagePath,
    this.dishImagePath,
    this.gridImagePath,
  });

  final String dishName;
  final String tagline;
  final DietaryModifier modifier;
  final List<Ingredient> ingredients;
  final String method;
  final String prepTime;
  final String cookTime;
  final String servings;
  final int? caloriesPerServing;
  final bool isPinned;
  final int? savedAt; // millisecondsSinceEpoch

  /// Path to the JSON file on disk (for updates/deletes).
  final String? jsonPath;

  /// Path to the original camera photo on disk.
  final String? imagePath;

  /// Path to the AI-generated dish illustration.
  final String? dishImagePath;

  /// Path to the AI-generated ingredients grid illustration.
  final String? gridImagePath;

  /// Parse the method string into individual numbered steps.
  List<String> get steps {
    // Split on patterns like "1.", "2.", etc. at the start of a line or after newline.
    final raw = method.split(RegExp(r'\n?\d+\.\s*'));
    return raw.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
  }

  /// For a given step, find which ingredient indices are mentioned in it.
  List<int> ingredientIndicesForStep(String stepText) {
    final lower = stepText.toLowerCase();
    final matches = <int>[];
    for (var i = 0; i < ingredients.length; i++) {
      final name = ingredients[i].name.toLowerCase();
      // Match on the main word (skip very short names like "oil" to avoid false positives)
      if (name.length > 3 && lower.contains(name)) {
        matches.add(i);
      } else if (name.length <= 3) {
        // For short names, require word boundary
        if (RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(lower)) {
          matches.add(i);
        }
      }
    }
    return matches;
  }

  factory RecipeResult.fromJson(Map<String, dynamic> json) {
    return RecipeResult(
      dishName: json['dishName'] as String? ?? 'Mystery Dish',
      tagline: json['tagline'] as String? ?? '',
      modifier: DietaryModifier.values.firstWhere(
        (m) => m.name == (json['modifier'] as String? ?? 'vegan'),
        orElse: () => DietaryModifier.vegan,
      ),
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      method: json['method'] as String? ?? '',
      prepTime: json['prepTime'] as String? ?? '',
      cookTime: json['cookTime'] as String? ?? '',
      servings: json['servings'] as String? ?? '',
      caloriesPerServing: json['caloriesPerServing'] as int?,
      isPinned: json['isPinned'] as bool? ?? false,
      savedAt: json['savedAt'] as int?,
      jsonPath: json['jsonPath'] as String?,
      imagePath: json['imagePath'] as String?,
      dishImagePath: json['dishImagePath'] as String?,
      gridImagePath: json['gridImagePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'dishName': dishName,
        'tagline': tagline,
        'modifier': modifier.name,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'method': method,
        'prepTime': prepTime,
        'cookTime': cookTime,
        'servings': servings,
        'caloriesPerServing': caloriesPerServing,
        'isPinned': isPinned,
        'savedAt': savedAt,
        'jsonPath': jsonPath,
        'imagePath': imagePath,
        'dishImagePath': dishImagePath,
        'gridImagePath': gridImagePath,
      };

  RecipeResult copyWith({
    bool? isPinned,
    int? savedAt,
    String? jsonPath,
    String? imagePath,
    String? dishImagePath,
    String? gridImagePath,
  }) =>
      RecipeResult(
        dishName: dishName,
        tagline: tagline,
        modifier: modifier,
        ingredients: ingredients,
        method: method,
        prepTime: prepTime,
        cookTime: cookTime,
        servings: servings,
        caloriesPerServing: caloriesPerServing,
        isPinned: isPinned ?? this.isPinned,
        savedAt: savedAt ?? this.savedAt,
        jsonPath: jsonPath ?? this.jsonPath,
        imagePath: imagePath ?? this.imagePath,
        dishImagePath: dishImagePath ?? this.dishImagePath,
        gridImagePath: gridImagePath ?? this.gridImagePath,
      );
}
