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
    this.imagePath,
    this.dishImagePath,
    this.gridImagePath,
  });

  final String dishName;
  final String tagline;
  final DietaryModifier modifier;
  final List<Ingredient> ingredients;
  final String method;

  /// Path to the original camera photo on disk.
  final String? imagePath;

  /// Path to the AI-generated dish illustration.
  final String? dishImagePath;

  /// Path to the AI-generated ingredients grid illustration.
  final String? gridImagePath;

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
        'imagePath': imagePath,
        'dishImagePath': dishImagePath,
        'gridImagePath': gridImagePath,
      };

  RecipeResult copyWith({
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
        imagePath: imagePath ?? this.imagePath,
        dishImagePath: dishImagePath ?? this.dishImagePath,
        gridImagePath: gridImagePath ?? this.gridImagePath,
      );
}
