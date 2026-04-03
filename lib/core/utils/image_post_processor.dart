import 'dart:typed_data';
import 'dart:ui' as ui;

/// Replaces the background color in Gemini-generated images with the exact
/// app background color (#E8EFE6) so illustrations blend seamlessly.
///
/// Approach: sample the image corners to find the approximate background color,
/// then replace all pixels within a tolerance of that color.
class ImagePostProcessor {
  ImagePostProcessor._();

  // Target: CookbookPalette.lightBackground = Color(0xFFE8EFE6)
  static const int _targetR = 232;
  static const int _targetG = 239;
  static const int _targetB = 230;

  /// Replace the dominant background color with the exact app background.
  /// Returns new PNG bytes with the corrected background.
  static Future<Uint8List> fixBackground(Uint8List imageBytes) async {
    // Decode to raw pixels.
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return imageBytes;

    final width = image.width;
    final height = image.height;
    final pixels = byteData.buffer.asUint8List();

    // Sample corners and edges to find the background color.
    final bgColor = _detectBackgroundColor(pixels, width, height);
    if (bgColor == null) return imageBytes;

    final bgR = bgColor[0], bgG = bgColor[1], bgB = bgColor[2];

    // Replace pixels close to the detected background with our exact target.
    // Use a generous tolerance since watercolor edges are fuzzy.
    const tolerance = 38;

    for (var i = 0; i < pixels.length; i += 4) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      // alpha at i+3

      final dr = (r - bgR).abs();
      final dg = (g - bgG).abs();
      final db = (b - bgB).abs();

      if (dr < tolerance && dg < tolerance && db < tolerance) {
        // Blend: pixels closer to the detected bg get fully replaced,
        // pixels near the edge get partially blended.
        final maxDelta = dr > dg ? (dr > db ? dr : db) : (dg > db ? dg : db);
        if (maxDelta < tolerance ~/ 2) {
          // Solidly background — replace entirely.
          pixels[i] = _targetR;
          pixels[i + 1] = _targetG;
          pixels[i + 2] = _targetB;
        } else {
          // Transition zone — blend toward target.
          final t = (maxDelta - tolerance ~/ 2) / (tolerance ~/ 2);
          pixels[i] = _lerp(_targetR, r, t);
          pixels[i + 1] = _lerp(_targetG, g, t);
          pixels[i + 2] = _lerp(_targetB, b, t);
        }
      }
    }

    // Re-encode as PNG.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final correctedCodec = await ui.ImageDescriptor.raw(
      await ui.ImmutableBuffer.fromUint8List(pixels),
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    ).instantiateCodec();
    final correctedFrame = await correctedCodec.getNextFrame();

    canvas.drawImage(correctedFrame.image, ui.Offset.zero, ui.Paint());
    final picture = recorder.endRecording();
    final result = await picture.toImage(width, height);
    final pngData = await result.toByteData(format: ui.ImageByteFormat.png);

    result.dispose();
    correctedFrame.image.dispose();
    image.dispose();

    return pngData?.buffer.asUint8List() ?? imageBytes;
  }

  /// Detect the background color by sampling corners and edges.
  static List<int>? _detectBackgroundColor(
      Uint8List pixels, int width, int height) {
    // Sample 20 pixels from corners and edges.
    final samples = <List<int>>[];
    final positions = <int>[
      // Corners (2px in from each edge)
      _pixelIndex(2, 2, width),
      _pixelIndex(width - 3, 2, width),
      _pixelIndex(2, height - 3, width),
      _pixelIndex(width - 3, height - 3, width),
      // Mid-edges
      _pixelIndex(width ~/ 2, 1, width),
      _pixelIndex(width ~/ 2, height - 2, width),
      _pixelIndex(1, height ~/ 2, width),
      _pixelIndex(width - 2, height ~/ 2, width),
      // Quarter points along edges
      _pixelIndex(width ~/ 4, 1, width),
      _pixelIndex(3 * width ~/ 4, 1, width),
      _pixelIndex(width ~/ 4, height - 2, width),
      _pixelIndex(3 * width ~/ 4, height - 2, width),
    ];

    for (final idx in positions) {
      if (idx + 3 < pixels.length) {
        samples.add([pixels[idx], pixels[idx + 1], pixels[idx + 2]]);
      }
    }

    if (samples.length < 4) return null;

    // Average the samples.
    var sumR = 0, sumG = 0, sumB = 0;
    for (final s in samples) {
      sumR += s[0];
      sumG += s[1];
      sumB += s[2];
    }
    return [
      sumR ~/ samples.length,
      sumG ~/ samples.length,
      sumB ~/ samples.length,
    ];
  }

  static int _pixelIndex(int x, int y, int width) => (y * width + x) * 4;

  static int _lerp(int a, int b, double t) =>
      (a + (b - a) * t.clamp(0.0, 1.0)).round().clamp(0, 255);
}
