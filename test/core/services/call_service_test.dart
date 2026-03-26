import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/call_service.dart';

void main() {
  test('CallService has a call timeout constant for plugin safety', () {
    // FlutterDirectCallerPlugin.callNumber() has no built-in timeout.
    // If the plugin hangs, the emergency flow is permanently blocked.
    // CallService must define a timeout to prevent this.
    expect(CallService.callTimeout, isA<Duration>());
    expect(CallService.callTimeout.inSeconds, lessThanOrEqualTo(5));
  });
}
