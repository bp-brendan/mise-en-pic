import 'package:flutter/animation.dart';

/// Shared animation constants aligned with the peer repos.
class MotionConfig {
  MotionConfig._();

  /// Route transition duration (matches Loom's 380ms).
  static const Duration routeTransition = Duration(milliseconds: 380);

  /// Route entrance scale origin (element scales from 90% → 100%).
  static const double routeBeginScale = 0.90;

  /// Standard curve for forward transitions.
  static const Curve routeCurve = Curves.easeOutCubic;

  /// Standard curve for reverse transitions.
  static const Curve routeReverseCurve = Curves.easeInQuad;

  /// Button press-down duration.
  static const Duration pressDown = Duration(milliseconds: 48);

  /// Button release duration.
  static const Duration pressUp = Duration(milliseconds: 120);

  /// Vertical pixel shift on button press.
  static const double pressTranslateY = 1.2;

  /// Loading shimmer cycle duration.
  static const Duration shimmerCycle = Duration(milliseconds: 1400);
}
