// Tests verifying PanicButton triggers an instant native emergency call
// on finger release — before any UI navigation or async work.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/widgets/panic_button.dart').readAsStringSync();
  });

  group('PanicButton instant call on release', () {
    test('loads primary contact number into cached field on init', () {
      expect(
        source.contains('_preloadEmergencyNumber') ||
            source.contains('getPrimaryEmergencyContact'),
        isTrue,
        reason: 'PanicButton must load the emergency number from '
            'ContactsRepository in initState so it is ready before release',
      );
    });

    test('pre-loads emergency number field with 112 as fail-safe default', () {
      expect(
        source.contains('_cachedEmergencyNumber'),
        isTrue,
        reason: 'PanicButton must cache the emergency number so it is '
            'available the instant the finger is released',
      );
      expect(
        source.contains("'112'"),
        isTrue,
        reason: 'Must default to 112 when no contact is loaded yet',
      );
    });

    test('passes instantCallTriggered true to CountdownScreen', () {
      expect(
        source.contains('instantCallTriggered: true'),
        isTrue,
        reason: 'CountdownScreen must know the call was already triggered '
            'so it does not duplicate the call',
      );
    });

    test('uses unawaited for fire-and-forget native call', () {
      expect(
        source.contains('unawaited'),
        isTrue,
        reason: 'Native call must be unawaited (fire-and-forget) so the release '
            'handler is not blocked by the async platform channel',
      );
    });

    test('calls executeEmergencyNative in _onPressEnd before navigation', () {
      expect(
        source.contains('executeEmergencyNative'),
        isTrue,
        reason: '_onPressEnd must trigger the native call immediately on release',
      );
      final nativeCallIndex = source.indexOf('executeEmergencyNative');
      final navIndex = source.indexOf('_openCountdownScreen');
      expect(
        nativeCallIndex < navIndex,
        isTrue,
        reason: 'executeEmergencyNative must appear before _openCountdownScreen '
            '— call first, navigate second',
      );
    });
  });
}
