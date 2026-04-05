// ============================================================================
// REVENUECAT SERVICE — KoruBeni Pro abonelik yönetimi
// ============================================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'local_logger_service.dart';

class RevenueCatService {
  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------
  // TODO(BEFORE_RELEASE): Replace with production Android key from RevenueCat dashboard!
  static const String _androidApiKey = 'test_hyyuitzShQIhaUMJcRDQBhwrZBP';
  // TODO(BEFORE_RELEASE): Replace with production iOS key from RevenueCat dashboard before iOS release!
  static const String _iosApiKey = 'REVENUECAT_IOS_API_KEY_PLACEHOLDER';

  /// The entitlement identifier configured in the RevenueCat dashboard.
  static const String entitlementId = 'KoruBeni Pro';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Configure the RevenueCat SDK. Call once at app startup.
  /// Safe to call on web (no-op) and handles errors gracefully.
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.error,
      );

      final apiKey = Platform.isAndroid ? _androidApiKey : _iosApiKey;
      final config = PurchasesConfiguration(apiKey);
      await Purchases.configure(config);
    } catch (e, st) {
      LocalLoggerService.instance.error('RevenueCatService.initialize', e, st);
    }
  }

  // ---------------------------------------------------------------------------
  // Entitlement check
  // ---------------------------------------------------------------------------

  /// Returns true if the given [customerInfo] contains an active KoruBeni Pro
  /// entitlement. RevenueCat caches this locally, so it works offline.
  bool isPro(CustomerInfo customerInfo) {
    return customerInfo.entitlements.active.containsKey(entitlementId);
  }

  // ---------------------------------------------------------------------------
  // Customer info
  // ---------------------------------------------------------------------------

  /// Fetches the latest [CustomerInfo] from RevenueCat (or local cache when
  /// offline). Returns null on failure.
  Future<CustomerInfo?> getCustomerInfo() async {
    if (kIsWeb) return null;
    try {
      return await Purchases.getCustomerInfo();
    } on PlatformException catch (e) {
      LocalLoggerService.instance.error('RevenueCatService.getCustomerInfo', e);
      return null;
    } catch (e) {
      LocalLoggerService.instance.error('RevenueCatService.getCustomerInfo', e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Offerings
  // ---------------------------------------------------------------------------

  /// Returns the current [Offerings] from RevenueCat, or null on failure.
  Future<Offerings?> getOfferings() async {
    if (kIsWeb) return null;
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      LocalLoggerService.instance.error('RevenueCatService.getOfferings', e);
      return null;
    } catch (e) {
      LocalLoggerService.instance.error('RevenueCatService.getOfferings', e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Purchase
  // ---------------------------------------------------------------------------

  /// Initiates a purchase for [package]. Throws a [RevenueCatPurchaseException]
  /// on recoverable errors so the UI can display a meaningful message.
  Future<CustomerInfo> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        throw RevenueCatPurchaseException.cancelled();
      }
      if (errorCode == PurchasesErrorCode.networkError) {
        throw RevenueCatPurchaseException.offline();
      }
      LocalLoggerService.instance.error('RevenueCatService.purchasePackage', e);
      throw RevenueCatPurchaseException(e.message ?? 'Purchase failed');
    } catch (e) {
      LocalLoggerService.instance.error('RevenueCatService.purchasePackage', e);
      throw RevenueCatPurchaseException(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------------------

  /// Restores previous purchases. Returns updated [CustomerInfo] or throws
  /// [RevenueCatPurchaseException] on failure.
  Future<CustomerInfo> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.networkError) {
        throw RevenueCatPurchaseException.offline();
      }
      LocalLoggerService.instance.error(
        'RevenueCatService.restorePurchases',
        e,
      );
      throw RevenueCatPurchaseException(e.message ?? 'Restore failed');
    } catch (e) {
      LocalLoggerService.instance.error(
        'RevenueCatService.restorePurchases',
        e,
      );
      throw RevenueCatPurchaseException(e.toString());
    }
  }
}

// ---------------------------------------------------------------------------
// Exception helper
// ---------------------------------------------------------------------------

class RevenueCatPurchaseException implements Exception {
  final String message;
  final bool isCancelled;
  final bool isOffline;

  const RevenueCatPurchaseException(
    this.message, {
    this.isCancelled = false,
    this.isOffline = false,
  });

  factory RevenueCatPurchaseException.cancelled() =>
      const RevenueCatPurchaseException(
        'Purchase cancelled',
        isCancelled: true,
      );

  factory RevenueCatPurchaseException.offline() =>
      const RevenueCatPurchaseException(
        'No internet connection',
        isOffline: true,
      );

  @override
  String toString() => 'RevenueCatPurchaseException: $message';
}
