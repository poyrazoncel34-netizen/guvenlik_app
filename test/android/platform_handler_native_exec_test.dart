import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// EmergencyPlatformHandler must route the typed native coordinator API and
/// explicitly retire the legacy executor entry point.
void main() {
  test('EmergencyPlatformHandler routes typed session dispatch', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPlatformHandler.kt',
    ).readAsStringSync();

    expect(source, contains('"dispatchEmergencySession"'));
    expect(source, contains('.claimAndDispatch(token)'));
    expect(source, contains('"executeEmergencyNative",'));
    expect(source, contains('-> result.notImplemented()'));
  });
}
