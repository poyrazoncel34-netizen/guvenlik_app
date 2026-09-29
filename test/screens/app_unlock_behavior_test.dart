import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:guvenlik_app/screens/settings_legal/legal_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

class _MemoryStorage extends SecureStorage {
  _MemoryStorage({bool failVerificationRead = false})
    : _failVerificationRead = failVerificationRead;

  final bool _failVerificationRead;
  final Map<String, String> values = <String, String>{
    SecureStorageKeys.userPin: '4821',
  };
  var _pinReads = 0;

  @override
  Future<String?> read({required String key}) async {
    if (key == SecureStorageKeys.userPin) {
      _pinReads++;
      if (_failVerificationRead && _pinReads > 1) {
        throw StateError('secure PIN became unreadable');
      }
    }
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();
}

Future<void> _pumpUnlock(
  WidgetTester tester, {
  _MemoryStorage? storage,
  Map<String, Object> preferences = const <String, Object>{},
  VoidCallback? onUnlocked,
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  await serviceLocator.reset();
  serviceLocator.registerSingleton<SecureStorage>(storage ?? _MemoryStorage());
  await pumpLocalized(tester, AppUnlockScreen(onUnlocked: onUnlocked ?? () {}));
  expect(find.byType(CircularProgressIndicator), findsNothing);
}

Future<void> _tapPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    final key = find.ancestor(
      of: find.text(digit),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Cancelling the stream subscription stops delivery immediately, while the
  // async generator's current one-second delay still has to elapse.
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _tapForgotPin(WidgetTester tester) async {
  final forgot = find.text('Şifremi Unuttum');
  await tester.ensureVisible(forgot);
  await tester.tap(forgot);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 40)),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const emergencyChannel = MethodChannel(
    'com.poyrazoncel.korubeni/emergency_platform',
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          emergencyChannel,
          (_) async => <String, Object?>{'type': 'absent'},
        );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(emergencyChannel, null);
    await serviceLocator.reset();
  });

  testWidgets('KLT-03 wrong PIN clears input and records a failure', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await _pumpUnlock(tester, storage: storage);

    await _tapPin(tester, '1111');

    expect(find.text('Yanlış PIN. Tekrar deneyin.'), findsOneWidget);
    expect(storage.values['pin_lockout_failed_attempts'], '1');
    expect(find.byIcon(Icons.lock_clock_rounded), findsNothing);
    await _unmount(tester);
  });

  testWidgets('unlock keypad exposes button roles and a named delete action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpUnlock(tester);

    for (final digit in '0123456789'.split('')) {
      final key = find.bySemanticsLabel(digit);
      expect(key, findsOneWidget, reason: 'missing keypad label $digit');
      expect(tester.getSemantics(key).flagsCollection.isButton, isTrue);
    }
    final delete = find.bySemanticsLabel('Sil');
    expect(delete, findsOneWidget);
    expect(tester.getSemantics(delete).flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('KLT-04 fifth wrong PIN locks the real keypad', (tester) async {
    final storage = _MemoryStorage();
    await _pumpUnlock(tester, storage: storage);

    for (var attempt = 0; attempt < 5; attempt++) {
      await _tapPin(tester, '1111');
    }

    expect(storage.values['pin_lockout_failed_attempts'], '5');
    expect(find.byIcon(Icons.lock_clock_rounded), findsOneWidget);
    final failuresBeforeLockedTap =
        storage.values['pin_lockout_failed_attempts'];
    await _tapPin(tester, '1111');
    expect(
      storage.values['pin_lockout_failed_attempts'],
      failuresBeforeLockedTap,
      reason: 'a locked keypad must not submit another candidate',
    );
    await _unmount(tester);
  });

  testWidgets('KLT-06 secure-storage read failure fails closed', (
    tester,
  ) async {
    final storage = _MemoryStorage(failVerificationRead: true);
    var unlocked = false;
    await _pumpUnlock(
      tester,
      storage: storage,
      onUnlocked: () => unlocked = true,
    );

    await _tapPin(tester, '4821');

    expect(
      find.text("Güvenlik PIN'i okunamadı; PIN ile iptal kullanılamıyor."),
      findsOneWidget,
    );
    expect(unlocked, isFalse);
    expect(storage.values['pin_lockout_failed_attempts'], isNull);
    await _unmount(tester);
  });

  testWidgets('KLT-07 info action opens the production legal screen', (
    tester,
  ) async {
    await _pumpUnlock(tester);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.byType(LegalSettingsScreen), findsOneWidget);
  });

  testWidgets('KLT-08 active safety session blocks forgot-PIN reset', (
    tester,
  ) async {
    await _pumpUnlock(
      tester,
      preferences: <String, Object>{
        'check_in_state_v2': jsonEncode(<String, Object>{'active': true}),
      },
    );

    await _tapForgotPin(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text(
        'Aktif bir güvenlik oturumu varken uygulama sıfırlanamaz. '
        'Önce PIN ile girip oturumu durdurun.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('KLT-09/KLT-10 reset token enables confirm and cancel closes', (
    tester,
  ) async {
    await _pumpUnlock(tester);

    await _tapForgotPin(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    ElevatedButton resetButton() => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Sıfırla'),
    );
    expect(resetButton().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'YANLIS');
    await tester.pump();
    expect(resetButton().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'SIFIRLA');
    await tester.pump();
    expect(resetButton().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(TextButton, 'İptal'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AppUnlockScreen), findsOneWidget);
  });
}
