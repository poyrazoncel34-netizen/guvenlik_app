import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_contact_consent_withdrawal_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'publishes withdrawal, wipes native state, then deletes contacts',
    () async {
      final events = <String>[];
      final service = EmergencyContactConsentWithdrawalService(
        revokeConsent: (locale) async => events.add('revoke:$locale'),
        persistPreferenceWithdrawal: () async {
          events.add('preference');
          return true;
        },
        platformSupported: true,
        wipeEmergencySessions: () async {
          events.add('wipe');
          return WipeResult.completed;
        },
        clearSessionProjections: () async {
          events.add('projection');
          return true;
        },
        deleteContacts: () async => events.add('delete'),
      );

      expect(await service.withdraw(locale: 'tr'), WipeResult.completed);
      expect(events, <String>[
        'revoke:tr',
        'preference',
        'wipe',
        'projection',
        'delete',
      ]);
    },
  );

  test('unknown native wipe keeps contact data and reports unknown', () async {
    final events = <String>[];
    final service = EmergencyContactConsentWithdrawalService(
      revokeConsent: (_) async => events.add('revoke'),
      persistPreferenceWithdrawal: () async {
        events.add('preference');
        return true;
      },
      platformSupported: true,
      wipeEmergencySessions: () async {
        events.add('wipe');
        return WipeResult.unknown;
      },
      clearSessionProjections: () async {
        events.add('projection');
        return true;
      },
      deleteContacts: () async => events.add('delete'),
    );

    expect(await service.withdraw(), WipeResult.unknown);
    expect(events, <String>['revoke', 'preference', 'wipe']);
  });

  test(
    'rejected preference commit stops before native or contact mutation',
    () async {
      final events = <String>[];
      final service = EmergencyContactConsentWithdrawalService(
        revokeConsent: (_) async => events.add('revoke'),
        persistPreferenceWithdrawal: () async {
          events.add('preference');
          return false;
        },
        platformSupported: true,
        wipeEmergencySessions: () async {
          events.add('wipe');
          return WipeResult.completed;
        },
        clearSessionProjections: () async {
          events.add('projection');
          return true;
        },
        deleteContacts: () async => events.add('delete'),
      );

      expect(await service.withdraw(), WipeResult.unknown);
      expect(events, <String>['revoke', 'preference']);
    },
  );

  test('contact deletion failure can never become completed', () async {
    final service = EmergencyContactConsentWithdrawalService(
      revokeConsent: (_) async {},
      persistPreferenceWithdrawal: () async => true,
      platformSupported: false,
      clearSessionProjections: () async => true,
      deleteContacts: () async => throw StateError('delete failed'),
    );

    expect(await service.withdraw(), WipeResult.unknown);
  });

  test(
    'projection cleanup failure retains contacts and reports unknown',
    () async {
      final events = <String>[];
      final service = EmergencyContactConsentWithdrawalService(
        revokeConsent: (_) async => events.add('revoke'),
        persistPreferenceWithdrawal: () async {
          events.add('preference');
          return true;
        },
        platformSupported: true,
        wipeEmergencySessions: () async {
          events.add('wipe');
          return WipeResult.completed;
        },
        clearSessionProjections: () async {
          events.add('projection');
          return false;
        },
        deleteContacts: () async => events.add('delete'),
      );

      expect(await service.withdraw(), WipeResult.unknown);
      expect(events, <String>['revoke', 'preference', 'wipe', 'projection']);
    },
  );
}
