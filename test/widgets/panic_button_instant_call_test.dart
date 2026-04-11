import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/widgets/panic_button.dart').readAsStringSync();
  });

  group('PanicButton countdown-only contract', () {
    test('does not preload contact numbers in the button widget', () {
      expect(
        source.contains('_preloadEmergencyNumber') ||
            source.contains('getPrimaryEmergencyContact') ||
            source.contains('_cachedEmergencyNumber'),
        isFalse,
        reason:
            'PanicButton must not preload numbers; countdown owns dispatch.',
      );
    });

    test('does not pass instantCallTriggered to CountdownScreen', () {
      expect(
        source.contains('instantCallTriggered'),
        isFalse,
        reason:
            'There must be no pre-dispatch flag because no call starts early.',
      );
    });

    test('does not fire-and-forget native emergency calls on release', () {
      expect(
        source.contains('executeEmergencyNative'),
        isFalse,
        reason:
            'Native emergency execution must happen only after countdown expiry.',
      );
    });

    test('release opens CountdownScreen only', () {
      expect(
        source.contains('const CountdownScreen()'),
        isTrue,
        reason: 'PanicButton release should navigate to countdown.',
      );
      final pressEndIndex = source.indexOf('_onPressEnd');
      final navIndex = source.indexOf('_openCountdownScreen');
      expect(
        pressEndIndex < navIndex,
        isTrue,
        reason: '_onPressEnd should delegate only to countdown navigation.',
      );
    });
  });
}
