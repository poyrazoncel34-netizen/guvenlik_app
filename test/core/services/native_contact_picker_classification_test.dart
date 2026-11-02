import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/native_contact_picker_service.dart';

/// The picker used to hand the screens the raw contact-book string. A number
/// grouped with no-break spaces was then rejected and reported as "the
/// contact has no number", while a contact that truly had no number was
/// treated as a silent cancel. Both screens now read ONE classification.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('classifyPickedPhoneContact', () {
    test('a NBSP-grouped contact-book number is picked as the canonical '
        'target', () {
      final result = classifyPickedPhoneContact(<String, dynamic>{
        'number': '0532\u00A0123\u00A045\u00A067',
        'name': 'Anne',
      });

      expect(result.status, ContactPickStatus.picked);
      expect(result.contact?.number, '05321234567');
      expect(result.contact?.name, 'Anne');
      expect(result.failureMessageKey, isNull);
    });

    test('a bidi-wrapped international number is picked as E.164', () {
      final result = classifyPickedPhoneContact(<String, dynamic>{
        'number': '\u202A+90 532 123 45 67\u202C',
        'name': 'Anne',
      });

      expect(result.status, ContactPickStatus.picked);
      expect(result.contact?.number, '+905321234567');
    });

    test('a contact without a number is noNumber, not a silent cancel', () {
      final replies = <Map<String, dynamic>>[
        {'number': '', 'name': 'Anne'},
        {'number': '   ', 'name': 'Anne'},
        {'name': 'Anne'},
        {'number': '\u200E\u202A\u202C', 'name': 'Anne'},
        {'number': '\u00A0\u00A0', 'name': 'Anne'},
      ];
      for (final reply in replies) {
        final result = classifyPickedPhoneContact(reply);
        expect(result.status, ContactPickStatus.noNumber, reason: '$reply');
        expect(result.failureMessageKey, 'contacts_no_phone');
        expect(result.contact, isNull);
      }
    });

    test('a present but uncallable number is invalidNumber with its own '
        'message', () {
      const numbers = <String>[
        '*31#05321234567',
        'tel:+905321234567',
        '05321234567,123',
        '05321234567;123',
        '05321234567p123',
        '0532 123 45 67 ext 12',
        '123456',
        '1234567890123456',
      ];
      for (final number in numbers) {
        final result = classifyPickedPhoneContact(<String, dynamic>{
          'number': number,
          'name': 'Anne',
        });
        expect(result.status, ContactPickStatus.invalidNumber, reason: number);
        expect(result.failureMessageKey, 'contacts_picked_invalid_phone');
        expect(
          result.contact,
          isNull,
          reason: 'an uncallable number must never look like a callable pick',
        );
        expect(result.rejected?.number, number);
      }
    });

    test('a rejected number is offered for correction without its invisible '
        'marks', () {
      final result = classifyPickedPhoneContact(<String, dynamic>{
        'number': '\u202A0532 123 45 67 ext 12\u202C',
        'name': 'Ofis',
      });

      expect(result.status, ContactPickStatus.invalidNumber);
      expect(result.rejected?.number, '0532 123 45 67 ext 12');
      expect(result.rejected?.name, 'Ofis');
    });

    test('a non-String channel value is treated as absent, not thrown', () {
      // An unchecked cast here threw a TypeError that neither screen catches.
      final noNumber = classifyPickedPhoneContact(<String, dynamic>{
        'number': 5321234567,
        'name': 'Anne',
      });
      expect(noNumber.status, ContactPickStatus.noNumber);

      final noName = classifyPickedPhoneContact(<String, dynamic>{
        'number': '05321234567',
        'name': 42,
      });
      expect(noName.status, ContactPickStatus.picked);
      expect(noName.contact?.name, '');
    });

    test('edge line breaks in a reply are trimmed, inner ones are refused', () {
      // The reply has always been trimmed. Line breaks are deliberately NOT
      // sanitized to spaces: inside a number they would merge two lines into
      // one callable target.
      final edges = classifyPickedPhoneContact(<String, dynamic>{
        'number': '\n0532 123 45 67\r\n',
        'name': 'Anne',
      });
      expect(edges.status, ContactPickStatus.picked);
      expect(edges.contact?.number, '05321234567');

      final inner = classifyPickedPhoneContact(<String, dynamic>{
        'number': '+905551234567\r\n999',
        'name': 'Anne',
      });
      expect(inner.status, ContactPickStatus.invalidNumber);
    });

    test('a null reply (the user backed out) stays a quiet cancel', () {
      final result = classifyPickedPhoneContact(null);

      expect(result.status, ContactPickStatus.cancelled);
      expect(result.failureMessageKey, isNull);
      expect(result.contact, isNull);
    });
  });

  group('pickPhoneContact over the channel', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    void reply(Future<Object?> Function(MethodCall call) handler) {
      messenger.setMockMethodCallHandler(
        NativeContactPickerService.channel,
        handler,
      );
    }

    tearDown(() {
      messenger.setMockMethodCallHandler(
        NativeContactPickerService.channel,
        null,
      );
    });

    test('the native reply is classified before a screen sees it', () async {
      reply(
        (_) async => <String, String>{
          'number': '0532\u00A0123\u00A045\u00A067',
          'name': 'Anne',
        },
      );

      final result = await NativeContactPickerService.pickPhoneContact();

      expect(result.status, ContactPickStatus.picked);
      expect(result.contact?.number, '05321234567');
    });

    test('an empty native number is reported as noNumber', () async {
      reply((_) async => <String, String>{'number': '', 'name': 'Anne'});

      final result = await NativeContactPickerService.pickPhoneContact();

      expect(result.status, ContactPickStatus.noNumber);
    });

    test('a channel failure is still reported as unavailable', () async {
      reply((_) async => throw PlatformException(code: 'PICK_FAILED'));

      final result = await NativeContactPickerService.pickPhoneContact();

      expect(result.status, ContactPickStatus.unavailable);
      expect(result.isUnavailable, isTrue);
    });
  });
}
