import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomePage UI elements', () {
    late String source;

    setUp(() {
      source = File('lib/screens/home_page.dart').readAsStringSync();
    });

    group('PanicButton removed', () {
      test('does not render PanicButton widget', () {
        expect(
          source.contains('child: PanicButton('),
          isFalse,
          reason:
              'PanicButton (Hızlı Yardım) has been removed from the home screen',
        );
      });
    });

    group('LocationCard removed', () {
      test('does not call _buildLocationCard', () {
        expect(
          source.contains('_buildLocationCard(provider)'),
          isFalse,
          reason:
              'Konum Paylaşımı card has been removed from the home screen',
        );
      });
    });

    group('QuickMessage removed', () {
      test('quick_message action is not in the actions list', () {
        expect(
          source.contains('"quick_message"'),
          isFalse,
          reason:
              'Hızlı Mesaj action has been removed (SMS feature was removed)',
        );
      });
    });
  });
}
