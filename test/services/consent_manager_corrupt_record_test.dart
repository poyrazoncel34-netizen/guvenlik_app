// ============================================================================
// CONSENT MANAGER — Bozuk kayıt regresyon testi
// ============================================================================
// KVKK rıza günlüğünde tek bir bozuk JSON satırı tüm onayları silmemeli.
// _loadConsentCache / getAllLogs döngüleri per-item try/catch ile her bozuk
// kaydı sessizce atlayıp sağlamları yüklemeli. Günlük artık keystore yerine
// düz, app-private SharedPreferences'ta tutulur.
// ============================================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Must match ConsentManager._consentLogKey.
  const consentLogKey = 'kvkk_consent_log_v2';

  Map<String, dynamic> goodRecord({
    required String type,
    required bool granted,
    DateTime? timestamp,
  }) => ConsentRecord(
    consentType: type,
    granted: granted,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1),
    appVersion: '1.0.0',
    osVersion: 'android-14',
    deviceModel: 'pixel',
    consentTextVersion: 'v1',
    locale: 'tr',
  ).toJson();

  test(
    '_loadConsentCache: one malformed entry must not wipe valid consents',
    () async {
      final list = <Map<String, dynamic>>[
        goodRecord(type: ConsentRecord.typeKvkk, granted: true),
        <String, dynamic>{
          'consentType': 'broken-row',
          // granted: MISSING — fromJson throws
          'timestamp': DateTime.utc(2026, 1, 2).toIso8601String(),
        },
        goodRecord(
          type: ConsentRecord.typeEmergencyContacts,
          granted: true,
        ),
      ];
      SharedPreferences.setMockInitialValues({
        consentLogKey: jsonEncode(list),
      });

      final cm = ConsentManager();
      await cm.initialize();

      expect(
        cm.isGranted(ConsentRecord.typeKvkk),
        isTrue,
        reason:
            'KVKK consent should remain granted even though a sibling row '
            'was malformed.',
      );
      expect(
        cm.isGranted(ConsentRecord.typeEmergencyContacts),
        isTrue,
        reason:
            'Emergency contacts consent should remain granted even though a '
            'sibling row was malformed.',
      );
    },
  );

  test(
    '_loadConsentCache: keeps latest record per consent type, '
    'malformed siblings ignored',
    () async {
      final list = <Map<String, dynamic>>[
        goodRecord(
          type: ConsentRecord.typeLocation,
          granted: false,
          timestamp: DateTime.utc(2026, 1, 1),
        ),
        <String, dynamic>{'this': 'is not a consent record at all'},
        goodRecord(
          type: ConsentRecord.typeLocation,
          granted: true,
          timestamp: DateTime.utc(2026, 6, 1),
        ),
      ];
      SharedPreferences.setMockInitialValues({
        consentLogKey: jsonEncode(list),
      });

      final cm = ConsentManager();
      await cm.initialize();

      expect(
        cm.isGranted(ConsentRecord.typeLocation),
        isTrue,
        reason:
            'The newer (granted=true) record must win over the older '
            '(granted=false) one despite the malformed entry between them.',
      );
    },
  );

  test(
    'getAllLogs: returns valid records and skips malformed ones',
    () async {
      final list = <Map<String, dynamic>>[
        goodRecord(type: ConsentRecord.typeTerms, granted: true),
        <String, dynamic>{
          'consentType': 42,
          'granted': true,
          'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
        },
        goodRecord(type: ConsentRecord.typeKvkk, granted: true),
        <String, dynamic>{},
      ];
      SharedPreferences.setMockInitialValues({
        consentLogKey: jsonEncode(list),
      });

      final cm = ConsentManager();
      final logs = await cm.getAllLogs();

      expect(logs, hasLength(2));
      expect(
        logs.map((r) => r.consentType),
        containsAll(<String>[
          ConsentRecord.typeTerms,
          ConsentRecord.typeKvkk,
        ]),
      );
    },
  );

  test('getAllLogs: empty list when storage is empty', () async {
    SharedPreferences.setMockInitialValues({});
    final cm = ConsentManager();
    final logs = await cm.getAllLogs();
    expect(logs, isEmpty);
  });
}
