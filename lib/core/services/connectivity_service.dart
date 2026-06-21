import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// Monitors network connectivity status.
class ConnectivityService with WidgetsBindingObserver {
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

    await _refresh();

    await _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _applyResults(results);
    });

    // Re-validate on resume: a wrong/early cold-start reading otherwise sticks,
    // because the change-only stream never fires if the real link did not
    // change. This clears a stale offline banner when returning to the app.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _applyResults(results);
    } catch (e) {
      debugPrint('ConnectivityService refresh error: $e');
    }
  }

  void _applyResults(List<ConnectivityResult> results) {
    final online = _hasConnection(results);
    if (online != _isOnline) {
      _isOnline = online;
      _statusController.add(_isOnline);
    }
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
    // Fail-open: an empty/unknown result is treated as ONLINE. This is an
    // informational banner on an offline-first app; a false "offline" (e.g. an
    // early or empty cold-start read) is worse than briefly missing a true
    // offline. Online = any transport other than 'none'.
    if (results.isEmpty) return true;
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _statusController.close();
  }
}
