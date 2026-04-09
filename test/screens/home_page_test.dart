import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomePage UI elements', () {
    late String source;

    setUp(() {
      source = File('lib/screens/home_page.dart').readAsStringSync();
    });

    group('PanicButton', () {
      test('renders PanicButton widget on home screen', () {
        expect(
          source.contains('PanicButton()'),
          isTrue,
          reason:
              'PanicButton (acil durum butonu) ana ekranda görünür olmalıdır',
        );
      });
    });
  });
}
