// ============================================================================
// CONSENT MANAGER — Kalıcılık + migrasyon regresyonu (S11 / G6-storage)
// ============================================================================
// Rıza günlüğü keystore'a BAĞIMLI OLMAYAN, düz app-private SharedPreferences'ta
// tutulur; yeniden başlatmada güvenilir şekilde kalmalı. Eski keystore
// günlüğü tek seferlik, salt-okunur migrasyonla taşınır; eski okuma başarısızsa
// migrasyon ertelenir ve kullanıcı yeniden rıza verir (çökme yok).
// ============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const consentLogKey = 'kvkk_consent_log_v2';
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  void mockSecureStorage(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  test('consent persists across a simulated restart (no keystore needed)',
      () async {
    SharedPreferences.setMockInitialValues({});
    // No secure-storage mock at all: proves persistence does NOT depend on the
    // keystore — grant must round-trip through plain SharedPreferences.
    final cm = ConsentManager();
    await cm.initialize();
    await cm.grantConsent(ConsentRecord.typeLocation);
    expect(cm.isGranted(ConsentRecord.typeLocation), isTrue);

    final reloaded = ConsentManager(); // simulate app restart
    await reloaded.initialize();
    expect(reloaded.isGranted(ConsentRecord.typeLocation), isTrue);
    expect(reloaded.loadFailed, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(consentLogKey), isTrue);
  });

  test('revoke persists across a simulated restart', () async {
    SharedPreferences.setMockInitialValues({});
    final cm = ConsentManager();
    await cm.initialize();
    await cm.grantConsent(ConsentRecord.typeEmergencyContacts);
    await cm.revokeConsent(ConsentRecord.typeEmergencyContacts);

    final reloaded = ConsentManager();
    await reloaded.initialize();
    expect(reloaded.isGranted(ConsentRecord.typeEmergencyContacts), isFalse);
  });

  test('migrates the legacy keystore consent log on first load', () async {
    SharedPreferences.setMockInitialValues({}); // new store empty
    final legacyLog = jsonEncode([
      ConsentRecord(
        consentType: ConsentRecord.typeEmergencyContacts,
        granted: true,
        timestamp: DateTime.utc(2026, 1, 1),
        appVersion: '1.0.0',
        osVersion: 'android-14',
        deviceModel: 'pixel',
        consentTextVersion: 'v1',
        locale: 'tr',
      ).toJson(),
    ]);
    mockSecureStorage((call) async {
      final args = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : <String, dynamic>{};
      switch (call.method) {
        case 'read':
          return args['key'] == SecureStorageKeys.consentLog
              ? legacyLog
              : null;
        case 'readAll':
          return <String, String>{};
        default:
          return null;
      }
    });

    final cm = ConsentManager();
    await cm.initialize();
    expect(
      cm.isGranted(ConsentRecord.typeEmergencyContacts),
      isTrue,
      reason: 'A previously granted consent must survive the store migration.',
    );

    // The log now lives in the keystore-independent SharedPreferences store.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(consentLogKey), isTrue);
  });

  test('keystore read failure defers migration without crashing', () async {
    SharedPreferences.setMockInitialValues({});
    mockSecureStorage((call) async {
      throw PlatformException(code: 'keystore_error');
    });

    final cm = ConsentManager();
    await cm.initialize(); // must not throw
    expect(cm.isGranted(ConsentRecord.typeLocation), isFalse);
    expect(
      cm.loadFailed,
      isFalse,
      reason: 'A failed legacy read is not a SharedPreferences load failure.',
    );

    // A fresh grant still persists via SharedPreferences despite the bad keystore.
    await cm.grantConsent(ConsentRecord.typeLocation);
    expect(cm.isGranted(ConsentRecord.typeLocation), isTrue);
  });

  test('legacy migration failure never logs secure-storage exception details',
      () async {
    SharedPreferences.setMockInitialValues({});
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);
    mockSecureStorage((call) async {
      throw PlatformException(
        code: 'CANARY_PRIVATE_KEYSTORE_CODE',
        message: 'PIN=8642 phone=+905551112233',
      );
    });

    await ConsentManager().initialize();

    final output = messages.join('\n');
    expect(output, isNot(contains('CANARY_PRIVATE_KEYSTORE_CODE')));
    expect(output, isNot(contains('8642')));
    expect(output, isNot(contains('+905551112233')));
    expect(output, contains('legacy consent migration deferred'));
  });
}
