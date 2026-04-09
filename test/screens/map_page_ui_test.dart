import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapPage UI changes', () {
    late String source;

    setUpAll(() {
      source = File('lib/screens/map_page.dart').readAsStringSync();
    });

    test('shows "map_location" key instead of "map_location_received"', () {
      expect(source.contains('"map_location_received".tr()'), isFalse,
          reason: '"Konumunuz Alındı" must be removed from status card title');
    });

    test('does not show coordinate numbers in status card', () {
      expect(
        source.contains('_currentLocation!.latitude.toStringAsFixed'),
        isFalse,
        reason: 'Coordinate numbers must not be shown in the status card',
      );
    });

    test('does not contain "Konum Paylaş" action button', () {
      expect(source.contains('"map_share_location".tr()'), isFalse,
          reason: 'Blue "Konum Paylaş" action button must be removed');
    });

    test('does not contain "Acil Yardım" SOS action button', () {
      expect(source.contains('"map_emergency_help".tr()'), isFalse,
          reason: 'Red SOS "Acil Yardım" action button must be removed');
    });
  });
}


