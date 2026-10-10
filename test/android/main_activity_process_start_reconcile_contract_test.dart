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
    // Comments stripped: a call left only in a comment is no call (review).
    final code = source
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .replaceAll(RegExp(r'//[^\n]*'), '');
    final onCreate = code.substring(
      code.indexOf('override fun onCreate('),
      code.indexOf('override fun onNewIntent('),
    );
    final superCall = onCreate.indexOf('super.onCreate(savedInstanceState)');
    final reconcile = onCreate.indexOf('ProcessStartReconcile.once');
    expect(superCall, isNot(-1));
    expect(reconcile, greaterThan(superCall), reason: 'needs the started Activity');
    final body = onCreate.substring(reconcile);
    expect(body, contains('EmergencyReceiverGuard.run'));
    expect(body, contains('reconcileCurrentBoot()'));
    expect(body, isNot(contains('if (false')));
    expect(body, isNot(contains('Thread(')), reason: 'reconciled before the UI runs');
    // A reconcile that threw must report failure, so the next start retries.
    expect(body, contains('reconciled = true'));
    expect(RegExp(r'\breconciled\s*\n\s*\}').hasMatch(body), isTrue);
  });
}
