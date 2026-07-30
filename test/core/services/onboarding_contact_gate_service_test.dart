import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/onboarding_contact_gate_service.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_service_test_support.dart';

/// Onboarding used to write prefOnboardingDone unconditionally, so an install
/// could reach the home screen with nothing to call. These tests pin the gate:
/// completion is impossible without a callable primary contact, and the gate
/// reads the canonical secure-storage source.
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

  Future<bool?> onboardingDoneFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefOnboardingDone);
  }

  group('gate state', () {
    test('an empty contact store does not satisfy the gate', () async {
      expect(await OnboardingContactGateService.hasCallableContact(), isFalse);
    });

    test('a saved primary contact satisfies the gate', () async {
      await ContactService.savePrimaryEmergencyContact(
        name: 'Ada',
        phone: '+905551112233',
      );

      expect(await OnboardingContactGateService.hasCallableContact(), isTrue);
      expect(await OnboardingContactGateService.primaryContactName(), 'Ada');
    });

    test('a non-primary contact alone does not satisfy the gate', () async {
      await ContactService.saveContactRecords(const [
        EmergencyContact(name: 'Ada', phone: '+905551112233'),
      ]);

      // List order is not consent to call; only an explicit primary counts.
      expect(await OnboardingContactGateService.hasCallableContact(), isFalse);
    });

    test('a stored primary with an uncallable number fails the gate', () async {
      // Written straight into the canonical envelope: the gate must not trust
      // stored data that arming would later reject.
      secure.store[SecureStorageKeys.emergencyContactsV1] = jsonEncode({
        'version': 1,
        'contacts': [
          {'name': 'Short', 'phone': '12', 'isPrimary': true},
        ],
      });
      ContactService.resetCache();

      expect(await OnboardingContactGateService.hasCallableContact(), isFalse);
    });

    test('a storage read failure fails the gate closed', () async {
      await ContactService.savePrimaryEmergencyContact(
        name: 'Ada',
        phone: '+905551112233',
      );
      ContactService.resetCache();
      secure.failReads = true;

      expect(await OnboardingContactGateService.hasCallableContact(), isFalse);
    });
  });

  group('phone validation', () {
    test('rejects numbers the dispatch path would refuse', () {
      expect(OnboardingContactGateService.phoneErrorKey('12'), isNotNull);
      expect(OnboardingContactGateService.phoneErrorKey(''), isNotNull);
      expect(
        OnboardingContactGateService.phoneErrorKey('tel:+905551112233'),
        isNotNull,
      );
    });

    test('accepts a callable target', () {
      expect(
        OnboardingContactGateService.phoneErrorKey('+90 555 111 22 33'),
        isNull,
      );
    });
  });

  group('saving', () {
    test('an invalid number is not written and leaves the gate closed', () async {
      final outcome = await OnboardingContactGateService.savePrimaryContact(
        name: 'Ada',
        phone: '12',
      );

      expect(outcome, OnboardingContactSaveOutcome.invalidPhone);
      expect(secure.store[SecureStorageKeys.emergencyContactsV1], isNull);
      expect(await OnboardingContactGateService.hasCallableContact(), isFalse);
    });

    test('a valid contact lands in the canonical secure store', () async {
      final outcome = await OnboardingContactGateService.savePrimaryContact(
        name: 'Ada',
        phone: '0555 111 22 33',
      );

      expect(outcome, OnboardingContactSaveOutcome.saved);
      final raw = secure.store[SecureStorageKeys.emergencyContactsV1];
      expect(raw, isNotNull);
      final contacts =
          (jsonDecode(raw!) as Map<String, dynamic>)['contacts'] as List<dynamic>;
      expect(contacts, hasLength(1));
      expect((contacts.single as Map)['isPrimary'], isTrue);
    });

    test('a lost write is reported as a failure, not a success', () async {
      secure.dropWrites = true;

      final outcome = await OnboardingContactGateService.savePrimaryContact(
        name: 'Ada',
        phone: '+905551112233',
      );

      expect(outcome, OnboardingContactSaveOutcome.storageFailed);
    });

    test('the legacy contacts table stays empty', () async {
      await OnboardingContactGateService.savePrimaryContact(
        name: 'Ada',
        phone: '+905551112233',
      );

      expect(await db.contactRowCount(), 0);
    });
  });

  group('completion', () {
    test('completeOnboarding refuses to write without a contact', () async {
      expect(await OnboardingContactGateService.completeOnboarding(), isFalse);
      expect(await onboardingDoneFlag(), isNull);
    });

    test('completeOnboarding writes the flag once the gate is satisfied', () async {
      await OnboardingContactGateService.savePrimaryContact(
        name: 'Ada',
        phone: '+905551112233',
      );

      expect(await OnboardingContactGateService.completeOnboarding(), isTrue);
      expect(await onboardingDoneFlag(), isTrue);
    });

    test('a contact removed after saving re-closes completion', () async {
      await OnboardingContactGateService.savePrimaryContact(
        name: 'Ada',
        phone: '+905551112233',
      );
      await ContactService.clearPrimaryEmergencyContact();

      expect(await OnboardingContactGateService.completeOnboarding(), isFalse);
      expect(await onboardingDoneFlag(), isNull);
    });
  });

  group('contact-data consent', () {
    test('an unregistered consent manager reports consent as needed', () {
      expect(OnboardingContactGateService.needsContactDataConsent(), isTrue);
    });

    test('a declined category consent reports consent as needed', () async {
      final manager = ConsentManager();
      await manager.initialize();
      serviceLocator.registerSingleton<ConsentManager>(manager);

      expect(OnboardingContactGateService.needsContactDataConsent(), isTrue);
    });

    test('granting from the step clears the requirement', () async {
      final manager = ConsentManager();
      await manager.initialize();
      serviceLocator.registerSingleton<ConsentManager>(manager);

      final granted = await OnboardingContactGateService
          .grantContactDataConsent(locale: 'tr');

      expect(granted, isTrue);
      expect(OnboardingContactGateService.needsContactDataConsent(), isFalse);
      expect(manager.isGranted(ConsentRecord.typeEmergencyContacts), isTrue);
    });

    test('granting without a registered manager fails instead of throwing', () async {
      final granted = await OnboardingContactGateService
          .grantContactDataConsent(locale: 'tr');

      expect(granted, isFalse);
    });
  });
}
