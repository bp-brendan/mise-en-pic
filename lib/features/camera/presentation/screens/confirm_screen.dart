import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/purchases/credit_paywall_sheet.dart';
import '../../../../core/purchases/credit_providers.dart';
import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../domain/models/dietary_modifier.dart';
import '../widgets/dietary_toggle_row.dart';

/// Shared confirmation screen: shows frozen image + dietary toggles.
/// Used by both camera capture and gallery pick flows.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  static const _prefKey = 'last_dietary_modifier';
  DietaryModifier _modifier = DietaryModifier.standard;

  @override
  void initState() {
    super.initState();
    _loadSavedModifier();
  }

  Future<void> _loadSavedModifier() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final match = DietaryModifier.values.where((m) => m.name == saved);
      if (match.isNotEmpty && mounted) {
        setState(() => _modifier = match.first);
      }
    }
  }

  Future<void> _saveModifier(DietaryModifier m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, m.name);
  }

  Future<void> _submit() async {
    _saveModifier(_modifier);

    // Pre-flight credit check.
    final hasCredits = ref.read(hasCreditsProvider);
    if (!hasCredits) {
      if (!mounted) return;
      final purchased = await showCreditPaywall(context);
      // If they didn't buy, don't proceed.
      if (!purchased || !mounted) return;
    }

    if (!mounted) return;
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
    final credits = ref.watch(userCreditsProvider).valueOrNull ?? 0;

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
                    onChanged: (m) {
                      setState(() => _modifier = m);
                      _saveModifier(m);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Get Recipe',
                            style: CookbookTheme.titleStyle(
                              fontSize: 15,
                              color: CookbookPalette.lightCard,
                            ),
                          ),
                          if (credits > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  CookbookTheme.brutalRadius,
                                ),
                              ),
                              child: Text(
                                '$credits',
                                style: CookbookTheme.labelStyle(
                                  fontSize: 11,
                                  color: CookbookPalette.lightCard,
                                ),
                              ),
                            ),
                          ],
                        ],
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
