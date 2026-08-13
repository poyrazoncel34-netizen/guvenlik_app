// ============================================================================
// SUBSCRIPTION PROVIDER — KoruBeni Pro abonelik durumu
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/services/revenue_cat_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/emergency_session_contract.dart';
import '../../core/services/subscription_access_state.dart';

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({RevenueCatService? revenueCatService})
    : _injectedRevenueCatService = revenueCatService;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  final RevenueCatService? _injectedRevenueCatService;
  bool _isLoading = false;
  SubscriptionAccessState _access =
      const SubscriptionAccessState.uninitialized();
  Future<void>? _initializationFuture;
  Future<void>? _refreshFuture;
  CustomerInfoUpdateListener? _customerInfoUpdateListener;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------
  /// COMMERCIAL entitlement: "is this person currently a paying subscriber, as
  /// far as we can tell". Bound to the BOUNDED policy, because that is the
  /// question the paywall, settings and subscription-management screens ask.
  ///
  /// Do NOT use this to authorize an emergency control. The two policies
  /// genuinely differ since the IR-04 change (emergency access is unbounded
  /// while unverifiable, commercial access is not), and one boolean cannot
  /// represent both -- reading this getter on an emergency surface is exactly
  /// how the UI and the gate came to disagree (R2-04).
  bool get isPro => _access.canUseNonEmergencyPaidFeature;

  /// EMERGENCY authorization: the unbounded policy the panic/SOS, check-in and
  /// safe-walk controls act on. Same value `SubscriptionGate.ensureAccess`
  /// computes for an emergency-capable feature.
  bool get canUseEmergencyFeature => _access.canUsePaidSafetyFeature;
  bool get isLoading => _isLoading;
  SubscriptionAccessState get access => _access;

  bool _offlineGraceLoaded = false;
  Future<void>? _offlineGraceFuture;
  SubscriptionAccessStatus get accessStatus => _access.status;
  EntitlementDecision get entitlementDecision => _access.entitlementDecision;
  Offerings? get offerings => _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  String? get errorMessage => _errorMessage;
  Offering? get currentOffering => _offerings?.current;
  bool get hasCurrentOffering => currentOffering != null;
  bool get hasAnyPackages =>
      currentOffering?.availablePackages.isNotEmpty ?? false;
  Package? get monthlyPackage =>
      currentOffering?.monthly ?? _packageByType(PackageType.monthly);
  Package? get annualPackage =>
      currentOffering?.annual ?? _packageByType(PackageType.annual);
  bool get hasRequiredPackages =>
      currentOffering != null &&
      monthlyPackage != null &&
      annualPackage != null;

  RevenueCatService get _rcService =>
      _injectedRevenueCatService ?? serviceLocator<RevenueCatService>();

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Lazy entry point for Pro/paywall flows. RevenueCatService enforces the
  /// current Terms+KVKK gate before configuring the SDK.
  Future<void> initialize() {
    if (kIsWeb) return Future<void>.value();
    if (_access.status == SubscriptionAccessStatus.verifiedPro ||
        _access.status == SubscriptionAccessStatus.verifiedFree) {
      return Future<void>.value();
    }
    return _initializationFuture ??= _initializeOnce().whenComplete(() {
      _initializationFuture = null;
    });
  }

  Future<void> _initializeOnce() async {
    _setLoading(true);
    _setAccess(_access.markLoading());
    try {
      if (!await _rcService.ensureInitialized()) {
        _setAccess(_access.markUnavailable());
        _errorMessage = 'subscription_error_plans_unavailable';
        return;
      }
      final results = await Future.wait([
        _rcService.getCustomerInfo(),
        _rcService.getOfferings(),
      ]);
      final info = results[0] as CustomerInfo?;
      final offs = results[1] as Offerings?;
      if (info != null) {
        await _applyCustomerInfo(info);
      } else {
        _setAccess(_access.markUnavailable());
      }
      _offerings = offs;
      _errorMessage = _offeringErrorKey();
    } catch (e) {
      _setAccess(_access.markUnavailable());
      _errorMessage = 'subscription_error_plans_unavailable';
    } finally {
      _setLoading(false);
      _registerCustomerInfoUpdates();
    }
  }

  /// Optional post-legal startup refresh for users who have previously held a
  /// verified Pro entitlement. The hint only triggers initialization; access
  /// remains unknown until a current Trusted Entitlements result is applied.
  Future<void> initializeFromPriorProHint() async {
    if (kIsWeb || !await _rcService.hasPriorProInitializationHint()) return;
    await initialize();
  }

  // ---------------------------------------------------------------------------
  // Purchase
  // ---------------------------------------------------------------------------

  /// Returns null on success, or an error message string on failure.
  /// Callers should show appropriate UI for [RevenueCatPurchaseException.isCancelled].
  Future<String?> purchasePackage(Package package) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final info = await _rcService.purchasePackage(package);
      await _applyCustomerInfo(info);
      // A purchase either produced a store-CONFIRMED active entitlement or it
      // did not. Checking a grace-widened getter here would report success on
      // a stale anchor after a failed purchase.
      if (_access.status != SubscriptionAccessStatus.verifiedPro) {
        _errorMessage = 'subscription_error_entitlement';
        return _errorMessage;
      }
      return null;
    } on RevenueCatPurchaseException catch (e) {
      if (e.isCancelled) return null; // User cancelled — not an error
      _errorMessage = e.isOffline
          ? 'subscription_error_offline'
          : 'subscription_error_purchase';
      notifyListeners();
      return _errorMessage;
    } catch (e) {
      _errorMessage = 'subscription_error_purchase';
      notifyListeners();
      return _errorMessage;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------------------

  /// Returns null on success, or an error message string on failure.
  Future<String?> restorePurchases() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final info = await _rcService.restorePurchases();
      await _applyCustomerInfo(info);
      return null;
    } on RevenueCatPurchaseException catch (e) {
      _errorMessage = e.isOffline
          ? 'subscription_error_offline'
          : 'subscription_error_restore';
      notifyListeners();
      return _errorMessage;
    } catch (e) {
      _errorMessage = 'subscription_error_restore';
      notifyListeners();
      return _errorMessage;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  /// Re-fetch CustomerInfo (e.g. on app resume or after returning from paywall).
  Future<void> refresh() {
    if (kIsWeb) return Future<void>.value();
    return _refreshFuture ??= _refreshOnce().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<void> _refreshOnce() async {
    try {
      final info = await _rcService.getCustomerInfo();
      if (info != null) {
        await _applyCustomerInfo(info);
      } else {
        _setAccess(_access.markUnavailable());
      }
    } catch (_) {
      _setAccess(_access.markUnavailable());
    }
  }

  /// Loads the persisted offline-grace anchor exactly once.
  ///
  /// Deliberately outside the network path and its timeout: after a cold start
  /// with no signal the network call is precisely what fails, and the anchor is
  /// the only thing that can still authorize the press. Local read only.
  Future<void> ensureOfflineGraceLoaded() {
    if (kIsWeb || _offlineGraceLoaded) return Future<void>.value();
    return _offlineGraceFuture ??= _loadOfflineGraceOnce().whenComplete(() {
      _offlineGraceFuture = null;
    });
  }

  Future<void> _loadOfflineGraceOnce() async {
    _offlineGraceLoaded = true;
    // Resolve defensively: this runs on the panic press, so a missing
    // registration degrades to "no anchor" instead of throwing into it.
    final service =
        _injectedRevenueCatService ??
        (serviceLocator.isRegistered<RevenueCatService>()
            ? serviceLocator<RevenueCatService>()
            : null);
    if (service == null) return;
    final results = await Future.wait(<Future<Object?>>[
      service.readLastVerifiedProAt(),
      service.hasPriorProInitializationHint(),
    ]);
    if (_disposed) return;
    final anchor = results[0] as DateTime?;
    final corroborated = results[1] as bool? ?? false;
    if (anchor == null || !corroborated) return;
    _setAccess(_access.withRestoredProAnchor(anchor, corroborated: true));
  }

  /// Waits for the first entitlement decision. Loading/network failure is
  /// returned explicitly; it is never silently converted to verified-free.
  /// Every already-initialized new-arm decision refreshes CustomerInfo so an
  /// old in-process Pro fact cannot silently authorize another session.
  Future<SubscriptionAccessState> resolveAccess() async {
    await ensureOfflineGraceLoaded();
    if (_access.status == SubscriptionAccessStatus.uninitialized) {
      await initialize();
    } else if (_access.status == SubscriptionAccessStatus.loading) {
      await _initializationFuture;
    } else {
      await refresh();
    }
    return _access;
  }

  Future<void> refreshOfferings() async {
    if (kIsWeb) return;
    _setLoading(true);
    try {
      _offerings = await _rcService.getOfferings();
      _errorMessage = _offeringErrorKey();
    } catch (_) {
      _errorMessage = 'subscription_error_plans_unavailable';
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _applyCustomerInfo(CustomerInfo info) async {
    final decision = _rcService.evaluateEntitlement(info);
    switch (decision) {
      case EntitlementDecision.authorized:
        _customerInfo = info;
        final verifiedAt = DateTime.now();
        _setAccess(_access.markVerified(isPro: true, at: verifiedAt));
        unawaited(_rcService.rememberVerifiedProInitializationHint());
        unawaited(_rcService.rememberVerifiedProAt(verifiedAt));
      case EntitlementDecision.denied:
        _customerInfo = info;
        _setAccess(_access.markVerified(isPro: false));
        // Awaited, unlike the Pro side: a process death between this in-memory
        // downgrade and the erase would resurrect the anchor on the next cold
        // start, handing offline authorization back to a lapsed subscriber.
        await _rcService.clearLastVerifiedProAt();
      case EntitlementDecision.unknown:
        // The store could not be reached. Preserve the anchor
        // (`lastVerifiedPro` + `lastVerifiedProAt`) untouched: under the IR-04
        // product policy a GENUINE prior confirmation keeps authorizing the
        // emergency path for as long as the store stays unreachable, so
        // `canUsePaidSafetyFeature` stays TRUE here for a confirmed subscriber
        // and FALSE for everyone else. Non-emergency paid features remain
        // bounded by `offlineGracePeriod`. An unknown answer is never converted
        // into a verified-free answer in either direction.
        _setAccess(_access.markUnavailable());
    }
  }

  void _setAccess(SubscriptionAccessState value) {
    _access = value;
    notifyListeners();
  }

  void _registerCustomerInfoUpdates() {
    if (_customerInfoUpdateListener != null || !_rcService.isConfigured) return;
    void listener(CustomerInfo info) {
      if (_disposed) return;
      // SDK callback: nothing to await into, so the erase is best-effort here.
      // The awaited paths above cover every decision the app itself requests.
      unawaited(_applyCustomerInfo(info));
    }

    try {
      Purchases.addCustomerInfoUpdateListener(listener);
      _customerInfoUpdateListener = listener;
    } catch (_) {
      // Configuration state is already reflected as unavailable. Listener
      // registration is best-effort and never changes entitlement truth.
    }
  }

  Package? _packageByType(PackageType type) {
    final packages = currentOffering?.availablePackages;
    if (packages == null) return null;
    for (final package in packages) {
      if (package.packageType == type) return package;
    }
    return null;
  }

  String? _offeringErrorKey() {
    if (_offerings == null) {
      return 'subscription_error_plans_unavailable';
    }
    if (!hasCurrentOffering) {
      return 'subscription_error_no_offering';
    }
    if (!hasAnyPackages) {
      return 'subscription_error_no_packages';
    }
    if (!hasRequiredPackages) {
      return 'subscription_error_packages_unavailable';
    }
    return null;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    final listener = _customerInfoUpdateListener;
    if (listener != null) {
      try {
        Purchases.removeCustomerInfoUpdateListener(listener);
      } catch (_) {
        // Best-effort SDK cleanup only.
      }
      _customerInfoUpdateListener = null;
    }
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
