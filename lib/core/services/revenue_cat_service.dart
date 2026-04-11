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
  static const String _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const bool _isProduction =
      String.fromEnvironment('ENV') == 'production';

  /// The entitlement identifier configured in the RevenueCat dashboard.
  static const String entitlementId = 'KoruBeni Pro';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Configure the RevenueCat SDK. Call once at app startup.
  /// Android-only Google Play billing setup.
  Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (_androidApiKey.isEmpty) {
        if (_isProduction) {
          throw StateError('RevenueCat Android API key is not configured');
        }
        await LocalLoggerService.instance.warning(
          'RevenueCatService.initialize',
          'RevenueCat disabled: Android API key is not configured',
        );
        return;
      }
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

      final config = PurchasesConfiguration(_androidApiKey);
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
    if (kIsWeb || !Platform.isAndroid) return null;
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
    if (kIsWeb || !Platform.isAndroid) return null;
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
      throw RevenueCatPurchaseException.generic();
    } catch (e) {
      LocalLoggerService.instance.error('RevenueCatService.purchasePackage', e);
      throw RevenueCatPurchaseException.generic();
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
      throw RevenueCatPurchaseException.generic();
    } catch (e) {
      LocalLoggerService.instance.error(
        'RevenueCatService.restorePurchases',
        e,
      );
      throw RevenueCatPurchaseException.generic();
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

  factory RevenueCatPurchaseException.generic() =>
      const RevenueCatPurchaseException('Purchase service unavailable');

  @override
  String toString() => 'RevenueCatPurchaseException: $message';
}
