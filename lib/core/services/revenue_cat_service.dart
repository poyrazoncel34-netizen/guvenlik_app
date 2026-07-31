// ============================================================================
// REVENUECAT SERVICE — KoruBeni Pro abonelik yönetimi
// ============================================================================

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/legal_texts.dart';
import '../config/app_environment.dart';
import '../constants/app_constants.dart';
import 'emergency_session_contract.dart';
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

  /// Non-sensitive, local-only reason to refresh RevenueCat after a restart.
  /// This value is never entitlement proof and never grants access itself.
  static const String priorProInitializationHintKey =
      'revenuecat_prior_verified_pro_hint_v1';

  /// Moment of the last verified-Pro answer, as milliseconds since epoch.
  /// Only meaningful together with [priorProInitializationHintKey]; on its own
  /// it is not treated as evidence of anything.
  static const String lastVerifiedProAtKey =
      'revenuecat_last_verified_pro_at_v1';

  bool _isConfigured = false;
  Future<bool>? _initializationFuture;

  bool get isConfigured => _isConfigured;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Backwards-compatible initializer. Callers should invoke it only from a
  /// Pro/paywall/restore path or from the historical-Pro hint path.
  Future<void> initialize() async {
    await ensureInitialized();
  }

  /// Lazily configures the Android SDK after current Terms and KVKK acceptance.
  /// `false` is an explicit unavailable/unknown result, never a free decision.
  Future<bool> ensureInitialized() {
    if (_isConfigured) return Future<bool>.value(true);
    return _initializationFuture ??= _initializeOnce().whenComplete(() {
      _initializationFuture = null;
    });
  }

  Future<bool> _initializeOnce() async {
    if (kIsWeb || !Platform.isAndroid) {
      _isConfigured = false;
      return false;
    }

    // Purchases.configure may create an anonymous RevenueCat identity and may
    // perform network I/O. Never call it until both current legal documents
    // have been accepted.
    if (!await hasCurrentLegalAcceptance()) {
      _isConfigured = false;
      await LocalLoggerService.instance.warningCode(
        LocalWarningCode.revenueCatLegalAcceptanceRequired,
      );
      return false;
    }

    try {
      if (AppEnvironment.isCiSmoke &&
          _androidApiKey == AppEnvironment.ciSmokeRevenueCatKey) {
        _isConfigured = false;
        await LocalLoggerService.instance.warningCode(
          LocalWarningCode.revenueCatDisabledInSmoke,
        );
        return false;
      }
      if (_androidApiKey.isEmpty) {
        _isConfigured = false;
        await LocalLoggerService.instance.warningCode(
          LocalWarningCode.revenueCatApiKeyMissing,
        );
        return false;
      }
      final isAllowedClientKey = _isProduction
          ? AppEnvironment.isProductionRevenueCatAndroidSdkKey(_androidApiKey)
          : AppEnvironment.isSafeRevenueCatClientSdkKey(_androidApiKey);
      if (!isAllowedClientKey) {
        _isConfigured = false;
        throw StateError(
          'RevenueCat key is not valid for this Android environment',
        );
      }
      // RevenueCat debug logs can include anonymous customer identifiers and
      // purchase metadata. Keep SDK logging at error even in debug builds.
      await Purchases.setLogLevel(LogLevel.error);

      final config = PurchasesConfiguration(_androidApiKey)
        ..entitlementVerificationMode =
            EntitlementVerificationMode.informational
        ..automaticDeviceIdentifierCollectionEnabled = false
        ..diagnosticsEnabled = false;
      await Purchases.configure(config);
      _isConfigured = true;
      return true;
    } catch (_) {
      _isConfigured = false;
      _logSanitizedFailure(LocalErrorCode.revenueCatInitializeFailed);
      return false;
    }
  }

  /// Legal gate used by every lazy initialization entry point.
  Future<bool> hasCurrentLegalAcceptance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accepted =
          (prefs.getBool(AppConstants.prefLegalDisclaimerAccepted) ?? false) ||
          (prefs.getBool(AppConstants.prefLegalAcceptedV1) ?? false);
      return accepted &&
          prefs.getString(AppConstants.prefTermsVersion) ==
              LegalTexts.termsVersion &&
          prefs.getString(AppConstants.prefKvkkVersion) ==
              LegalTexts.kvkkVersion;
    } catch (_) {
      _logSanitizedFailure(LocalErrorCode.revenueCatLegalStateReadFailed);
      return false;
    }
  }

  Future<bool> hasPriorProInitializationHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(priorProInitializationHintKey) ?? false;
    } catch (_) {
      _logSanitizedFailure(LocalErrorCode.revenueCatPriorProHintReadFailed);
      return false;
    }
  }

  Future<void> rememberVerifiedProInitializationHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(priorProInitializationHintKey, true);
    } catch (_) {
      _logSanitizedFailure(LocalErrorCode.revenueCatPriorProHintWriteFailed);
    }
  }

  /// Reads the persisted grace anchor. A future timestamp means a rolled-back
  /// clock or a tampered store and is discarded rather than trusted.
  Future<DateTime?> readLastVerifiedProAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(lastVerifiedProAtKey);
      if (millis == null || millis <= 0) return null;
      final moment = DateTime.fromMillisecondsSinceEpoch(millis);
      return moment.isAfter(DateTime.now()) ? null : moment;
    } on Exception {
      _logSanitizedFailure(LocalErrorCode.revenueCatProAnchorReadFailed);
      return null;
    }
  }

  Future<void> rememberVerifiedProAt(DateTime when) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(lastVerifiedProAtKey, when.millisecondsSinceEpoch);
    } on Exception {
      _logSanitizedFailure(LocalErrorCode.revenueCatProAnchorWriteFailed);
    }
  }

  /// Awaited by callers on a verified-free answer: if the process dies between
  /// the in-memory downgrade and this write, a stale anchor would survive.
  Future<void> clearLastVerifiedProAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(lastVerifiedProAtKey);
      await prefs.remove(priorProInitializationHintKey);
    } on Exception {
      _logSanitizedFailure(LocalErrorCode.revenueCatProAnchorWriteFailed);
    }
  }

  // ---------------------------------------------------------------------------
  // Entitlement check
  // ---------------------------------------------------------------------------

  /// Returns true only for an active and cryptographically verified KoruBeni
  /// Pro entitlement. Kept for conservative API compatibility.
  bool isPro(CustomerInfo customerInfo) {
    return evaluateEntitlement(customerInfo) == EntitlementDecision.authorized;
  }

  /// Converts RevenueCat's informational Trusted Entitlements result into the
  /// safety kernel's three-valued decision. Absence is `denied` only when the
  /// enclosing response is verified; any failed/not-requested verification is
  /// `unknown` even if RevenueCat's active map contains the entitlement.
  EntitlementDecision evaluateEntitlement(CustomerInfo? customerInfo) {
    if (customerInfo == null) return EntitlementDecision.unknown;

    final entitlements = customerInfo.entitlements;
    if (!_isTrusted(entitlements.verification)) {
      return EntitlementDecision.unknown;
    }

    final allEntitlement = entitlements.all[entitlementId];
    final activeEntitlement = entitlements.active[entitlementId];

    if (activeEntitlement != null) {
      if (allEntitlement == null ||
          !activeEntitlement.isActive ||
          !allEntitlement.isActive ||
          !_isTrusted(activeEntitlement.verification) ||
          !_isTrusted(allEntitlement.verification)) {
        return EntitlementDecision.unknown;
      }
      return EntitlementDecision.authorized;
    }

    if (allEntitlement != null) {
      if (allEntitlement.isActive || !_isTrusted(allEntitlement.verification)) {
        return EntitlementDecision.unknown;
      }
    }
    return EntitlementDecision.denied;
  }

  // ---------------------------------------------------------------------------
  // Customer info
  // ---------------------------------------------------------------------------

  /// Fetches the latest [CustomerInfo] from RevenueCat (or local cache when
  /// offline). Returns null on failure.
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!await ensureInitialized() || !_canUsePurchases) return null;
    try {
      return await Purchases.getCustomerInfo();
    } on PlatformException catch (_) {
      _logSanitizedFailure(LocalErrorCode.revenueCatCustomerInfoFailed);
      return null;
    } catch (_) {
      _logSanitizedFailure(LocalErrorCode.revenueCatCustomerInfoFailed);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Offerings
  // ---------------------------------------------------------------------------

  /// Returns the current [Offerings] from RevenueCat, or null on failure.
  Future<Offerings?> getOfferings() async {
    if (!await ensureInitialized() || !_canUsePurchases) return null;
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (_) {
      _logSanitizedFailure(LocalErrorCode.revenueCatOfferingsFailed);
      return null;
    } catch (_) {
      _logSanitizedFailure(LocalErrorCode.revenueCatOfferingsFailed);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Purchase
  // ---------------------------------------------------------------------------

  /// Initiates a purchase for [package]. Throws a [RevenueCatPurchaseException]
  /// on recoverable errors so the UI can display a meaningful message.
  Future<CustomerInfo> purchasePackage(Package package) async {
    if (!await ensureInitialized() || !_canUsePurchases) {
      throw RevenueCatPurchaseException.generic();
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        throw RevenueCatPurchaseException.cancelled();
      }
      if (errorCode == PurchasesErrorCode.networkError) {
        throw RevenueCatPurchaseException.offline();
      }
      _logSanitizedFailure(LocalErrorCode.revenueCatPurchaseFailed);
      throw RevenueCatPurchaseException.generic();
    } catch (_) {
      _logSanitizedFailure(LocalErrorCode.revenueCatPurchaseFailed);
      throw RevenueCatPurchaseException.generic();
    }
  }

  // ---------------------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------------------

  /// Restores previous purchases. Returns updated [CustomerInfo] or throws
  /// [RevenueCatPurchaseException] on failure.
  Future<CustomerInfo> restorePurchases() async {
    if (!await ensureInitialized() || !_canUsePurchases) {
      throw RevenueCatPurchaseException.generic();
    }
    try {
      return await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.networkError) {
        throw RevenueCatPurchaseException.offline();
      }
      _logSanitizedFailure(LocalErrorCode.revenueCatRestoreFailed);
      throw RevenueCatPurchaseException.generic();
    } catch (_) {
      _logSanitizedFailure(LocalErrorCode.revenueCatRestoreFailed);
      throw RevenueCatPurchaseException.generic();
    }
  }

  bool _isTrusted(VerificationResult result) =>
      result == VerificationResult.verified ||
      result == VerificationResult.verifiedOnDevice;

  void _logSanitizedFailure(LocalErrorCode code) {
    // Never persist exception messages/details here: SDK exceptions can carry
    // identifiers. The operation-specific allowlisted code is the entire
    // persisted diagnostic payload.
    LocalLoggerService.instance.errorCode(code);
  }

  bool get _canUsePurchases => !kIsWeb && Platform.isAndroid && _isConfigured;
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
