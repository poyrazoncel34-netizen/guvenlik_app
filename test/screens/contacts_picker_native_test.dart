import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/native_contact_picker_service.dart';

/// S10: "Rehberden Seç" must work WITHOUT READ_CONTACTS. The native picker uses
/// Intent.ACTION_PICK on the phone data URI (temporary per-row grant), replacing
/// fluttercontactpicker_plus which refused to launch on Android 11+ without the
/// permission.
void main() {
  group('native contact picker source contract', () {
    late String mainActivity;
    late String contactsPage;
    late String pickerService;
    late String manifest;

    setUpAll(() {
      mainActivity = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
      ).readAsStringSync();
      contactsPage = File('lib/screens/contacts_page.dart').readAsStringSync();
      // The channel moved out of the screen into a single access path so
      // onboarding could reuse it; the guarantees below did not move.
      pickerService = File(
        'lib/core/services/native_contact_picker_service.dart',
      ).readAsStringSync();
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('MainActivity exposes the picker channel and uses ACTION_PICK', () {
      expect(
        mainActivity,
        contains('com.poyrazoncel.korubeni/contacts_picker'),
      );
      expect(mainActivity, contains('Intent.ACTION_PICK'));
      expect(
        mainActivity,
        contains('ContactsContract.CommonDataKinds.Phone.CONTENT_URI'),
      );
    });

    test('MainActivity forwards super.onActivityResult', () {
      expect(
        mainActivity,
        contains('super.onActivityResult(requestCode, resultCode, data)'),
      );
    });

    test('MainActivity never requests the READ_CONTACTS runtime permission', () {
      // The permissionless picker must not reference the runtime permission API
      // (a comment mentioning READ_CONTACTS is fine; a request is not).
      expect(mainActivity.contains('Manifest.permission.READ_CONTACTS'), isFalse);
      expect(mainActivity.contains('requestPermissions'), isFalse);
    });

    test('the picker service owns the channel and dropped the old package', () {
      expect(pickerService, contains("'pickPhoneContact'"));
      expect(
        pickerService,
        contains('com.poyrazoncel.korubeni/contacts_picker'),
      );
      expect(pickerService.contains('fluttercontactpicker_plus'), isFalse);
      expect(pickerService.contains('FlutterContactPicker'), isFalse);
    });

    test('contacts_page reaches the picker only through that service', () {
      expect(
        contactsPage,
        contains('NativeContactPickerService.pickPhoneContact()'),
      );
      expect(
        contactsPage.contains('com.poyrazoncel.korubeni/contacts_picker'),
        isFalse,
        reason:
            'A second channel to one platform capability is the anti-pattern.',
      );
      expect(contactsPage.contains('fluttercontactpicker_plus'), isFalse);
      expect(contactsPage.contains('FlutterContactPicker'), isFalse);
    });

    test('onboarding reuses the same picker service', () {
      final step = File(
        'lib/screens/onboarding/onboarding_contact_step.dart',
      ).readAsStringSync();
      expect(step, contains('NativeContactPickerService.pickPhoneContact()'));
      expect(
        step.contains('com.poyrazoncel.korubeni/contacts_picker'),
        isFalse,
      );
    });

    test('manifest keeps READ_CONTACTS stripped (tools:node=remove)', () {
      expect(manifest, contains('android.permission.READ_CONTACTS'));
      expect(manifest, contains('tools:node="remove"'));
    });
  });

  group('parsePickedPhoneContact', () {
    test('null map (cancelled) returns null', () {
      expect(parsePickedPhoneContact(null), isNull);
    });

    test('empty/whitespace number returns null', () {
      expect(parsePickedPhoneContact(<String, dynamic>{'number': ''}), isNull);
      expect(
        parsePickedPhoneContact(<String, dynamic>{'number': '   '}),
        isNull,
      );
      expect(
        parsePickedPhoneContact(<String, dynamic>{'name': 'No Number'}),
        isNull,
      );
    });

    test('parses and trims name + number', () {
      final picked = parsePickedPhoneContact(
        <String, dynamic>{'number': ' 0555 123 45 67 ', 'name': '  Ayşe  '},
      );
      expect(picked, isNotNull);
      expect(picked!.number, '0555 123 45 67');
      expect(picked.name, 'Ayşe');
    });

    test('missing name yields empty name with a valid number', () {
      final picked = parsePickedPhoneContact(
        <String, dynamic>{'number': '05551234567'},
      );
      expect(picked, isNotNull);
      expect(picked!.number, '05551234567');
      expect(picked.name, '');
    });
  });
}
