import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/config/motion_config.dart';
import 'features/camera/domain/models/dietary_modifier.dart';
import 'features/camera/presentation/screens/camera_screen.dart';
import 'features/camera/presentation/screens/confirm_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/recipe/domain/models/recipe_result.dart';
import 'features/recipe/presentation/screens/recipe_screen.dart';
import 'features/saved/presentation/screens/saved_recipe_detail_screen.dart';
import 'features/saved/presentation/screens/saved_recipes_screen.dart';

CustomTransitionPage<void> _scaleFadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: MotionConfig.routeTransition,
    reverseTransitionDuration: MotionConfig.routeTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final scale = Tween<double>(
        begin: MotionConfig.routeBeginScale,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: MotionConfig.routeCurve,
      ));
      final fade = CurvedAnimation(
        parent: animation,
        curve: MotionConfig.routeCurve,
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/camera',
      pageBuilder: (context, state) => _scaleFadePage(
        key: state.pageKey,
        child: const CameraScreen(),
      ),
    ),
    GoRoute(
      path: '/confirm',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final imageBytes = extra['imageBytes'] as Uint8List;
        return _scaleFadePage(
          key: state.pageKey,
          child: ConfirmScreen(imageBytes: imageBytes),
        );
      },
    ),
    GoRoute(
      path: '/recipe',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final imageBytes = extra['imageBytes'] as Uint8List;
        final modifier = extra['modifier'] as DietaryModifier;
        return _scaleFadePage(
          key: state.pageKey,
          child: RecipeScreen(
            imageBytes: imageBytes,
            modifier: modifier,
          ),
        );
      },
    ),
    GoRoute(
      path: '/saved',
      pageBuilder: (context, state) => _scaleFadePage(
        key: state.pageKey,
        child: const SavedRecipesScreen(),
      ),
    ),
    GoRoute(
      path: '/saved/view',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final recipe = extra['recipe'] as RecipeResult;
        return _scaleFadePage(
          key: state.pageKey,
          child: SavedRecipeDetailScreen(recipe: recipe),
        );
      },
    ),
  ],
);
