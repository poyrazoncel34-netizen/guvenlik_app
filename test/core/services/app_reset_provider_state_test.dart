import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/services/app_reset_service.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/core/services/app_reset_state_registry.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';

class _MemoryContactsRepository implements ContactsRepository {
  final List<EmergencyContact> records = <EmergencyContact>[
    const EmergencyContact(name: 'Eski Kişi', phone: '+905551112233'),
  ];
  EmergencyContact? primary;

  @override
  Future<void> clearPrimaryEmergencyContact() async => primary = null;

  @override
  Future<List<String>> getAllEmergencyNumbers() async =>
      records.map((contact) => contact.phone).toList();

  @override
  Future<List<EmergencyContact>> getContactRecords() async =>
      List<EmergencyContact>.from(records);

  @override
  Future<List<String>> getContacts() async =>
      records.map((contact) => contact.phone).toList();

  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async => primary;

  @override
  Future<void> saveContactRecords(List<EmergencyContact> contacts) async {
    records
      ..clear()
      ..addAll(contacts);
  }

  @override
  Future<void> saveContacts(List<String> numbers) async {
    records
      ..clear()
      ..addAll(
        numbers.map((phone) => EmergencyContact(name: '', phone: phone)),
      );
  }

  @override
  Future<void> saveEmergencyNumbers(List<String> numbers) =>
      saveContacts(numbers);

  @override
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {
    primary = EmergencyContact(name: name, phone: phone);
  }
}

class _ProviderResetStore implements AppResetLocalDataStore {
  _ProviderResetStore(this.repository);

  final _MemoryContactsRepository repository;

  @override
  Future<bool> clearLocalFiles() async => true;

  @override
  Future<bool> clearPreferences() async => true;

  @override
  Future<void> clearSecureStorage() async {
    repository.records.clear();
    repository.primary = null;
  }

  @override
  Future<void> deleteDatabase() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryContactsRepository repository;
  late ContactsProvider provider;

  setUp(() async {
    await serviceLocator.reset();
    repository = _MemoryContactsRepository();
    serviceLocator.registerSingleton<ContactsRepository>(repository);
    provider = ContactsProvider();
    await provider.initialize();
  });

  tearDown(() async {
    provider.dispose();
    await serviceLocator.reset();
  });

  test(
    'successful data deletion clears a live provider and cannot resurrect old contacts',
    () async {
      expect(provider.emergencyContacts, hasLength(1));

      final result = await AppResetService.clearLocalData(
        emergencyPlatform: EmergencyPlatformService.forTesting(
          methodChannel: const MethodChannel('provider-reset-test'),
          supported: false,
        ),
        localStore: _ProviderResetStore(repository),
      );

      expect(result, WipeResult.completed);
      expect(repository.records, isEmpty);
      expect(
        provider.emergencyContacts,
        isEmpty,
        reason: 'the process-lived ContactsProvider must forget deleted data',
      );

      expect(
        await provider.addContact(name: 'Yeni Kişi', phone: '+905559998877'),
        isTrue,
      );
      expect(repository.records.map((contact) => contact.name), <String>[
        'Yeni Kişi',
      ]);
    },
  );

  test(
    'a provider that cannot forget downgrades the wipe to unknown',
    () async {
      // Storage deletion succeeding while process-lived state survives is NOT
      // a completed wipe: the user was promised the data is gone, and a later
      // save from that stale provider can write it back. The caller must see
      // `unknown` so it does not report success.
      final failing = Object();
      AppResetStateRegistry.register(
        failing,
        () async => throw StateError('provider refused to reset'),
      );
      addTearDown(() => AppResetStateRegistry.unregister(failing));

      final result = await AppResetService.clearLocalData(
        emergencyPlatform: EmergencyPlatformService.forTesting(
          methodChannel: const MethodChannel('provider-reset-test'),
          supported: false,
        ),
        localStore: _ProviderResetStore(repository),
      );

      expect(
        result,
        WipeResult.unknown,
        reason: 'a refused in-memory invalidation must not report completed',
      );
      expect(repository.records, isEmpty, reason: 'storage still cleared');
    },
  );
}
