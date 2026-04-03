import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../domain/models/recipe_result.dart';

/// Persists saved recipes as JSON + separate image files.
class RecipeRepository {
  static const _dirName = 'saved_recipes';

  Future<Directory> _recipesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _safeSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Save a recipe with all associated image assets.
  Future<RecipeResult> save(
    RecipeResult recipe,
    Uint8List photoBytes, {
    Uint8List? dishImage,
    Uint8List? gridImage,
  }) async {
    final dir = await _recipesDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final slug = _safeSlug(recipe.dishName);
    final prefix = '${dir.path}/${slug}_$stamp';

    // Save original photo.
    final photoPath = '${prefix}_photo.jpg';
    await File(photoPath).writeAsBytes(photoBytes);

    // Save dish illustration if available.
    String? dishPath;
    if (dishImage != null) {
      dishPath = '${prefix}_dish.png';
      await File(dishPath).writeAsBytes(dishImage);
    }

    // Save ingredients grid if available.
    String? gridPath;
    if (gridImage != null) {
      gridPath = '${prefix}_grid.png';
      await File(gridPath).writeAsBytes(gridImage);
    }

    // Save JSON with image path references.
    final jsonPath = '$prefix.json';
    final updated = recipe.copyWith(
      imagePath: photoPath,
      dishImagePath: dishPath,
      gridImagePath: gridPath,
      jsonPath: jsonPath,
      savedAt: stamp,
    );
    await File(jsonPath).writeAsString(jsonEncode(updated.toJson()));

    return updated;
  }

  /// Update a saved recipe's JSON (e.g. after pin toggle).
  Future<void> _updateJson(RecipeResult recipe) async {
    final path = recipe.jsonPath;
    if (path == null) return;
    await File(path).writeAsString(jsonEncode(recipe.toJson()));
  }

  /// Toggle the pinned state of a recipe.
  Future<RecipeResult> togglePin(RecipeResult recipe) async {
    final updated = recipe.copyWith(isPinned: !recipe.isPinned);
    await _updateJson(updated);
    return updated;
  }

  /// Delete a recipe and all its associated files.
  Future<void> delete(RecipeResult recipe) async {
    final paths = [
      recipe.jsonPath,
      recipe.imagePath,
      recipe.dishImagePath,
      recipe.gridImagePath,
    ];
    for (final path in paths) {
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }

  /// Load all saved recipes, pinned first then newest first.
  Future<List<RecipeResult>> loadAll() async {
    final dir = await _recipesDir();
    if (!await dir.exists()) return [];

    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();

    files.sort((a, b) => b.path.compareTo(a.path));

    final results = <RecipeResult>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        var recipe = RecipeResult.fromJson(json);
        // Backfill jsonPath for older saves that don't have it.
        if (recipe.jsonPath == null) {
          recipe = recipe.copyWith(jsonPath: file.path);
        }
        results.add(recipe);
      } catch (_) {
        // Skip corrupted entries.
      }
    }

    // Sort: pinned first, then by savedAt descending.
    results.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return (b.savedAt ?? 0).compareTo(a.savedAt ?? 0);
    });

    return results;
  }

  /// Read a saved image file.
  Future<Uint8List?> loadImage(String? path) async {
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}
