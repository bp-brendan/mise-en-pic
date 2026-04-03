import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/purchases/credit_paywall_sheet.dart';
import '../../../../core/purchases/credit_providers.dart';
import '../../../../core/theme/cookbook_palette.dart';
import '../../../../core/theme/cookbook_theme.dart';
import '../../../../core/widgets/tactile_button.dart';

/// Front page with three entry points: camera, gallery, saved recipes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !context.mounted) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    context.push('/confirm', extra: {'imageBytes': bytes});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final credits = ref.watch(userCreditsProvider).valueOrNull ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Credit count / buy button
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => showCreditPaywall(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius:
                          BorderRadius.circular(CookbookTheme.brutalRadius),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: CookbookTheme.strokeWidth,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: CookbookPalette.lightAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$credits',
                          style: CookbookTheme.titleStyle(
                            fontSize: 14,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Logo / title area
              Text(
                '\u{1F37D}\u{FE0F}',
                style: const TextStyle(fontSize: 56),
              ),
              const SizedBox(height: 12),
              Text(
                'MISE EN PIC',
                textAlign: TextAlign.center,
                style: CookbookTheme.displayStyle(
                  fontSize: 36,
                  fontWeight: 760,
                  color: ink,
                ).copyWith(
                  shadows: CookbookTheme.letterpressShadows(ink),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Snap a dish. Get the recipe.',
                style: CookbookTheme.bodyStyle(
                  fontSize: 15,
                  color: ink.withValues(alpha: 0.5),
                ).copyWith(fontStyle: FontStyle.italic),
              ),

              const Spacer(flex: 2),

              // Action buttons
              _HomeActionCard(
                icon: Icons.camera_alt_outlined,
                label: 'TAKE A PHOTO',
                subtitle: 'Use your camera to snap a dish',
                onPressed: () => context.push('/camera'),
              ),
              const SizedBox(height: 12),
              _HomeActionCard(
                icon: Icons.photo_library_outlined,
                label: 'FROM GALLERY',
                subtitle: 'Pick a food photo you already have',
                onPressed: () => _pickFromGallery(context),
              ),
              const SizedBox(height: 12),
              _HomeActionCard(
                icon: Icons.bookmark_outline,
                label: 'SAVED RECIPES',
                subtitle: 'Your cookbook collection',
                onPressed: () => context.push('/saved'),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;

    return TactileButton(
      onPressed: onPressed,
      size: const Size(double.infinity, 72),
      borderRadius: BorderRadius.circular(CookbookTheme.brutalRadius),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Icon(icon, size: 26, color: CookbookPalette.lightAccent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: CookbookTheme.labelStyle(
                    fontSize: 12,
                    color: ink,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: CookbookTheme.bodyStyle(
                    fontSize: 12,
                    color: ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: ink.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
