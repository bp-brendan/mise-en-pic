import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/motion_config.dart';
import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../domain/models/dietary_modifier.dart';
import '../providers/camera_providers.dart';
import '../widgets/capture_button.dart';
import '../widgets/dietary_toggle_row.dart';

/// Full-screen camera viewfinder with capture → freeze → dietary-toggle flow.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCaptured = false;
  Uint8List? _capturedBytes;
  DietaryModifier _modifier = DietaryModifier.vegan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Prefer back camera.
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    if (!mounted) {
      controller.dispose();
      return;
    }

    setState(() => _controller = controller);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;

    final file = await controller.takePicture();
    final bytes = await file.readAsBytes();

    setState(() {
      _isCaptured = true;
      _capturedBytes = bytes;
    });
  }

  void _retake() {
    setState(() {
      _isCaptured = false;
      _capturedBytes = null;
    });
  }

  void _submit() {
    if (_capturedBytes == null) return;
    context.push(
      '/recipe',
      extra: {
        'imageBytes': _capturedBytes!,
        'modifier': _modifier,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview or frozen frame.
          if (_isCaptured && _capturedBytes != null)
            Image.memory(
              _capturedBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          else if (controller != null && controller.value.isInitialized)
            CameraPreview(controller)
          else
            const Center(
              child: CircularProgressIndicator(
                color: CookbookPalette.lightCard,
              ),
            ),

          // Bottom controls.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControls(context),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedSwitcher(
      duration: MotionConfig.routeTransition,
      switchInCurve: MotionConfig.routeCurve,
      switchOutCurve: MotionConfig.routeReverseCurve,
      child: _isCaptured
          ? _ConfirmationControls(
              key: const ValueKey('confirm'),
              modifier: _modifier,
              onModifierChanged: (m) => setState(() => _modifier = m),
              onRetake: _retake,
              onSubmit: _submit,
              bottomPadding: bottomPadding,
            )
          : _CaptureControls(
              key: const ValueKey('capture'),
              onCapture: _capture,
              bottomPadding: bottomPadding,
            ),
    );
  }
}

class _CaptureControls extends StatelessWidget {
  const _CaptureControls({
    super.key,
    required this.onCapture,
    required this.bottomPadding,
  });

  final VoidCallback onCapture;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding + 24, top: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(child: CaptureButton(onPressed: onCapture)),
    );
  }
}

class _ConfirmationControls extends StatelessWidget {
  const _ConfirmationControls({
    super.key,
    required this.modifier,
    required this.onModifierChanged,
    required this.onRetake,
    required this.onSubmit,
    required this.bottomPadding,
  });

  final DietaryModifier modifier;
  final ValueChanged<DietaryModifier> onModifierChanged;
  final VoidCallback onRetake;
  final VoidCallback onSubmit;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 24,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: CookbookPalette.lightCard.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: CookbookPalette.lightStroke,
            width: CookbookTheme.strokeWidth,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DIETARY PREFERENCE',
            style: CookbookTheme.labelStyle(
              color: CookbookPalette.lightInk.withValues(alpha: 0.5),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          DietaryToggleRow(
            selected: modifier,
            onChanged: onModifierChanged,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetake,
                  child: Text(
                    'Retake',
                    style: CookbookTheme.titleStyle(
                      fontSize: 15,
                      color: CookbookPalette.lightInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onSubmit,
                  child: Text(
                    'Get Recipe',
                    style: CookbookTheme.titleStyle(
                      fontSize: 15,
                      color: CookbookPalette.lightCard,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
