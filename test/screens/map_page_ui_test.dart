import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapPage UI changes', () {
    late String source;
    late String mainNavigation;
    late String homeProvider;

    setUpAll(() {
      source = File('lib/screens/map_page.dart').readAsStringSync();
      mainNavigation = File(
        'lib/screens/main_navigation.dart',
      ).readAsStringSync();
      homeProvider = File(
        'lib/presentation/providers/home_provider.dart',
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

    test(
      'location requests use prominent disclosure helper before native prompt',
      () {
        // The disclosure call moved into LocationConsentGate so the same
        // choke point also enforces withdrawn in-app consent, and so
        // map_page.dart stops growing against its size ratchet. The Play
        // requirement is unchanged: prominent disclosure still runs before the
        // native prompt, one layer down.
        expect(
          source,
          contains("import '../core/services/location_consent_gate.dart';"),
        );
        expect(source, contains('Future<bool> _ensureLocationPermission()'));
        expect(
          source,
          contains('LocationConsentGate.ensureAllowed(context)'),
        );
        final gate = File(
          'lib/core/services/location_consent_gate.dart',
        ).readAsStringSync();
        expect(
          gate,
          contains('PermissionHelper.requestLocationPermission(context)'),
          reason:
              'The prominent-disclosure helper must still be what asks for the '
              'OS permission; only its call site moved.',
        );
        expect(
          source.indexOf('_ensureLocationPermission()') <
              source.indexOf('_locationRepository.getLastKnownLocation()'),
          isTrue,
          reason:
              'Map tab must show the prominent location disclosure before '
              'reading/requesting location via LocationService.',
        );
      },
    );

    test('location-session sharing UI is removed (S6/S8)', () {
      for (final symbol in const [
        'startLocationSharing',
        'isLocationSharing',
        '_toggleLocationSharing',
        '_showLocationShareOptions',
        '"map_live"',
        'location_share_duration',
        'location_disabled_outlined',
      ]) {
        expect(
          source.contains(symbol),
          isFalse,
          reason: '$symbol must be removed with the location-session feature',
        );
      }
      // The free coordinate read-out must stay on the status card.
      expect(source, contains('"map_location".tr()'));
      // And the provider must no longer expose the sharing API.
      expect(homeProvider.contains('startLocationSharing'), isFalse);
    });

    test('OpenStreetMap use stays user-viewed and attributed', () {
      final docs = [
        File('docs/play_console_declarations.md'),
        File('docs/release_risks.md'),
        File('store/DATA_SAFETY_FORM.md'),
        File('store/PLAY_CONSOLE_COPY_PASTE_PACK.md'),
      ].map((file) => file.readAsStringSync()).join('\n');

      expect(source, contains('© OpenStreetMap contributors'));
      expect(source, contains('user actively views'));
      expect(source, contains('Do not bulk download'));
      expect(source, isNot(contains('.mbtiles')));
      expect(docs, contains('must not bulk download'));
      expect(docs, contains('pre-seed'));
      expect(docs, contains('archive'));
      expect(docs, contains('128 MiB'));
      expect(docs, contains('candidate-bound'));
      expect(docs, contains('NETWORK_CAPTURE_AND_COUNSEL_UNVERIFIED'));
    });
  });
}
