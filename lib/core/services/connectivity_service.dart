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

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _statusController.stream;

  /// Initialize and start monitoring
  Future<void> initialize() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _hasConnection(results);
    } catch (e) {
      debugPrint('ConnectivityService init error: $e');
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != _isOnline) {
        _isOnline = online;
        _statusController.add(_isOnline);
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
