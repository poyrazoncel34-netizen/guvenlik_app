// Hostile-input cover for the two user-supplied fields in the safety path.
//
// The phone field is the safety-critical one and is already bounded by
// EmergencyNumberValidator (7-15 digits). The contact NAME field is the softer
// target: it accepts free text and is rendered back on the home screen and in
// the countdown UI, so the realistic risks are rendering breakage and overflow
// rather than compromise -- SQL injection is structurally prevented by
// parameterised sqflite queries, and there is no DOM for XSS.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/utils/emergency_number_validator.dart';
import 'package:guvenlik_app/screens/onboarding/onboarding_contact_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/contact_service_test_support.dart';

/// Bidi and zero-width controls are written as escapes on purpose: as literal
/// characters they are invisible in review, which is exactly the property that
/// makes them worth testing.
const Map<String, String> _hostile = <String, String>{
  'html': '<b>bold</b><img src=x onerror=alert(1)>',
  'script': '<script>alert("xss")</script>',
  'sqlLike': "Robert'); DROP TABLE contacts;--",
  'zeroWidth': 'ad\u200Bsoyad\u200D',
  'rtlOverride': '\u202Emalicious\u202C',
  'emojiFlood': '\u{1F469}\u{1F692}\u{1F469}\u{1F692}\u{1F469}\u{1F692}',
  'combining': 'á̂̃̄̅̆̇',
  'replacementChar': 'ad�soyad',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  group('phone field refuses every hostile string', () {
    for (final entry in _hostile.entries) {
      test('${entry.key} is not a callable emergency target', () {
        expect(
          EmergencyNumberValidator.isCallableEmergencyTarget(entry.value),
          isFalse,
          reason:
              'A non-numeric string must never become a dial target. If this '
              'ever passes, the countdown could hand it to Telecom.',
        );
      });
    }

    test('a 10,000 character paste is refused without hanging', () {
      final huge = '1' * 10000;
      final sw = Stopwatch()..start();
      final callable = EmergencyNumberValidator.isCallableEmergencyTarget(huge);
      sw.stop();

      expect(callable, isFalse, reason: 'far beyond the 15-digit bound');
      expect(
        sw.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'Validation sits on the arm path. A pathological input must not '
            'introduce a delay there -- that is a ReDoS-shaped risk.',
      );
    });

    test('digit-count bounds are enforced at both ends', () {
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('123456'),
        isFalse,
        reason: 'one digit under the 7-digit minimum',
      );
      expect(
        EmergencyNumberValidator.isCallableEmergencyTarget('1' * 16),
        isFalse,
        reason: 'one digit over the 15-digit maximum',
      );
    });
  });

  group('contact name field survives hostile input', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await serviceLocator.reset();
      serviceLocator.registerSingleton<SecureStorage>(FakeSecureStorage());
      serviceLocator.registerSingleton<LocalDatabaseService>(
        FakeLocalDatabaseService(),
      );
      ContactService.resetCache();
    });

    tearDown(() async {
      ContactService.resetCache();
      await serviceLocator.reset();
    });

    Future<void> pumpStep(WidgetTester tester) async {
      // pumpWidget inside runAsync: the step awaits real secure-storage and
      // sqflite-ffi reads that never resolve under FakeAsync.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OnboardingContactStep(onGateChanged: (_) {}),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('hostile strings render without exception', (tester) async {
      await pumpStep(tester);
      final nameField = find.byType(TextField).first;

      for (final entry in _hostile.entries) {
        await tester.enterText(nameField, entry.value);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} must not throw while rendering',
        );
      }
    });

    testWidgets('a huge paste is bounded by the field maxLength', (
      tester,
    ) async {
      await pumpStep(tester);
      final nameField = find.byType(TextField).first;

      await tester.enterText(nameField, 'A' * 10000);
      await tester.pump(const Duration(milliseconds: 50));

      final field = tester.widget<TextField>(nameField);
      final maxLength = field.maxLength;
      expect(
        maxLength,
        isNotNull,
        reason:
            'An unbounded free-text field is what turns a paste into a layout '
            'and storage problem.',
      );
      if (maxLength != null) {
        expect(field.controller?.text.length, lessThanOrEqualTo(maxLength));
      }
      expect(tester.takeException(), isNull);
    });
  });
}
