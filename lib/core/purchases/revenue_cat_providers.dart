import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// The entitlement identifier configured in the RevenueCat dashboard.
const _entitlementId = 'Mise en Pic Pro';

// ── Initialisation ───────────────────────────────────────────────

/// Call once at app startup, before runApp.
Future<void> configureRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug);

  const apiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'test_CWBMStvxrDrqCHQHXnkNPWvgONk',
  );

  final configuration = PurchasesConfiguration(apiKey);
  await Purchases.configure(configuration);
}

// ── Customer Info ────────────────────────────────────────────────

/// Streams [CustomerInfo] updates (purchase, restore, renewal, expiry).
final customerInfoProvider = StreamProvider<CustomerInfo>((ref) {
  final controller = StreamController<CustomerInfo>();

  // Seed with current info.
  Purchases.getCustomerInfo().then(
    (info) => controller.add(info),
    onError: controller.addError,
  );

  // Listen for updates.
  void listener(CustomerInfo info) => controller.add(info);
  Purchases.addCustomerInfoUpdateListener(listener);

  ref.onDispose(() {
    Purchases.removeCustomerInfoUpdateListener(listener);
    controller.close();
  });

  return controller.stream;
});

/// Whether the user currently has the "Mise en Pic Pro" entitlement.
final isProProvider = Provider<bool>((ref) {
  final info = ref.watch(customerInfoProvider).valueOrNull;
  if (info == null) return false;
  return info.entitlements.all[_entitlementId]?.isActive ?? false;
});

// ── Purchases ────────────────────────────────────────────────────

/// Present the RevenueCat paywall only if the entitlement is not active.
Future<PaywallResult> showPaywall() async {
  return RevenueCatUI.presentPaywallIfNeeded(_entitlementId);
}

/// Present the paywall unconditionally (e.g. from a settings button).
Future<PaywallResult> showPaywallAlways() async {
  return RevenueCatUI.presentPaywall();
}

/// Present the Customer Center (manage subscription, request refund, etc.).
Future<void> showCustomerCenter() async {
  await RevenueCatUI.presentCustomerCenter();
}

/// Restore purchases (e.g. after reinstall or new device).
Future<CustomerInfo> restorePurchases() async {
  return Purchases.restorePurchases();
}
