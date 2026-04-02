import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../shared/painters/watercolor_painter.dart';

/// Displays the captured food photo with the watercolor/lithograph treatment.
///
/// Decodes [imageBytes] into a `ui.Image` then hands off to
/// [WatercolorPainter] for rendering.
class CookbookIllustration extends StatefulWidget {
  const CookbookIllustration({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<CookbookIllustration> createState() => _CookbookIllustrationState();
}

class _CookbookIllustrationState extends State<CookbookIllustration> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void didUpdateWidget(covariant CookbookIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.imageBytes, widget.imageBytes)) {
      _decodeImage();
    }
  }

  Future<void> _decodeImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _image = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CustomPaint(
        painter: WatercolorPainter(image: image),
        size: Size.infinite,
      ),
    );
  }
}
