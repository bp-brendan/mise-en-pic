import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../theme/cookbook_palette.dart';
import '../theme/cookbook_theme.dart';
import '../widgets/letterpress_card.dart';
import '../widgets/tactile_button.dart';
import 'revenue_cat_providers.dart';

/// Shows the custom credit paywall as a modal bottom sheet.
///
/// Returns `true` if a purchase was completed, `false` otherwise.
Future<bool> showCreditPaywall(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreditPaywallSheet(),
  );
  return result ?? false;
}

class _CreditPaywallSheet extends ConsumerStatefulWidget {
  const _CreditPaywallSheet();

  @override
  ConsumerState<_CreditPaywallSheet> createState() =>
      _CreditPaywallSheetState();
}

class _CreditPaywallSheetState extends ConsumerState<_CreditPaywallSheet> {
  String? _purchasingId;
  bool _restoring = false;
  String? _error;

  Future<void> _handlePurchase(Package package) async {
    setState(() {
      _purchasingId = package.storeProduct.identifier;
      _error = null;
    });

    try {
      await purchaseCredits(package);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _purchasingId = null;
          _error = e.toString().contains('cancelled') ? null : e.toString();
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _restoring = true;
      _error = null;
    });

    try {
      await restorePurchases();
      if (mounted) {
        setState(() => _restoring = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final ink = CookbookPalette.lightInk;
    final offerings = ref.watch(offeringsProvider);

    return Container(
      decoration: BoxDecoration(
        color: CookbookPalette.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: CookbookPalette.lightStroke,
            width: CookbookTheme.strokeWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: bottomPadding + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'GET MORE RECIPES',
              style: CookbookTheme.displayStyle(
                fontSize: 24,
                fontWeight: 760,
                color: ink,
              ).copyWith(
                shadows: CookbookTheme.letterpressShadows(ink),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Each credit generates a full illustrated recipe',
              style: CookbookTheme.bodyStyle(
                fontSize: 14,
                color: ink.withValues(alpha: 0.5),
              ).copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),

            // Product cards
            offerings.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator.adaptive(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Unable to load products.\nPlease try again.',
                  textAlign: TextAlign.center,
                  style: CookbookTheme.bodyStyle(
                    color: CookbookPalette.error,
                  ),
                ),
              ),
              data: (data) {
                final packages =
                    data.current?.availablePackages ?? <Package>[];

                final pack5 = _findPackage(packages, 'credits_5_pack');
                final pack25 = _findPackage(packages, 'credits_25_pack');
                final pack100 = _findPackage(packages, 'credits_100_pack');

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pack5 != null)
                      Expanded(
                        child: _CreditCard(
                          credits: 5,
                          package: pack5,
                          isPurchasing:
                              _purchasingId == pack5.storeProduct.identifier,
                          isDisabled: _purchasingId != null,
                          onTap: () => _handlePurchase(pack5),
                        ),
                      ),
                    if (pack5 != null && pack25 != null)
                      const SizedBox(width: 8),
                    if (pack25 != null)
                      Expanded(
                        child: _CreditCard(
                          credits: 25,
                          package: pack25,
                          badgeLabel: 'POPULAR',
                          isPurchasing:
                              _purchasingId == pack25.storeProduct.identifier,
                          isDisabled: _purchasingId != null,
                          onTap: () => _handlePurchase(pack25),
                        ),
                      ),
                    if (pack25 != null && pack100 != null)
                      const SizedBox(width: 8),
                    if (pack100 != null)
                      Expanded(
                        child: _CreditCard(
                          credits: 100,
                          package: pack100,
                          badgeLabel: 'BEST VALUE',
                          isPurchasing:
                              _purchasingId == pack100.storeProduct.identifier,
                          isDisabled: _purchasingId != null,
                          onTap: () => _handlePurchase(pack100),
                        ),
                      ),
                  ],
                );
              },
            ),

            // Error message
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: CookbookTheme.bodyStyle(
                  fontSize: 13,
                  color: CookbookPalette.error,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Restore purchases
            GestureDetector(
              onTap: _restoring ? null : _handleRestore,
              child: Text(
                _restoring ? 'Restoring...' : 'Restore purchases',
                style: CookbookTheme.bodyStyle(
                  fontSize: 13,
                  color: CookbookPalette.lightAccent,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: CookbookPalette.lightAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Package? _findPackage(List<Package> packages, String productId) {
    for (final p in packages) {
      if (p.storeProduct.identifier == productId) return p;
    }
    return null;
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({
    required this.credits,
    required this.package,
    required this.isPurchasing,
    required this.isDisabled,
    required this.onTap,
    this.badgeLabel,
  });

  final int credits;
  final Package package;
  final bool isPurchasing;
  final bool isDisabled;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final ink = CookbookPalette.lightInk;

    return LetterpressCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge
          if (badgeLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: CookbookPalette.lightAccent,
                borderRadius:
                    BorderRadius.circular(CookbookTheme.brutalRadius),
              ),
              child: Text(
                badgeLabel!,
                style: CookbookTheme.labelStyle(
                  fontSize: 8,
                  color: CookbookPalette.lightCard,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ] else
            const SizedBox(height: 18),

          // Credit count
          Text(
            '$credits',
            style: CookbookTheme.displayStyle(
              fontSize: 32,
              fontWeight: 760,
              color: ink,
            ).copyWith(
              shadows: CookbookTheme.letterpressShadows(ink),
            ),
          ),
          Text(
            'RECIPES',
            style: CookbookTheme.labelStyle(
              fontSize: 9,
              color: ink.withValues(alpha: 0.5),
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 12),

          // Price
          Text(
            package.storeProduct.priceString,
            style: CookbookTheme.titleStyle(
              fontSize: 16,
              color: ink,
            ),
          ),
          const SizedBox(height: 14),

          // Buy button
          SizedBox(
            width: double.infinity,
            child: TactileButton(
              onPressed: isDisabled ? null : onTap,
              color: CookbookPalette.lightAccent,
              size: const Size(double.infinity, 38),
              child: isPurchasing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          CookbookPalette.lightCard,
                        ),
                      ),
                    )
                  : Text(
                      'BUY',
                      style: CookbookTheme.labelStyle(
                        fontSize: 11,
                        color: CookbookPalette.lightCard,
                        letterSpacing: 2.0,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
