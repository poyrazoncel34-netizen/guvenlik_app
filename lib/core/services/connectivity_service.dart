import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors network connectivity status.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  static ConnectivityService get instance => _instance;
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _initialized = false;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _statusController.stream;

  /// Initialize and start monitoring
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _hasConnection(results);
    } catch (e) {
      debugPrint('ConnectivityService init error: $e');
    }

    await _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != _isOnline) {
        _isOnline = online;
        _statusController.add(_isOnline);
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      isOnlineFromResults(results);

  /// Pure connectivity decision, extracted so it can be unit-tested without
  /// the platform plugin.
  ///
  /// connectivity_plus reports the active transport(s), not real internet
  /// reachability. Any transport other than [ConnectivityResult.none]
  /// (mobile, wifi, ethernet, vpn, bluetooth, other) counts as online. The
  /// previous allow-list of only mobile/wifi/ethernet wrongly reported
  /// "offline" while the device was actually online over a VPN/other
  /// transport, surfacing a false offline banner (S7).
  static bool isOnlineFromResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
