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
  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  Offerings? get offerings => _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  String? get errorMessage => _errorMessage;

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
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
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
      return null;
    } on RevenueCatPurchaseException catch (e) {
      if (e.isCancelled) return null; // User cancelled — not an error
      _errorMessage = e.message;
      notifyListeners();
      return e.message;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return e.toString();
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
      _errorMessage = e.message;
      notifyListeners();
      return e.message;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return e.toString();
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
