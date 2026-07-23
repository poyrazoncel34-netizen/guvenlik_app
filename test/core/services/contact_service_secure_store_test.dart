import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_service_test_support.dart';

/// H1 (§10.1/10.2c): canonical source is flutter_secure_storage with a
/// warm, write-through in-memory cache. These tests cover the read/write
/// contract and the no-stale guarantee.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  late FakeSecureStorage secure;
  late FakeLocalDatabaseService db;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    secure = FakeSecureStorage();
    db = FakeLocalDatabaseService();
    serviceLocator.registerSingleton<SecureStorage>(secure);
    serviceLocator.registerSingleton<LocalDatabaseService>(db);
    ContactService.resetCache();
  });

  tearDown(() async {
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  List<dynamic> envelopeContacts() {
    final raw = secure.store[SecureStorageKeys.emergencyContactsV1];
    expect(raw, isNotNull, reason: 'canonical envelope must be written');
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    return decoded['contacts'] as List<dynamic>;
  }

  test('save then read returns the same contacts', () async {
    await ContactService.saveContactRecords(const [
      EmergencyContact(name: 'Ada', phone: '+905551112233'),
      EmergencyContact(name: 'Bora', phone: '+905554445566'),
    ]);

    final read = await ContactService.getContactRecords();
    expect(read.map((c) => c.phone), ['+905551112233', '+905554445566']);
  });

  test('write persists a canonical secure-storage envelope', () async {
    await ContactService.saveContactRecords(const [
      EmergencyContact(name: 'Ada', phone: '+905551112233'),
    ]);

    final contacts = envelopeContacts();
    expect(contacts, hasLength(1));
    expect((contacts.first as Map)['phone'], '+905551112233');
    // Migration flag is set once the new store is in use.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConstants.prefContactsSecureMigratedV1), isTrue);
  });

  test(
    'unsafe URI-like targets never enter the canonical contact store',
    () async {
      await ContactService.saveContactRecords(const [
        EmergencyContact(name: 'URI', phone: 'tel:+905551112233'),
        EmergencyContact(name: 'Extension', phone: '+905554445566;ext=123'),
        EmergencyContact(name: 'Safe', phone: ' (+90) 555-777.88.99 '),
      ]);

      final read = await ContactService.getContactRecords();
      expect(read, hasLength(1));
      expect(read.single.name, 'Safe');
      expect(read.single.phone, '+905557778899');
    },
  );

  test('read with cold cache loads from secure storage and warms', () async {
    // Pre-populate the canonical key directly, then drop the cache.
    secure.store[SecureStorageKeys.emergencyContactsV1] = jsonEncode({
      'version': 1,
      'contacts': [
        {'name': 'Ada', 'phone': '+905551112233', 'isPrimary': true},
      ],
    });
    ContactService.resetCache();

    final read = await ContactService.getContactRecords();
    expect(read, hasLength(1));
    expect(read.first.phone, '+905551112233');
    expect(read.first.isPrimary, isTrue);
  });

  test(
    'getEmergencyContact returns the primary; numbers are primary-first',
    () async {
      await ContactService.saveContactRecords(const [
        EmergencyContact(name: 'Ada', phone: '+905551112233'),
        EmergencyContact(name: 'Bora', phone: '+905554445566'),
      ]);
      await ContactService.savePrimaryEmergencyContact(
        name: 'Bora',
        phone: '+905554445566',
      );

      final primary = await ContactService.getEmergencyContact();
      expect(primary, isNotNull);
      expect(primary!.phone, '+905554445566');

      final numbers = await ContactService.getAllEmergencyNumbers();
      expect(numbers.first, '+905554445566', reason: 'primary served first');
    },
  );

  test('savePrimary write-through demotes the previous primary', () async {
    await ContactService.savePrimaryEmergencyContact(
      name: 'Ada',
      phone: '+905551112233',
    );
    await ContactService.savePrimaryEmergencyContact(
      name: 'Bora',
      phone: '+905554445566',
    );

    final contacts = await ContactService.getContactRecords();
    final primaries = contacts.where((c) => c.isPrimary).toList();
    expect(primaries, hasLength(1));
    expect(primaries.first.phone, '+905554445566');
  });

  test('cache never goes stale: latest write wins on read', () async {
    await ContactService.saveContactRecords(const [
      EmergencyContact(name: 'Ada', phone: '+905551112233'),
    ]);
    await ContactService.saveContactRecords(const [
      EmergencyContact(name: 'Bora', phone: '+905554445566'),
    ]);

    final read = await ContactService.getContactRecords();
    expect(read.map((c) => c.phone), ['+905554445566']);
  });

  test(
    'overlapping contact mutations are serialized without lost updates',
    () async {
      await ContactService.saveContactRecords(const [
        EmergencyContact(name: 'Ada', phone: '+905551112233'),
        EmergencyContact(name: 'Bora', phone: '+905554445566'),
      ]);
      await ContactService.savePrimaryEmergencyContact(
        name: 'Ada',
        phone: '+905551112233',
      );
      final blockedWrite = Completer<void>();
      secure.blockNextWrite = blockedWrite;

      final clear = ContactService.clearPrimaryEmergencyContact();
      while (secure.blockNextWrite != null) {
        await Future<void>.delayed(Duration.zero);
      }
      final selectBora = ContactService.savePrimaryEmergencyContact(
        name: 'Bora',
        phone: '+905554445566',
      );
      await Future<void>.delayed(Duration.zero);
      blockedWrite.complete();
      await Future.wait(<Future<void>>[clear, selectBora]);

      expect(
        (await ContactService.getEmergencyContact())?.phone,
        '+905554445566',
      );
    },
  );

  test(
    'deleteAllContacts verifies secure, database and legacy deletion',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'saved_contacts': <String>['+905551112233'],
        'emergency_contact_phone': '+905551112233',
        'emergency_contact_name': 'Ada',
      });
      secure.store[SecureStorageKeys.contactsData] = 'legacy';
      secure.store[SecureStorageKeys.emergencyContactPhone] = '+905551112233';
      secure.store[SecureStorageKeys.emergencyContactName] = 'Ada';
      await db.seedContact(
        name: 'Ada',
        phone: '+905551112233',
        isPrimary: true,
      );
      await ContactService.savePrimaryEmergencyContact(
        name: 'Ada',
        phone: '+905551112233',
      );

      await ContactService.deleteAllContacts();

      expect(secure.store, isEmpty);
      expect(await db.contactRowCount(), 0);
      expect(await ContactService.getContactRecords(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('saved_contacts'), isFalse);
      expect(prefs.containsKey('emergency_contact_phone'), isFalse);
      expect(prefs.containsKey('emergency_contact_name'), isFalse);
      expect(prefs.getBool(AppConstants.prefContactsSecureMigratedV1), isTrue);
    },
  );

  test(
    'public compatibility APIs preserve explicit-primary call policy',
    () async {
      expect(normalizePhoneNumber('+90 (555) 111-22-33'), '+905551112233');
      expect(normalizePhoneNumber('0555 444 55 66'), '05554445566');

      await ContactService.saveContacts([
        '+905551112233',
        '+90 (555) 111-22-33',
        'tel:+905557778899',
      ]);

      expect(await ContactService.getContacts(), ['+905551112233']);
      expect(
        await ContactService.getEmergencyNumber(),
        isNull,
        reason: 'List order is never implicit consent to call.',
      );

      await ContactService.savePrimaryEmergencyContact(
        name: '',
        phone: '+905551112233',
      );
      expect(await ContactService.getEmergencyNumber(), '+905551112233');

      await ContactService.clearPrimaryEmergencyContact();
      expect(await ContactService.getEmergencyNumber(), isNull);

      await ContactService.saveEmergencyContact(['+905554445566']);
      expect(await ContactService.getContacts(), ['+905554445566']);
    },
  );

  test(
    'legacy prefs numbers and explicit primary migrate without duplicates',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'saved_contacts': <String>[
          '+905551112233',
          '+90 (555) 111-22-33',
          '+905554445566',
          'invalid',
        ],
        'emergency_contact_phone': '+905554445566',
        'emergency_contact_name': 'Bora',
      });
      ContactService.resetCache();

      final contacts = await ContactService.getContactRecords();

      expect(contacts, hasLength(2));
      expect(contacts.where((contact) => contact.isPrimary), hasLength(1));
      expect(
        contacts.singleWhere((contact) => contact.isPrimary).phone,
        '+905554445566',
      );
      expect(envelopeContacts(), hasLength(2));
    },
  );

  test(
    'strict warm-up rejects contacts whose canonical write was lost',
    () async {
      await db.seedContact(
        name: 'Ada',
        phone: '+905551112233',
        isPrimary: true,
      );
      secure.dropWrites = true;

      await expectLater(
        ContactService.warmUpRequired(),
        throwsA(isA<StateError>()),
      );
      expect(await db.contactRowCount(), 1);

      secure.failReads = true;
      await ContactService.warmUp();
    },
  );
}
