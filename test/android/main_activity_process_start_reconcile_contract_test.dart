// Closure audit 2026-10-10 (API 29 emulator): `am force-stop` during an armed
// Check-In deleted its alarms (4 -> 0 pending); reopening the app restored
// none and the session still read ARMED -- nothing would fire once the app
// was closed. Android 15+ re-delivers BOOT_COMPLETED to a force-stopped app
// when it next starts; API 29-34 does not. MainActivity therefore runs the
// same-boot safety reconcile once per process, behind the receiver guard.
//
// Source contract (the Activity cannot run on the host): the behaviour itself
// is covered by ProcessStartReconcileTest + EmergencySessionCoordinatorTest,
// and on the device (docs/audit/evidence/closure-2026-10-09/).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MainActivity.onCreate reconciles armed sessions once per process', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
    ).readAsStringSync();
    final onCreate = source.substring(
      source.indexOf('override fun onCreate('),
      source.indexOf('override fun onNewIntent('),
    );
    expect(onCreate, contains('ProcessStartReconcile.once'));
    expect(onCreate, contains('reconcileCurrentBoot()'));
    expect(onCreate, contains('EmergencyReceiverGuard.run'));
  });
}
