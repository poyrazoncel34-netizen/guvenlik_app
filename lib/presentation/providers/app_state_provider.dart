import 'package:flutter/foundation.dart';

class AppStateProvider extends ChangeNotifier {
  bool _isBusy = false;
  String? _statusMessage;

  bool get isBusy => _isBusy;
  String? get statusMessage => _statusMessage;

  void setBusy(bool value, {String? message}) {
    _isBusy = value;
    _statusMessage = message;
    notifyListeners();
  }
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
