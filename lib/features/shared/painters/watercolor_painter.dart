import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Placeholder stylized painter that applies a vintage cookbook illustration
/// effect over a captured food image.
///
/// This is the structural scaffold for a future Fragment Shader
/// (`ui.FragmentProgram`). For now it composites desaturated washes, edge
/// vignettes, and paper-grain noise to approximate a watercolor/lithograph
/// aesthetic.
class WatercolorPainter extends CustomPainter {
  const WatercolorPainter({
    required this.image,
    this.seed = 42,
  });

  final ui.Image image;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Offset.zero & size;

    // Base image — slightly desaturated for a faded print look.
    final desatMatrix = ColorFilter.matrix(<double>[
      0.72, 0.18, 0.10, 0, 8, //
      0.14, 0.72, 0.14, 0, 8, //
      0.10, 0.18, 0.72, 0, 8, //
      0, 0, 0, 1, 0, //
    ]);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..colorFilter = desatMatrix,
    );

    // Warm sepia wash overlay.
    canvas.drawRect(
      dst,
      Paint()
        ..color = const Color(0xFFF5ECD7).withValues(alpha: 0.18)
        ..blendMode = BlendMode.softLight,
    );

    // Vignette — darkened edges like an aged print.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.3),
        ],
        stops: const [0.55, 1.0],
      ).createShader(dst);
    canvas.drawRect(dst, vignette);

    // Paper grain specks.
    final random = math.Random(seed);
    final grainPaint = Paint()
      ..color = const Color(0xFF1D1C19).withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    final speckCount = (size.width * size.height / 600).round().clamp(100, 800);
    for (var i = 0; i < speckCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = 0.3 + random.nextDouble() * 0.6;
      canvas.drawCircle(Offset(x, y), r, grainPaint);
    }

    // Thin border — plate-mark from a printing press.
    canvas.drawRect(
      dst.deflate(4),
      Paint()
        ..color = const Color(0xFF1D1C19).withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant WatercolorPainter old) => old.image != image;
}
