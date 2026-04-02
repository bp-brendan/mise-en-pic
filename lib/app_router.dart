import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/config/motion_config.dart';
import 'features/camera/domain/models/dietary_modifier.dart';
import 'features/camera/presentation/screens/camera_screen.dart';
import 'features/recipe/presentation/screens/recipe_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CameraScreen(),
    ),
    GoRoute(
      path: '/recipe',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final imageBytes = extra['imageBytes'] as Uint8List;
        final modifier = extra['modifier'] as DietaryModifier;

        return CustomTransitionPage(
          key: state.pageKey,
          child: RecipeScreen(
            imageBytes: imageBytes,
            modifier: modifier,
          ),
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
              child: ScaleTransition(
                scale: scale,
                child: child,
              ),
            );
          },
        );
      },
    ),
  ],
);
