import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/screens/contacts_page.dart';

/// S10: "Rehberden Seç" must work WITHOUT READ_CONTACTS. The native picker uses
/// Intent.ACTION_PICK on the phone data URI (temporary per-row grant), replacing
/// fluttercontactpicker_plus which refused to launch on Android 11+ without the
/// permission.
void main() {
  group('native contact picker source contract', () {
    late String mainActivity;
    late String contactsPage;
    late String manifest;

    setUpAll(() {
      mainActivity = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
      ).readAsStringSync();
      contactsPage = File('lib/screens/contacts_page.dart').readAsStringSync();
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

    test('contacts_page calls the channel and dropped the old package', () {
      expect(contactsPage, contains("'pickPhoneContact'"));
      expect(contactsPage, contains('_contactsPickerChannel'));
      expect(contactsPage.contains('fluttercontactpicker_plus'), isFalse);
      expect(contactsPage.contains('FlutterContactPicker'), isFalse);
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
