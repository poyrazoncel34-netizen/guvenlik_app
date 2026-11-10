import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/contact_backup_service.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_service_test_support.dart';

/// allowBackup=false means a new phone starts empty. The contact backup is the
/// one user-held way across; these tests pin that it is exact, that it carries
/// nothing but contacts, and that every malformed file is refused WITHOUT
/// touching the contacts already on the device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  // Low iteration count keeps the suite fast; the production default is
  // pinned separately below.
  const service = ContactBackupService(
    iterations: 1000,
    minAcceptedIterations: 1000,
  );
  const password = 'dogru-sifre-123';

  late FakeSecureStorage secure;

  Future<void> freshInstall() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    secure = FakeSecureStorage();
    serviceLocator.registerSingleton<SecureStorage>(secure);
    serviceLocator.registerSingleton<LocalDatabaseService>(
      FakeLocalDatabaseService(),
    );
    ContactService.resetCache();
  }

  const original = [
    EmergencyContact(name: 'Ada Yilmaz', phone: '+905551112233'),
    EmergencyContact(name: 'Bora Kaya', phone: '+905554445566'),
    EmergencyContact(name: 'Cem Ozturk', phone: '05557778899'),
  ];

  Future<void> seedOriginal() async {
    await ContactService.saveContactRecords(original);
    await ContactService.savePrimaryEmergencyContact(
      name: 'Bora Kaya',
      phone: '+905554445566',
    );
  }

  List<Map<String, Object?>> snapshot(List<EmergencyContact> contacts) =>
      contacts
          .map(
            (c) => <String, Object?>{
              'name': c.name,
              'phone': c.phone,
              'isPrimary': c.isPrimary,
            },
          )
          .toList();

  Map<String, dynamic> envelope(Uint8List bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

  Uint8List reencode(Map<String, dynamic> json) =>
      Uint8List.fromList(utf8.encode(jsonEncode(json)));

  Future<void> expectFailure(
    Future<Object?> Function() action,
    ContactBackupFailure failure,
  ) async {
    await expectLater(
      action(),
      throwsA(
        isA<ContactBackupException>().having(
          (e) => e.failure,
          'failure',
          failure,
        ),
      ),
    );
  }

  setUp(freshInstall);

  tearDown(() async {
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  group('round trip', () {
    test(
      'export -> clean install -> import restores contacts exactly',
      () async {
        await seedOriginal();
        final before = snapshot(await ContactService.getContactRecords());
        expect(before.where((c) => c['isPrimary'] == true), hasLength(1));

        final file = await service.exportCurrentContacts(password);

        await freshInstall();
        expect(await ContactService.getContactRecords(), isEmpty);

        final decoded = await service.decode(file, password);
        final restored = await service.restore(decoded);

        expect(restored, before.length);
        ContactService.resetCache();
        final after = snapshot(await ContactService.getContactRecords());
        expect(after, before);
      },
    );

    test('import over existing contacts replaces them exactly', () async {
      await seedOriginal();
      final before = snapshot(await ContactService.getContactRecords());
      final file = await service.exportCurrentContacts(password);

      await freshInstall();
      await ContactService.saveContactRecords(const [
        EmergencyContact(name: 'Baska Kisi', phone: '+905550000000'),
      ]);
      await ContactService.savePrimaryEmergencyContact(
        name: 'Baska Kisi',
        phone: '+905550000000',
      );

      await service.restore(await service.decode(file, password));

      ContactService.resetCache();
      expect(snapshot(await ContactService.getContactRecords()), before);
    });

    test('a backup without a primary restores without a primary', () async {
      await ContactService.saveContactRecords(original);
      final file = await service.exportCurrentContacts(password);

      await freshInstall();
      await ContactService.saveContactRecords(const [
        EmergencyContact(name: 'Ada Yilmaz', phone: '+905551112233'),
      ]);
      await ContactService.savePrimaryEmergencyContact(
        name: 'Ada Yilmaz',
        phone: '+905551112233',
      );

      await service.restore(await service.decode(file, password));

      ContactService.resetCache();
      final after = await ContactService.getContactRecords();
      expect(after.where((c) => c.isPrimary), isEmpty);
      expect(after.map((c) => c.name), original.map((c) => c.name));
    });
  });

  group('what the file carries', () {
    test(
      'the plaintext holds contacts only -- never PIN or security data',
      () async {
        await seedOriginal();
        secure.store[SecureStorageKeys.userPin] = 'pbkdf2_sha256\$PINRECORD';
        final file = await service.exportCurrentContacts(password);

        final text = utf8.decode(file);
        expect(text, isNot(contains('PINRECORD')));
        expect(text, isNot(contains('Ada Yilmaz')));
        expect(text, isNot(contains('905551112233')));

        final plain = await service.decryptPayloadForTesting(file, password);
        expect(plain.keys, ['contacts']);
        for (final item in plain['contacts'] as List<dynamic>) {
          expect((item as Map).keys.toSet(), {'name', 'phone', 'isPrimary'});
        }
        expect(jsonEncode(plain), isNot(contains('PINRECORD')));
      },
    );

    test(
      'two exports of the same contacts differ (fresh salt and nonce)',
      () async {
        await seedOriginal();
        final a = envelope(await service.exportCurrentContacts(password));
        final b = envelope(await service.exportCurrentContacts(password));
        expect(a['kdf']['salt'], isNot(b['kdf']['salt']));
        expect(a['cipher']['nonce'], isNot(b['cipher']['nonce']));
      },
    );

    test('production default iteration count is pinned', () {
      expect(
        ContactBackupService.defaultIterations,
        greaterThanOrEqualTo(310000),
      );
      // The floor is its own constant: raising the default later must not
      // make older backups unreadable.
      expect(ContactBackupService.minimumIterations, 310000);
      // The cap bounds an uncancellable wait on a crafted file.
      expect(
        ContactBackupService.maxAcceptedIterations,
        lessThanOrEqualTo(1000000),
      );
      expect(
        const ContactBackupService().minAcceptedIterations,
        ContactBackupService.minimumIterations,
      );
    });
  });

  group('export refusals', () {
    test('short password is refused', () async {
      await seedOriginal();
      await expectFailure(
        () => service.exportCurrentContacts('1234567'),
        ContactBackupFailure.passwordTooShort,
      );
    });

    test('nothing to export is refused', () async {
      await expectFailure(
        () => service.exportCurrentContacts(password),
        ContactBackupFailure.noContacts,
      );
    });
  });

  group('broken or wrong files leave existing contacts untouched', () {
    late Uint8List good;
    late List<Map<String, Object?>> deviceBefore;

    setUp(() async {
      await seedOriginal();
      good = await service.exportCurrentContacts(password);
      deviceBefore = snapshot(await ContactService.getContactRecords());
    });

    tearDown(() async {
      ContactService.resetCache();
      expect(
        snapshot(await ContactService.getContactRecords()),
        deviceBefore,
        reason: 'a refused file must never change the stored contacts',
      );
    });

    test('wrong password', () async {
      await expectFailure(
        () => service.decode(good, 'yanlis-sifre-999'),
        ContactBackupFailure.wrongPasswordOrDamaged,
      );
    });

    test('not JSON at all', () async {
      await expectFailure(
        () => service.decode(
          Uint8List.fromList(utf8.encode('BEGIN:VCARD\nEND:VCARD')),
          password,
        ),
        ContactBackupFailure.notABackup,
      );
    });

    test('invalid UTF-8 bytes', () async {
      await expectFailure(
        () => service.decode(Uint8List.fromList([0xff, 0xfe, 0x00]), password),
        ContactBackupFailure.notABackup,
      );
    });

    test('empty file', () async {
      await expectFailure(
        () => service.decode(Uint8List(0), password),
        ContactBackupFailure.notABackup,
      );
    });

    test('the KVKK data export is not a contact backup', () async {
      final kvkk = reencode({
        'exportInfo': {'appName': AppConstants.appName},
        'emergencyContacts': [
          {'name': 'Ada', 'phone': '+905551112233'},
        ],
      });
      await expectFailure(
        () => service.decode(kvkk, password),
        ContactBackupFailure.notABackup,
      );
    });

    test('a JSON array instead of an object', () async {
      await expectFailure(
        () => service.decode(reencode0('[1,2,3]'), password),
        ContactBackupFailure.notABackup,
      );
    });

    test('unsupported future version', () async {
      final json = envelope(good)..['version'] = 2;
      await expectFailure(
        () => service.decode(reencode(json), password),
        ContactBackupFailure.unsupportedVersion,
      );
    });

    test('oversized file is refused before parsing', () async {
      final big = Uint8List(ContactBackupService.maxFileBytes + 1);
      await expectFailure(
        () => service.decode(big, password),
        ContactBackupFailure.tooLarge,
      );
    });

    test('tampered ciphertext', () async {
      final json = envelope(good);
      final ct = base64Decode(json['ciphertext'] as String);
      ct[0] ^= 0x01;
      json['ciphertext'] = base64Encode(ct);
      await expectFailure(
        () => service.decode(reencode(json), password),
        ContactBackupFailure.wrongPasswordOrDamaged,
      );
    });

    test('tampered authenticated header (iterations) fails', () async {
      final json = envelope(good);
      json['kdf']['iterations'] = (json['kdf']['iterations'] as int) + 1;
      await expectFailure(
        () => service.decode(reencode(json), password),
        ContactBackupFailure.wrongPasswordOrDamaged,
      );
    });

    test('iteration count below the accepted floor is refused', () async {
      final json = envelope(good);
      json['kdf']['iterations'] = 1;
      await expectFailure(
        () => service.decode(reencode(json), password),
        ContactBackupFailure.notABackup,
      );
    });

    test('iteration count just above the cap is refused', () async {
      final json = envelope(good);
      json['kdf']['iterations'] =
          ContactBackupService.maxAcceptedIterations + 1;
      await expectFailure(
        () => service.decode(reencode(json), password),
        ContactBackupFailure.notABackup,
      );
    });

    test('absurd iteration count is refused (no CPU lock-up)', () async {
      final json = envelope(good);
      json['kdf']['iterations'] = 1 << 40;
      await expectFailure(
        () => service.decode(reencode(json), password),
        ContactBackupFailure.notABackup,
      );
    });

    test('missing header fields', () async {
      for (final field in ['kdf', 'cipher', 'ciphertext']) {
        final json = envelope(good)..remove(field);
        await expectFailure(
          () => service.decode(reencode(json), password),
          ContactBackupFailure.notABackup,
        );
      }
    });

    test('wrong field types and bad base64', () async {
      final json1 = envelope(good)..['ciphertext'] = 42;
      await expectFailure(
        () => service.decode(reencode(json1), password),
        ContactBackupFailure.notABackup,
      );
      final json2 = envelope(good)..['ciphertext'] = '%%%not-base64%%%';
      await expectFailure(
        () => service.decode(reencode(json2), password),
        ContactBackupFailure.notABackup,
      );
      final json3 = envelope(good);
      json3['cipher']['nonce'] = base64Encode([1, 2, 3]);
      await expectFailure(
        () => service.decode(reencode(json3), password),
        ContactBackupFailure.notABackup,
      );
    });

    test('truncated file', () async {
      final cut = Uint8List.sublistView(good, 0, good.length ~/ 2);
      await expectFailure(
        () => service.decode(cut, password),
        ContactBackupFailure.notABackup,
      );
    });
  });

  group('authentic files with invalid content are refused', () {
    Future<void> expectInvalid(Object payload) async {
      final file = await service.encryptPayloadForTesting(payload, password);
      await expectFailure(
        () => service.decode(file, password),
        ContactBackupFailure.invalidContent,
      );
    }

    Map<String, Object?> item(
      String name,
      String phone, {
      bool primary = false,
    }) => {'name': name, 'phone': phone, 'isPrimary': primary};

    test('empty contact list', () => expectInvalid({'contacts': <Object>[]}));

    test(
      'more than the contact limit',
      () => expectInvalid({
        'contacts': [
          for (var i = 0; i < AppConstants.maxEmergencyContacts + 1; i++)
            item('Kisi $i', '+90555111220$i'),
        ],
      }),
    );

    test(
      'an uncallable phone number',
      () => expectInvalid({
        'contacts': [item('Ada', 'abc')],
      }),
    );

    test(
      'a name hiding a bidi override',
      () => expectInvalid({
        'contacts': [item('Ada\u202Eyilmaz', '+905551112233')],
      }),
    );

    test(
      'a name hiding a zero-width character',
      () => expectInvalid({
        'contacts': [item('Ada\u200B', '+905551112233')],
      }),
    );

    test(
      'an empty name',
      () => expectInvalid({
        'contacts': [item('   ', '+905551112233')],
      }),
    );

    test(
      'duplicate phones',
      () => expectInvalid({
        'contacts': [
          item('Ada', '+905551112233'),
          item('Ada 2', '+905551112233'),
        ],
      }),
    );

    test(
      'two primaries',
      () => expectInvalid({
        'contacts': [
          item('Ada', '+905551112233', primary: true),
          item('Bora', '+905554445566', primary: true),
        ],
      }),
    );

    test(
      'unexpected extra field is refused, not ignored',
      () => expectInvalid({
        'contacts': [
          {...item('Ada', '+905551112233'), 'pin': '1234'},
        ],
      }),
    );

    test(
      'unexpected top-level key is refused',
      () => expectInvalid({
        'contacts': [item('Ada', '+905551112233')],
        'pinCode': '1234',
      }),
    );

    test(
      'wrong types inside an item',
      () => expectInvalid({
        'contacts': [
          {'name': 5, 'phone': '+905551112233', 'isPrimary': false},
        ],
      }),
    );

    test('payload is not an object', () => expectInvalid(<Object>[1, 2]));
  });

  test(
    'restore that cannot be written reports failure and keeps old contacts',
    () async {
      await seedOriginal();
      final before = snapshot(await ContactService.getContactRecords());
      final decoded = await service.decode(
        await service.exportCurrentContacts(password),
        password,
      );
      secure.failWrites = true;

      await expectFailure(
        () => service.restore(decoded.reversed.toList()),
        ContactBackupFailure.writeFailed,
      );

      secure.failWrites = false;
      ContactService.resetCache();
      expect(snapshot(await ContactService.getContactRecords()), before);
    },
  );

  test(
    'a restore interrupted half-way rolls back to the previous list',
    () async {
      await seedOriginal();
      final before = snapshot(await ContactService.getContactRecords());
      final other = await service.decode(
        await service.encryptPayloadForTesting({
          'contacts': [
            {'name': 'Yeni Kisi', 'phone': '+905550001122', 'isPrimary': true},
            {
              'name': 'Diger Kisi',
              'phone': '+905550003344',
              'isPrimary': false,
            },
          ],
        }, password),
        password,
      );

      // The list write lands, the primary-flag write after it does not: the
      // store now holds a half-restored list unless restore() puts the old one
      // back.
      final flaky = _FailNthWrite(2)..store.addAll(secure.store);
      await serviceLocator.unregister<SecureStorage>();
      serviceLocator.registerSingleton<SecureStorage>(flaky);
      ContactService.resetCache();

      await expectFailure(
        () => service.restore(other),
        ContactBackupFailure.writeFailed,
      );

      ContactService.resetCache();
      expect(snapshot(await ContactService.getContactRecords()), before);
    },
  );

  Future<List<EmergencyContact>> otherBackup() async => service.decode(
    await service.encryptPayloadForTesting({
      'contacts': [
        {'name': 'Yeni Kisi', 'phone': '+905550001122', 'isPrimary': true},
        {'name': 'Diger Kisi', 'phone': '+905550003344', 'isPrimary': false},
      ],
    }, password),
    password,
  );

  void swapStorage(FakeSecureStorage next) {
    next.store.addAll(secure.store);
    serviceLocator.unregister<SecureStorage>();
    serviceLocator.registerSingleton<SecureStorage>(next);
    ContactService.resetCache();
  }

  test(
    'an interrupted restore on an EMPTY device rolls back to empty',
    () async {
      final other = await otherBackup();
      swapStorage(_FailNthWrite(2));

      await expectFailure(
        () => service.restore(other),
        ContactBackupFailure.writeFailed,
      );

      ContactService.resetCache();
      expect(await ContactService.getContactRecords(), isEmpty);
    },
  );

  test('a non-platform storage exception still rolls back', () async {
    await seedOriginal();
    final before = snapshot(await ContactService.getContactRecords());
    final other = await otherBackup();
    swapStorage(
      _FailNthWrite(2, error: const FormatException('store refused')),
    );

    await expectFailure(
      () => service.restore(other),
      ContactBackupFailure.writeFailed,
    );

    ContactService.resetCache();
    expect(snapshot(await ContactService.getContactRecords()), before);
  });

  test(
    'process death between the two writes still leaves the chosen primary',
    () async {
      await seedOriginal();
      final other = await otherBackup();
      // Only the first write of the restore lands; everything after it is lost,
      // as if the process were killed between the two writes.
      final dying = _LandFirstNWrites(1);
      swapStorage(dying);

      await expectFailure(
        () => service.restore(other),
        ContactBackupFailure.writeFailed,
      );

      // What the NEXT launch reads is what landed before the kill.
      final afterKill = FakeSecureStorage()..store.addAll(dying.landed);
      serviceLocator.unregister<SecureStorage>();
      serviceLocator.registerSingleton<SecureStorage>(afterKill);
      ContactService.resetCache();
      final primary = await ContactService.getEmergencyContact();
      expect(primary, isNotNull, reason: 'a panic must still have a target');
      expect(primary?.phone, '+905550001122');
    },
  );

  test('a write that silently does not land is detected', () async {
    final decoded = await service.decode(
      await (() async {
        await seedOriginal();
        return service.exportCurrentContacts(password);
      })(),
      password,
    );
    await freshInstall();
    secure.dropWrites = true;

    await expectFailure(
      () => service.restore(decoded),
      ContactBackupFailure.writeFailed,
    );
  });
}

Uint8List reencode0(String raw) => Uint8List.fromList(utf8.encode(raw));

/// Fails exactly the [n]th write, then behaves normally again.
class _FailNthWrite extends FakeSecureStorage {
  _FailNthWrite(this.n, {Exception? error})
    : error = error ?? PlatformException(code: 'write_fail_once');

  final int n;
  final Exception error;
  int _seen = 0;

  @override
  Future<void> write({required String key, required String value}) {
    _seen++;
    if (_seen == n) {
      throw error;
    }
    return super.write(key: key, value: value);
  }
}

/// Records in [landed] only the state after the first [n] writes: what the
/// next launch would read had the process died right there. Later writes are
/// dropped, so the in-process read-back cannot confirm the restore either.
class _LandFirstNWrites extends FakeSecureStorage {
  _LandFirstNWrites(this.n);

  final int n;
  final Map<String, String> landed = <String, String>{};
  int _seen = 0;
  bool _seeded = false;

  @override
  Future<void> write({required String key, required String value}) async {
    if (!_seeded) {
      landed.addAll(store);
      _seeded = true;
    }
    _seen++;
    if (_seen > n) return;
    landed[key] = value;
    await super.write(key: key, value: value);
  }
}
