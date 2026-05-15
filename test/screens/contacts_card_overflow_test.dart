import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contacts kart — isim overflow', () {
    test('contact name is constrained before emergency badge', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      final badgeIndex = source.indexOf('contacts_emergency_badge');
      final flexibleIndex = source.lastIndexOf('Flexible(', badgeIndex);
      final nameIndex = source.lastIndexOf('contact.name', badgeIndex);
      final ellipsisIndex = source.lastIndexOf(
        'TextOverflow.ellipsis',
        badgeIndex,
      );

      expect(badgeIndex, isNot(-1));
      expect(flexibleIndex, isNot(-1));
      expect(nameIndex, isNot(-1));
      expect(ellipsisIndex, isNot(-1));

      expect(flexibleIndex < nameIndex, isTrue);
      expect(nameIndex < badgeIndex, isTrue);
      expect(ellipsisIndex < badgeIndex, isTrue);
    });
  });
}
