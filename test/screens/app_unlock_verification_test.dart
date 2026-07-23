import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/pin_lockout_service.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      <String, dynamic>{
        'unlock_semantics': 'Uygulama kilidi',
        'unlock_title': 'Kilitli',
        'unlock_subtitle': 'PIN girin',
        'unlock_wrong_pin': 'Yanlış PIN',
        'pin_state_read_failed': 'PIN okunamadı',
        'safety_session_pin_required': 'PIN gerekli',
        'brute_force_locked': '{seconds} saniye kilitli',
        'brute_force_locked_short': '{seconds} saniye',
        'forgot_pin_title': 'PIN unutuldu',
      };
}

class _Storage extends SecureStorage {
  _Storage({this.failPinReads = false, this.failLockoutReads = false});

  final bool failPinReads;
  final bool failLockoutReads;
  final Map<String, String> values = <String, String>{};
  int lockoutWriteCount = 0;
  int pinReadCount = 0;
  Completer<void>? verificationGate;

  bool _isLockoutKey(String key) => key.startsWith('pin_lockout_');

  @override
  Future<String?> read({required String key}) async {
    if (key == SecureStorageKeys.userPin) {
      pinReadCount += 1;
      if (failPinReads) throw StateError('PIN read unavailable');
      final gate = verificationGate;
      if (pinReadCount > 1 && gate != null) {
        await gate.future;
      }
    }
    if (failLockoutReads && _isLockoutKey(key)) {
      throw StateError('lockout state unavailable');
    }
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (_isLockoutKey(key)) lockoutWriteCount += 1;
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    if (_isLockoutKey(key)) lockoutWriteCount += 1;
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();
}

Future<void> _pumpUnlock(
  WidgetTester tester, {
  required _Storage storage,
  required VoidCallback onUnlocked,
}) async {
  tester.view.physicalSize = const Size(1080, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final verification = PinVerificationService.forTesting(
    secureStorage: storage,
  );
  final lockout = PinLockoutService.forTesting(secureStorage: storage);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const <Locale>[Locale('tr', 'TR')],
      path: 'unused',
      assetLoader: const _Translations(),
      fallbackLocale: const Locale('tr', 'TR'),
      startLocale: const Locale('tr', 'TR'),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: AppUnlockScreen(
            onUnlocked: onUnlocked,
            pinVerificationService: verification,
            pinLockoutService: lockout,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterPin(WidgetTester tester, String value) async {
  for (final digit in value.characters) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('verified PIN unlocks once while concurrent taps are ignored', (
    tester,
  ) async {
    final gate = Completer<void>();
    final storage = _Storage()
      ..values[SecureStorageKeys.userPin] = '4826'
      ..verificationGate = gate;
    var unlockCount = 0;
    await _pumpUnlock(
      tester,
      storage: storage,
      onUnlocked: () => unlockCount += 1,
    );

    await _enterPin(tester, '4826');
    await tester.tap(find.text('4'));
    await tester.tap(find.text('8'));
    await tester.pump();
    expect(unlockCount, 0);

    gate.complete();
    await tester.pumpAndSettle();
    expect(unlockCount, 1);
    expect(storage.pinReadCount, 2);
  });

  testWidgets('PIN read failure stays locked and never records a failure', (
    tester,
  ) async {
    final storage = _Storage(failPinReads: true);
    var unlockCount = 0;
    await _pumpUnlock(
      tester,
      storage: storage,
      onUnlocked: () => unlockCount += 1,
    );

    await _enterPin(tester, '4826');
    await tester.pump();

    expect(unlockCount, 0);
    expect(storage.lockoutWriteCount, 0);
    expect(find.text('PIN okunamadı'), findsOneWidget);
  });

  testWidgets('lockout-state read failure disables PIN verification', (
    tester,
  ) async {
    final storage = _Storage(failLockoutReads: true)
      ..values[SecureStorageKeys.userPin] = '4826';
    var unlockCount = 0;
    await _pumpUnlock(
      tester,
      storage: storage,
      onUnlocked: () => unlockCount += 1,
    );

    await _enterPin(tester, '4826');
    await tester.pump();

    expect(unlockCount, 0);
    expect(storage.pinReadCount, 1);
    expect(find.text('PIN okunamadı'), findsOneWidget);
  });

  testWidgets('wrong PIN is persisted before a later correct PIN unlocks', (
    tester,
  ) async {
    final storage = _Storage()..values[SecureStorageKeys.userPin] = '4826';
    var unlockCount = 0;
    await _pumpUnlock(
      tester,
      storage: storage,
      onUnlocked: () => unlockCount += 1,
    );

    await _enterPin(tester, '1111');
    await tester.pumpAndSettle();
    expect(unlockCount, 0);
    expect(storage.values['pin_lockout_failed_attempts'], '1');

    await _enterPin(tester, '4826');
    await tester.pumpAndSettle();
    expect(unlockCount, 1);
    expect(storage.values.containsKey('pin_lockout_failed_attempts'), isFalse);
  });
}
