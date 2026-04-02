import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cookbook_palette.dart';
import '../theme/cookbook_theme.dart';

/// A debossed, tactile button with the suite's signature press animation.
///
/// 48ms forward (easeOutCubic), 120ms reverse (easeInQuad), 1.2px Y shift,
/// shadow lift recedes on press.
class TactileButton extends StatefulWidget {
  const TactileButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.borderColor,
    this.size,
    this.isCircular = false,
    this.haptic = true,
    this.borderRadius,
    this.semanticLabel,
    this.padding,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final Size? size;
  final bool isCircular;
  final bool haptic;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final EdgeInsetsGeometry? padding;

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 48),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _pressAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInQuad,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
    if (widget.haptic) HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails _) => _pressController.reverse();
  void _handleTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = widget.color ?? theme.cardColor;
    final border = widget.borderColor ?? theme.colorScheme.outline;
    final shape = widget.isCircular ? BoxShape.circle : BoxShape.rectangle;

    return GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      onTap: widget.onPressed,
      child: Semantics(
        label: widget.semanticLabel,
        button: true,
        enabled: widget.onPressed != null,
        child: AnimatedBuilder(
          animation: _pressAnimation,
          builder: (context, child) {
            final press = _pressAnimation.value;
            final lift = 0.5 * (1.0 - press);
            final radius = widget.isCircular
                ? null
                : widget.borderRadius ??
                    BorderRadius.circular(CookbookTheme.brutalRadius);

            return Container(
              width: widget.size?.width,
              height: widget.size?.height,
              decoration: BoxDecoration(
                color: Color.lerp(
                  surface,
                  surface.withValues(alpha: 0.92),
                  press,
                ),
                shape: shape,
                borderRadius: radius,
                border: Border.all(
                  color: border,
                  width: CookbookTheme.strokeWidth,
                ),
                boxShadow: CookbookTheme.paperElevationShadows(lift: lift),
              ),
              transform: Matrix4.translationValues(0, press * 1.2, 0),
              child: ClipPath(
                clipper: widget.isCircular
                    ? const ShapeBorderClipper(shape: CircleBorder())
                    : ShapeBorderClipper(
                        shape: RoundedRectangleBorder(
                          borderRadius: radius!,
                        ),
                      ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const CustomPaint(painter: _VellumTexturePainter()),
                    Align(alignment: Alignment.center, child: child),
                  ],
                ),
              ),
            );
          },
          child: DefaultTextStyle.merge(
            style: CookbookTheme.labelStyle(
              color: theme.colorScheme.onSurface,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                color: theme.colorScheme.onSurface,
                size: 22,
              ),
              child: widget.padding != null
                  ? Padding(padding: widget.padding!, child: widget.child)
                  : widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _VellumTexturePainter extends CustomPainter {
  const _VellumTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CookbookPalette.debossHighlight.withValues(alpha: 0.075),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _VellumTexturePainter old) => false;
}
