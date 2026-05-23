// ============================================================================
// CONSENT MANAGER — Bozuk kayıt regresyon testi
// ============================================================================
// KVKK rıza günlüğünde tek bir bozuk JSON satırı tüm onayları silmemeli.
// _loadConsentCache / getAllLogs döngüleri per-item try/catch ile her bozuk
// kaydı sessizce atlayıp sağlamları yüklemeli; aksi halde kullanıcı verdiği
// onayları kaybeder, akış consent-siz kalır, KVKK denetiminde sorun çıkar.
// ============================================================================

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/services/consent_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_secure_storage MethodChannel mock — in-memory map yedek.
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> store;

  setUp(() {
    store = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          final args = call.arguments is Map
              ? Map<String, dynamic>.from(call.arguments as Map)
              : <String, dynamic>{};
          switch (call.method) {
            case 'read':
              return store[args['key'] as String];
            case 'readAll':
              return Map<String, dynamic>.from(store);
            case 'write':
              store[args['key'] as String] = args['value'] as String;
              return null;
            case 'delete':
              store.remove(args['key'] as String);
              return null;
            case 'deleteAll':
              store.clear();
              return null;
            case 'containsKey':
              return store.containsKey(args['key'] as String);
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

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
      store[SecureStorageKeys.consentLog] = jsonEncode(list);

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
      store[SecureStorageKeys.consentLog] = jsonEncode(list);

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
      store[SecureStorageKeys.consentLog] = jsonEncode(list);

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
    final cm = ConsentManager();
    final logs = await cm.getAllLogs();
    expect(logs, isEmpty);
  });
}
