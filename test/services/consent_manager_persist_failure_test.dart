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
import 'package:guvenlik_app/constants/legal_texts.dart';
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

  test(
    'consent persists across a simulated restart (no keystore needed)',
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
    },
  );

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
          return args['key'] == SecureStorageKeys.consentLog ? legacyLog : null;
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

  test(
    'legacy migration failure never logs secure-storage exception details',
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
    },
  );

  test(
    'legal acceptance is published only after every version write commits',
    () async {
      final store = _FaultingLegalAcceptanceStore();

      await ConsentManager().markLegalVersionsAccepted(store: store);

      expect(store.operations, [
        'bool:legal_accepted_v1=false',
        'bool:pref_legal_disclaimer_accepted=false',
        'string:pref_terms_version=${LegalTexts.termsVersion}',
        'string:pref_kvkk_version=${LegalTexts.kvkkVersion}',
        'bool:pref_legal_disclaimer_accepted=true',
      ]);
      expect(store.values['pref_legal_disclaimer_accepted'], isTrue);
      expect(store.values['legal_accepted_v1'], isFalse);
    },
  );

  test(
    'legal version commit failure leaves every acceptance marker false',
    () async {
      final store = _FaultingLegalAcceptanceStore(
        rejectedOperation: 'string:pref_kvkk_version',
      );

      await expectLater(
        ConsentManager().markLegalVersionsAccepted(store: store),
        throwsA(isA<ConsentStorageException>()),
      );

      expect(store.values['pref_legal_disclaimer_accepted'], isFalse);
      expect(store.values['legal_accepted_v1'], isFalse);
      expect(
        store.operations,
        isNot(contains('bool:pref_legal_disclaimer_accepted=true')),
      );
    },
  );

  test(
    'legal store exception is converted to a bounded storage failure',
    () async {
      final store = _FaultingLegalAcceptanceStore(
        throwingOperation: 'string:pref_terms_version',
      );

      Object? failure;
      try {
        await ConsentManager().markLegalVersionsAccepted(store: store);
      } catch (error) {
        failure = error;
      }

      expect(failure, isA<ConsentStorageException>());
      expect(failure.toString(), isNot(contains('PIN=8642')));
      expect(store.values['pref_legal_disclaimer_accepted'], isFalse);
      expect(store.values['legal_accepted_v1'], isFalse);
    },
  );
}

class _FaultingLegalAcceptanceStore implements LegalAcceptanceStore {
  _FaultingLegalAcceptanceStore({
    this.rejectedOperation,
    this.throwingOperation,
  });

  final String? rejectedOperation;
  final String? throwingOperation;
  final Map<String, Object> values = {};
  final List<String> operations = [];

  @override
  Future<bool> setBool(String key, bool value) async {
    final operation = 'bool:$key=$value';
    operations.add(operation);
    if (throwingOperation == 'bool:$key') {
      throw StateError('storage exploded PIN=8642');
    }
    if (rejectedOperation == 'bool:$key') return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    final operation = 'string:$key=$value';
    operations.add(operation);
    if (throwingOperation == 'string:$key') {
      throw StateError('storage exploded PIN=8642');
    }
    if (rejectedOperation == 'string:$key') return false;
    values[key] = value;
    return true;
  }
}
