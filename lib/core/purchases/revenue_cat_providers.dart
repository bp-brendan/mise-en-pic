import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ── Initialisation ───────────────────────────────────────────────

/// Call once at app startup, after Firebase.initializeApp() and auth.
Future<void> configureRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug);

  const apiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'test_CWBMStvxrDrqCHQHXnkNPWvgONk',
  );

  final configuration = PurchasesConfiguration(apiKey);
  await Purchases.configure(configuration);
}

/// Link RevenueCat user to Firebase UID so webhooks can map purchases.
/// Call after both auth and RevenueCat are initialised.
Future<void> loginRevenueCat(String uid) async {
  await Purchases.logIn(uid);
}

// ── Customer Info ────────────────────────────────────────────────

/// Streams [CustomerInfo] updates (purchase, restore, expiry).
final customerInfoProvider = StreamProvider<CustomerInfo>((ref) {
  final controller = StreamController<CustomerInfo>();

  Purchases.getCustomerInfo().then(
    (info) => controller.add(info),
    onError: controller.addError,
  );

  void listener(CustomerInfo info) => controller.add(info);
  Purchases.addCustomerInfoUpdateListener(listener);

  ref.onDispose(() {
    Purchases.removeCustomerInfoUpdateListener(listener);
    controller.close();
  });

  return controller.stream;
});

// ── Offerings ────────────────────────────────────────────────────

/// Fetches available product offerings from RevenueCat.
final offeringsProvider = FutureProvider<Offerings>((ref) async {
  return Purchases.getOfferings();
});

// ── Purchases ────────────────────────────────────────────────────

/// Purchase a credit pack via RevenueCat (headless).
/// Returns [CustomerInfo] on success, throws on failure/cancellation.
Future<CustomerInfo> purchaseCredits(Package package) async {
  try {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  } on PlatformException catch (e) {
    final errorCode = PurchasesErrorHelper.getErrorCode(e);
    if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
      throw const _PurchaseCancelledException();
    }
    rethrow;
  }
}

/// Restore purchases (e.g. after reinstall or new device).
Future<CustomerInfo> restorePurchases() async {
  return Purchases.restorePurchases();
}

class _PurchaseCancelledException implements Exception {
  const _PurchaseCancelledException();
  @override
  String toString() => 'Purchase cancelled by user.';
}
