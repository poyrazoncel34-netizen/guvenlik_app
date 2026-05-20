// ============================================================================
// SUBSCRIPTION PROVIDER — KoruBeni Pro abonelik durumu
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/services/revenue_cat_service.dart';
import '../../core/di/service_locator.dart';

class SubscriptionProvider extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  bool _isPro = false;
  bool _isLoading = false;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------
  bool get isPro {
    if (kDebugMode) return true; // GEÇICI: emülatör ekran görüntüsü - yayindan once kaldirilacak
    return _isPro;
  }
  bool get isLoading => _isLoading;
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

  RevenueCatService get _rcService => serviceLocator<RevenueCatService>();

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Call once after RevenueCatService.initialize() to load current state.
  Future<void> initialize() async {
    if (kIsWeb) return;
    _setLoading(true);
    try {
      final results = await Future.wait([
        _rcService.getCustomerInfo(),
        _rcService.getOfferings(),
      ]);
      final info = results[0] as CustomerInfo?;
      final offs = results[1] as Offerings?;
      if (info != null) {
        _customerInfo = info;
        _isPro = _rcService.isPro(info);
      }
      _offerings = offs;
      _errorMessage = _offeringErrorKey();
    } catch (e) {
      _errorMessage = 'subscription_error_plans_unavailable';
    } finally {
      _setLoading(false);
    }
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
      _customerInfo = info;
      _isPro = _rcService.isPro(info);
      notifyListeners();
      if (!_isPro) {
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
      _customerInfo = info;
      _isPro = _rcService.isPro(info);
      notifyListeners();
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
  Future<void> refresh() async {
    if (kIsWeb) return;
    try {
      final info = await _rcService.getCustomerInfo();
      if (info != null) {
        _customerInfo = info;
        _isPro = _rcService.isPro(info);
        notifyListeners();
      }
    } catch (_) {}
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
}
