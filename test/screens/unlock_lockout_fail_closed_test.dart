// The PIN brute-force lockout has exactly ONE enforcement point.
//
// `PinVerificationService.verify()` never consults `PinLockoutService`; the
// lock screen's own `_lockoutEndTime` is what disables the keypad. So whatever
// the screen believes when the lockout counters cannot be read IS the policy.
//
// It used to believe "0 failures, not locked" (a bare `catch` that returned an
// empty state), which silently disarmed the lockout with no log line -- in
// release, with `debugPrint` compiled out, there was no trace at all. Under the
// duress model that hands an attacker holding the device unlimited guesses.
//
// The counters live in secure storage, so a keystore fault that leaves the PIN
// hash readable while the counters are not is the exact scenario here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Readable PIN, unreadable lockout counters.
class _LockoutCountersUnreadable extends SecureStorage {
  static const Set<String> lockoutKeys = <String>{
    'pin_lockout_failed_attempts',
    'pin_lockout_until_ms',
  };

  @override
  Future<String?> read({required String key}) {
    if (lockoutKeys.contains(key)) {
      return Future<String?>.error(StateError('counter unreadable'));
    }
    if (key == SecureStorageKeys.userPin) {
      return Future<String?>.value('pbkdf2\$1000\$abc\$def');
    }
    return Future<String?>.value(null);
  }

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {}
}

/// Counters readable and clean -- the negative control.
class _LockoutCountersClean extends SecureStorage {
  @override
  Future<String?> read({required String key}) async {
    if (key == SecureStorageKeys.userPin) return 'pbkdf2\$1000\$abc\$def';
    return null;
  }

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {}
}

Future<void> _pumpUnlock(WidgetTester tester, SecureStorage storage) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await serviceLocator.reset();
  serviceLocator.registerSingleton<SecureStorage>(storage);
  await tester.pumpWidget(
    MaterialApp(home: AppUnlockScreen(onUnlocked: () {})),
  );
  await tester.pumpAndSettle();
}

Finder get _lockBand => find.byIcon(Icons.lock_clock_rounded);

/// A locked screen owns a live countdown subscription; unmount it so the
/// binding does not fail the test on the still-pending timer.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async => serviceLocator.reset());

  testWidgets('unreadable lockout counters lock the screen, not open it', (
    tester,
  ) async {
    await _pumpUnlock(tester, _LockoutCountersUnreadable());

    expect(
      _lockBand,
      findsOneWidget,
      reason: 'an unreadable counter is not evidence of zero failed attempts; '
          'treating it as "not locked" is the only thing standing between an '
          'attacker and unlimited PIN guesses',
    );
    // The screen must stay usable: the owner's escape hatch is still there.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TextButton), findsWidgets);

    await _unmount(tester);
  });

  testWidgets('readable clean counters leave the screen unlocked', (
    tester,
  ) async {
    await _pumpUnlock(tester, _LockoutCountersClean());

    expect(
      _lockBand,
      findsNothing,
      reason: 'the negative control: without this, an always-locked screen '
          'would pass the case above while bricking every ordinary unlock',
    );

    await _unmount(tester);
  });
}
