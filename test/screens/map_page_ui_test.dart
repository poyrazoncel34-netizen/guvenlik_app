import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapPage UI changes', () {
    late String source;
    late String mainNavigation;
    late String homeProvider;
    late String emergencyMap;

    setUpAll(() {
      source = File('lib/screens/map_page.dart').readAsStringSync();
      mainNavigation = File(
        'lib/screens/main_navigation.dart',
      ).readAsStringSync();
      homeProvider = File(
        'lib/presentation/providers/home_provider.dart',
      ).readAsStringSync();
      emergencyMap = File(
        'lib/screens/emergency_map_screen.dart',
      ).readAsStringSync();
    });

    test('shows "map_location" key instead of "map_location_received"', () {
      expect(
        source.contains('"map_location_received".tr()'),
        isFalse,
        reason: '"Konumunuz Alındı" must be removed from status card title',
      );
    });

    test('shows real coordinates or unavailable state in status card', () {
      expect(
        source.contains('_currentLocation!.latitude.toStringAsFixed'),
        isTrue,
        reason:
            'Status card should no longer look static when a location exists',
      );
      expect(
        source.contains('"map_location_unavailable".tr()'),
        isTrue,
        reason: 'Status card should be honest when no location is available',
      );
    });

    test('does not contain "Konum Paylaş" action button', () {
      expect(
        source.contains('"map_share_location".tr()'),
        isFalse,
        reason: 'Blue "Konum Paylaş" action button must be removed',
      );
    });

    test('does not contain "Acil Yardım" SOS action button', () {
      expect(
        source.contains('"map_emergency_help".tr()'),
        isFalse,
        reason: 'Red SOS "Acil Yardım" action button must be removed',
      );
    });

    test('startup does not activate MapPage location request', () {
      expect(
        mainNavigation,
        contains('MapPage(isActive: _selectedIndex == 1)'),
        reason: 'MapPage must stay inactive while Home is selected on startup.',
      );
      expect(
        source,
        contains('if (widget.isActive)'),
        reason: 'MapPage init must not request location while inactive.',
      );
    });

    test('selecting map tab can trigger initial location load', () {
      expect(source, contains('void didUpdateWidget'));
      expect(source, contains('!oldWidget.isActive'));
      expect(source, contains('widget.isActive'));
      expect(source, contains('_initLocation();'));
    });

    test('location sharing start surfaces success and failure to the user', () {
      expect(homeProvider, contains('Future<bool> startLocationSharing'));
      expect(homeProvider, contains('return false;'));
      expect(homeProvider, contains('return true;'));
      expect(
        source,
        contains(
          'final started = await provider.startLocationSharing(minutes)',
        ),
      );
      expect(source, contains('location_sharing_start_failed'));
      expect(source, contains('home_location_shared_desc'));
      expect(
        emergencyMap,
        contains('final started = await provider.startLocationSharing(10)'),
      );
      expect(emergencyMap, contains('location_sharing_start_failed'));
    });
  });
}
