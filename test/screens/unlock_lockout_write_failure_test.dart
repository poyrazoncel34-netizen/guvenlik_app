// A failed PIN attempt that cannot be DEBITED must still cost the attacker.
//
// `PinVerificationService.verify()` never consults `PinLockoutService`, so
// `AppUnlockScreen`'s own `_lockoutEndTime` is the single enforcement point for
// the brute-force lockout. The screen used to call `registerFailure()` as a
// fire-and-forget future whose only error handler was `debugPrint` -- which
// release compiles out. A secure storage that still READS (so the PIN record is
// available and verification works) but can no longer WRITE therefore produced:
// counter never advanced, lockout never armed, nothing logged. 10,000
// candidates, unlimited attempts, no trace.
//
// `unlock_lockout_fail_closed_test.dart` covers the READ failure. This file
// covers the WRITE failure, which is a different fault with a different cause:
// there the counter is unknown, here it is knowable but stuck behind reality.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

/// Reads succeed, mutations fail. The PIN record stays verifiable, so this is
/// NOT the unreadable-counter case: the screen can tell a wrong PIN from a
/// storage fault, and still cannot record the attempt.
class _WriteOnlyFailureStorage extends SecureStorage {
  _WriteOnlyFailureStorage({this.writeError});

  /// What a write throws, or null for a store that works. Both an `Exception`
  /// and an `Error` are exercised by the tests below, because the screen catches
  /// them in two separate clauses: `PlatformException` is what
  /// flutter_secure_storage actually raises on a keystore fault, while
  /// `StateError` is what `PinLockoutService.getState()` raises on a corrupt
  /// counter. A test that only covered one would leave the other clause
  /// unproven.
  final Object? writeError;
  final Map<String, String> values = <String, String>{
    SecureStorageKeys.userPin: '4821',
  };

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    final error = writeError;
    if (error != null) throw error;
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();
}

Future<void> _pumpUnlock(WidgetTester tester, SecureStorage storage) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await serviceLocator.reset();
  serviceLocator.registerSingleton<SecureStorage>(storage);
  await pumpLocalized(tester, AppUnlockScreen(onUnlocked: () {}));
  expect(find.byType(CircularProgressIndicator), findsNothing);
}

/// The stored PIN is '4821', so this is always a wrong entry.
Future<void> _tapWrongPin(WidgetTester tester) async {
  for (final digit in '1111'.split('')) {
    final key = find.ancestor(
      of: find.text(digit),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
  // The submit path awaits secure storage, so let real async work drain.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Finder get _lockBand => find.byIcon(Icons.lock_clock_rounded);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async => serviceLocator.reset());

  testWidgets('a keystore write fault still locks the keypad', (tester) async {
    await _pumpUnlock(
      tester,
      _WriteOnlyFailureStorage(
        writeError: PlatformException(code: 'keystore_write_failed'),
      ),
    );

    await _tapWrongPin(tester);

    expect(
      _lockBand,
      findsOneWidget,
      reason:
          'the failed attempt could not be written to the counters, so nothing '
          'else will ever enforce it; treating that as "not locked" hands an '
          'attacker holding the device unlimited untraced PIN guesses',
    );
    // The owner must stay able to recover: the escape hatch is not gated on the
    // lockout, and the screen is not stuck on a spinner.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TextButton), findsWidgets);

    await _unmount(tester);
  });

  testWidgets('a corrupt-counter Error still locks the keypad', (tester) async {
    await _pumpUnlock(
      tester,
      _WriteOnlyFailureStorage(writeError: StateError('counter corrupt')),
    );

    await _tapWrongPin(tester);

    expect(
      _lockBand,
      findsOneWidget,
      reason:
          'StateError is an Error, not an Exception, so it is caught by its own '
          'clause; without this case that clause could be deleted silently',
    );

    await _unmount(tester);
  });

  testWidgets('a debitable wrong attempt does not lock before the threshold', (
    tester,
  ) async {
    await _pumpUnlock(tester, _WriteOnlyFailureStorage());

    await _tapWrongPin(tester);

    expect(
      _lockBand,
      findsNothing,
      reason:
          'the negative control: the lockout threshold is five failures, so a '
          'screen that locked on the first one would pass the case above while '
          'punishing every ordinary mistyped PIN',
    );

    await _unmount(tester);
  });
}
