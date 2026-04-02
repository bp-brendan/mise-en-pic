import 'package:flutter/material.dart';

import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/widgets/tactile_button.dart';

/// Large circular capture button for the camera viewfinder.
class CaptureButton extends StatelessWidget {
  const CaptureButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TactileButton(
      onPressed: onPressed,
      isCircular: true,
      size: const Size(72, 72),
      color: CookbookPalette.lightCard,
      borderColor: CookbookPalette.lightStroke,
      semanticLabel: 'Capture photo',
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: CookbookPalette.lightInk.withValues(alpha: 0.3),
            width: 2.5,
          ),
        ),
      ),
    );
  }
}
