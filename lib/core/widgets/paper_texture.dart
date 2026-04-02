import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen paper-grain background with a slow cycling gradient.
///
/// Matches the PaperTextureBackground from the peer repos — subtle dot/fiber
/// noise over a softly shifting warm gradient.
class PaperTextureBackground extends StatefulWidget {
  const PaperTextureBackground({required this.child, super.key});

  final Widget child;

  @override
  State<PaperTextureBackground> createState() =>
      _PaperTextureBackgroundState();
}

class _PaperTextureBackgroundState extends State<PaperTextureBackground>
    with WidgetsBindingObserver {
  static const _cycleDuration = Duration(seconds: 24);
  static const _tickInterval = Duration(milliseconds: 120);
  Timer? _tickTimer;
  double _phase = 0.0;
  bool _animationsDisabled = false;

  static const _variants = <List<Color>>[
    [Color(0xFFE8EFE6), Color(0xFFDCE7D6)], // sage
    [Color(0xFFF0E7DF), Color(0xFFE9DDD2)], // dusty peach
    [Color(0xFFE3EBEF), Color(0xFFD9E3E9)], // pale sky
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncTicker();
  }

  void _syncTicker() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final shouldAnimate =
        !_animationsDisabled && lifecycle == AppLifecycleState.resumed;
    if (!shouldAnimate) {
      _tickTimer?.cancel();
      _tickTimer = null;
      return;
    }
    _tickTimer ??= Timer.periodic(_tickInterval, (_) {
      if (!mounted) return;
      final delta =
          _tickInterval.inMilliseconds / _cycleDuration.inMilliseconds;
      setState(() => _phase = (_phase + delta) % 1.0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final card = theme.cardColor;
    final ink = theme.colorScheme.onSurface;

    final phase = _phase * _variants.length;
    final i = phase.floor() % _variants.length;
    final j = (i + 1) % _variants.length;
    final t = Curves.easeInOut.transform(phase - phase.floor());
    final variantStart = Color.lerp(_variants[i][0], _variants[j][0], t)!;
    final variantEnd = Color.lerp(_variants[i][1], _variants[j][1], t)!;
    final start = Color.lerp(bg, variantStart, 0.16)!;
    final end = Color.lerp(card, variantEnd, 0.12)!;

    final viewportSize = MediaQuery.sizeOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: CustomPaint(
        painter: _PaperGrainPainter(
          seed: 16,
          size: viewportSize,
          ink: ink,
        ),
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter({
    required this.seed,
    required this.size,
    required this.ink,
  });

  final int seed;
  final Size size;
  final Color ink;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final random = math.Random(seed);

    // Gentle wash gradient.
    final washPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
          ink.withValues(alpha: 0.018),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & canvasSize);
    canvas.drawRect(Offset.zero & canvasSize, washPaint);

    // Dot noise — paper tooth.
    final dotPaint = Paint()
      ..color = ink.withValues(alpha: 0.018)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1;
    final area = canvasSize.width * canvasSize.height;
    final dotCount = (area / 190).round().clamp(800, 5200);
    for (var i = 0; i < dotCount; i++) {
      final x = random.nextDouble() * canvasSize.width;
      final y = random.nextDouble() * canvasSize.height;
      canvas.drawCircle(Offset(x, y), 0.6, dotPaint);
    }

    // Fiber strands.
    final fiberPaint = Paint()
      ..color = ink.withValues(alpha: 0.012)
      ..strokeWidth = 0.6;
    final fiberCount = (area / 9000).round().clamp(120, 640);
    for (var i = 0; i < fiberCount; i++) {
      final x = random.nextDouble() * canvasSize.width;
      final y = random.nextDouble() * canvasSize.height;
      final length = 3 + random.nextDouble() * 8;
      canvas.drawLine(Offset(x, y), Offset(x + length, y + 0.5), fiberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter old) =>
      old.seed != seed || old.size != size || old.ink != ink;
}
