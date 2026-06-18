// Source-contract test (repo convention: assert behaviour via source, see
// edit_profile_screen_test / settings_provider_no_shake_test). Guarantees the
// KVKK Md.11 export output can never contain removed medical-profile fields.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserDataExportService medical-profile removal', () {
    late String source;

    setUp(() {
      source = File(
        'lib/core/services/user_data_export_service.dart',
      ).readAsStringSync();
    });

    test('export no longer reads the medical profile secure key', () {
      expect(
        source.contains('medicalProfile') ||
            source.contains('_sensitiveProfile'),
        isFalse,
        reason: 'Export must not reference the removed medical profile data',
      );
    });

    test('export profile payload excludes all sensitive medical fields', () {
      for (final field in const [
        "'bloodType'",
        "'allergies'",
        "'medicalConditions'",
        "'emergencyNotes'",
      ]) {
        expect(
          source.contains(field),
          isFalse,
          reason: 'Export profile must not contain $field',
        );
      }
    });
  });
}
