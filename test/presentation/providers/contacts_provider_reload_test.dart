import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ContactsRepository {}

/// After a contact-backup restore the provider must show the restored list,
/// and must never keep the pre-restore list when the reload fails: its next
/// add/reorder persists the whole in-memory list over secure storage.
void main() {
  late _MockRepository repository;

  setUp(() async {
    await serviceLocator.reset();
    repository = _MockRepository();
    serviceLocator.registerSingleton<ContactsRepository>(repository);
  });

  tearDown(() => serviceLocator.reset());

  test('reload shows the list now in storage, even after initialize', () async {
    when(() => repository.getContactRecords()).thenAnswer(
      (_) async => const [
        EmergencyContact(name: 'Eski', phone: '+905550000001'),
      ],
    );
    when(
      () => repository.getPrimaryEmergencyContact(),
    ).thenAnswer((_) async => null);
    final provider = ContactsProvider();
    await provider.initialize();
    expect(provider.emergencyContacts.single.name, 'Eski');

    when(() => repository.getContactRecords()).thenAnswer(
      (_) async => const [
        EmergencyContact(name: 'Yeni', phone: '+905550000002', isPrimary: true),
      ],
    );
    when(() => repository.getPrimaryEmergencyContact()).thenAnswer(
      (_) async => const EmergencyContact(
        name: 'Yeni',
        phone: '+905550000002',
        isPrimary: true,
      ),
    );

    await provider.reloadFromStorage();

    expect(provider.emergencyContacts.single.name, 'Yeni');
    expect(provider.selectedEmergencyPhone, '+905550000002');
    expect(provider.isLoading, isFalse);
  });

  test('a failed reload drops the stale list instead of keeping it', () async {
    when(() => repository.getContactRecords()).thenAnswer(
      (_) async => const [
        EmergencyContact(name: 'Eski', phone: '+905550000001'),
      ],
    );
    when(
      () => repository.getPrimaryEmergencyContact(),
    ).thenAnswer((_) async => null);
    final provider = ContactsProvider();
    await provider.initialize();

    when(
      () => repository.getContactRecords(),
    ).thenThrow(PlatformException(code: 'read_fail'));

    await provider.reloadFromStorage();

    expect(provider.emergencyContacts, isEmpty);
    expect(provider.isLoading, isFalse);

    // Uninitialised again, so the next screen open re-reads storage.
    when(() => repository.getContactRecords()).thenAnswer(
      (_) async => const [
        EmergencyContact(name: 'Yeni', phone: '+905550000002'),
      ],
    );
    await provider.initialize();
    expect(provider.emergencyContacts.single.name, 'Yeni');
  });
}
