// Y-05, screen half (chaos audit 2026-10-08, API 35 emulator): with the
// lockout service already measuring on elapsedRealtime, the unlock screen
// still opened its keypad when the clock was moved forward one hour. The
// screen gated input on its OWN wall-clock end time
// (`DateTime.now().isBefore(_lockoutEndTime)`), so "Kilitli: 37s" vanished the
// moment the wall clock passed it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/safety_clock.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LockedOut extends SecureStorage {
  final Map<String, String> values = <String, String>{
    SecureStorageKeys.userPin: 'pbkdf2\$1000\$abc\$def',
    'pin_lockout_failed_attempts': '6',
    'pin_lockout_until_ms':
        '${DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch}',
  };

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

class _FakeClock implements SafetyClock {
  DateTime wall = DateTime.now();
  Duration elapsed = Duration.zero;

  @override
  DateTime now() => wall;

  @override
  Duration get monotonic => elapsed;
}

Finder get _lockBand => find.byIcon(Icons.lock_clock_rounded);

void main() {
  testWidgets('moving the clock forward does not open a locked keypad', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_LockedOut());
    final clock = _FakeClock();
    await tester.pumpWidget(
      MaterialApp(
        home: AppUnlockScreen(onUnlocked: () {}, clock: clock),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_lockBand, findsOneWidget);

    clock.wall = clock.wall.add(const Duration(hours: 1, seconds: 1));
    clock.elapsed += const Duration(seconds: 1);
    await tester.pump(const Duration(milliseconds: 1100));

    expect(_lockBand, findsOneWidget, reason: 'the wall clock opened it');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await serviceLocator.reset();
  });
}
