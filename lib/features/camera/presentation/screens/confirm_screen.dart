import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../domain/models/dietary_modifier.dart';
import '../widgets/dietary_toggle_row.dart';

/// Shared confirmation screen: shows frozen image + dietary toggles.
/// Used by both camera capture and gallery pick flows.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  DietaryModifier _modifier = DietaryModifier.vegan;

  void _submit() {
    context.push(
      '/recipe',
      extra: {
        'imageBytes': widget.imageBytes,
        'modifier': _modifier,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Frozen image
          Image.memory(
            widget.imageBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black38,
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomPadding + 24,
                top: 20,
              ),
              decoration: BoxDecoration(
                color: CookbookPalette.lightCard.withValues(alpha: 0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
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
                      color:
                          CookbookPalette.lightInk.withValues(alpha: 0.5),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DietaryToggleRow(
                    selected: _modifier,
                    onChanged: (m) => setState(() => _modifier = m),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
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
            ),
          ),
        ],
      ),
    );
  }
}
