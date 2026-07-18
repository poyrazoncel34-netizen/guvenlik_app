import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final kotlinBase =
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency';

  test('manifest listens for exact-alarm permission grants', () {
    expect(manifest, contains('.emergency.ExactAlarmPermissionReceiver'));
    expect(
      manifest,
      contains(
        'android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED',
      ),
    );
  });

  test('permission receiver restores every active native safety alarm', () {
    final receiver = File(
      '$kotlinBase/ExactAlarmPermissionReceiver.kt',
    ).readAsStringSync();

    expect(receiver, contains('EmergencySessionRuntime.coordinator(context)'));
    expect(receiver, contains('reconcileCurrentBoot()'));
    expect(receiver, isNot(contains('restoreAfterExactAlarmPermissionGrant')));
  });

  test('exact alarms have independently cancellable inexact backups', () {
    final source = File(
      '$kotlinBase/AndroidEmergencySessionRuntime.kt',
    ).readAsStringSync();

    expect(source, contains('pendingIntent(envelope.token, exact = true)'));
    expect(source, contains('pendingIntent(envelope.token, exact = false)'));
    expect(
      source,
      contains('if (exact) EXACT_REQUEST_CODE else INEXACT_REQUEST_CODE'),
    );
    expect(source, contains('appendPath(identity)'));
    expect(
      source,
      contains('manager.cancel(pendingIntent(token, exact = true))'),
    );
    expect(
      source,
      contains('manager.cancel(pendingIntent(token, exact = false))'),
    );
  });
}
