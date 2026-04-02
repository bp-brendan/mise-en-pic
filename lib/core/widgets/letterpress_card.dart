import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/cookbook_palette.dart';
import '../theme/cookbook_theme.dart';

/// A card with the suite's signature letterpress/deboss visual treatment:
/// multi-layer shadows, specular highlight, cut-edge darkening, paper grain.
class LetterpressCard extends StatelessWidget {
  const LetterpressCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = CookbookTheme.brutalRadius,
    this.surfaceColor,
    this.borderColor,
    this.lift = 0.5,
    this.seed,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? surfaceColor;
  final Color? borderColor;
  final double lift;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = surfaceColor ?? theme.cardTheme.color ?? theme.cardColor;
    final border = borderColor ?? theme.colorScheme.outline;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: border,
            width: CookbookTheme.strokeWidth * 0.8,
          ),
          boxShadow: CookbookTheme.paperElevationShadows(lift: lift),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 0.5),
          child: CustomPaint(
            painter: _CardImpressionPainter(
              seed: seed ?? identityHashCode(this),
              ink: theme.colorScheme.onSurface,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SpecularEdgePainter(radius: radius),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CutEdgePainter(radius: radius),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle grain impression unique to each card instance.
class _CardImpressionPainter extends CustomPainter {
  const _CardImpressionPainter({required this.seed, required this.ink});
  final int seed;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(seed);

    // Subtle top-to-bottom darkening (letterpress bite depth).
    final depthPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          ink.withValues(alpha: 0.018),
          ink.withValues(alpha: 0.032),
        ],
        stops: const [0.25, 0.68, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, depthPaint);

    // Salty ink specks.
    final salt = Paint()
      ..color = ink.withValues(alpha: 0.022)
      ..style = PaintingStyle.fill;
    final area = size.width * size.height;
    final speckCount = (area / 850).round().clamp(35, 220);
    for (var i = 0; i < speckCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = 0.22 + random.nextDouble() * 0.42;
      canvas.drawCircle(Offset(x, y), r, salt);
    }

    // Soft overprint haze.
    final overprint = Paint()
      ..shader = RadialGradient(
        colors: [ink.withValues(alpha: 0.02), Colors.transparent],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.72, size.height * 0.18),
          radius: size.shortestSide * 0.42,
        ),
      );
    canvas.drawRect(Offset.zero & size, overprint);
  }

  @override
  bool shouldRepaint(covariant _CardImpressionPainter old) =>
      seed != old.seed || ink != old.ink;
}

/// Top/left specular highlight — light catching the raised paper edge.
class _SpecularEdgePainter extends CustomPainter {
  const _SpecularEdgePainter({required this.radius});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final highlight =
        CookbookPalette.debossHighlight.withValues(alpha: 0.18);
    final transparent =
        CookbookPalette.debossHighlight.withValues(alpha: 0.0);

    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [highlight, transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 1.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 1.5), topPaint);

    final leftPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [highlight, transparent],
      ).createShader(Rect.fromLTWH(0, 0, 1.5, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, 1.5, size.height), leftPaint);
  }

  @override
  bool shouldRepaint(covariant _SpecularEdgePainter old) =>
      radius != old.radius;
}

/// Right/bottom cut edge — subtle darkened strip for chiseled depth.
class _CutEdgePainter extends CustomPainter {
  const _CutEdgePainter({required this.radius});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shadow = Colors.black.withValues(alpha: 0.04);
    canvas.drawRect(
      Rect.fromLTWH(size.width - 1, 0, 1, size.height),
      Paint()..color = shadow,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = shadow,
    );
  }

  @override
  bool shouldRepaint(covariant _CutEdgePainter old) => false;
}
