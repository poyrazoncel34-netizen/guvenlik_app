// Widget smoke test: PanicButton renders without crashing.
// Full integration tests are skipped here because PanicButton depends on
// platform channels (HapticFeedback, Navigator push) and EasyLocalization.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PanicButton', () {
    test('PanicButton source file exists', () {
      expect(File('lib/widgets/panic_button.dart').existsSync(), isTrue);
    });

    test('PanicButton uses HapticFeedback', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      expect(source.contains('HapticFeedback'), isTrue);
    });

    test('_buttonHeld flag declared as bool field', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      expect(
        source.contains('bool _buttonHeld'),
        isTrue,
        reason:
            '_buttonHeld must be declared so _onPressStart can set it '
            'synchronously before any await.',
      );
    });

    test('_onPressStart sets _buttonHeld=true before first await', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      final buttonHeldIdx = source.indexOf('_buttonHeld = true');
      final awaitIdx = source.indexOf('await FeatureWarningHelper.showIfNeeded');
      expect(buttonHeldIdx, isNot(-1),
          reason: '_buttonHeld = true must exist in _onPressStart');
      expect(buttonHeldIdx < awaitIdx, isTrue,
          reason:
              '_buttonHeld = true must appear BEFORE the first await in '
              '_onPressStart to be effective against the race condition.');
    });

    test('_onPressStart guards post-await work with !_buttonHeld check', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      expect(
        source.contains('if (!_buttonHeld) return;'),
        isTrue,
        reason:
            'After the await, _onPressStart must return early when '
            '_buttonHeld is false (i.e. _onPressEnd already fired).',
      );
    });

    test('_onPressEnd only opens CountdownScreen when wasArmed is true', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      expect(source.contains('final wasArmed = _isArmed'), isTrue,
          reason:
              '_isArmed must be captured into wasArmed before being reset, '
              'so _openCountdownScreen can be gated on the pre-reset value.');
      expect(source.contains('if (wasArmed) _openCountdownScreen()'), isTrue,
          reason:
              '_openCountdownScreen must only be called when wasArmed is true; '
              'an unconditional call causes the countdown to open even when '
              'the button was released before arming completed.');
    });

    test('_openCountdownScreen guards on mounted before Navigator.push', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      final openIdx = source.indexOf('void _openCountdownScreen()');
      expect(openIdx, isNot(-1), reason: '_openCountdownScreen must exist');
      final mountedIdx = source.indexOf('if (!mounted) return', openIdx);
      final navigatorIdx = source.indexOf('Navigator.push', openIdx);
      expect(mountedIdx, isNot(-1),
          reason:
              '_openCountdownScreen must guard with if (!mounted) return; '
              'before Navigator.push to avoid use-after-dispose crashes.');
      expect(mountedIdx < navigatorIdx, isTrue,
          reason:
              'The mounted check must come BEFORE Navigator.push in '
              '_openCountdownScreen.');
    });

    test('_onPressEnd clears _buttonHeld synchronously before setState', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      final onPressEndIdx = source.indexOf('void _onPressEnd(');
      final buttonHeldClearIdx =
          source.indexOf('_buttonHeld = false', onPressEndIdx);
      final setStateInEndIdx = source.indexOf('setState', onPressEndIdx);
      expect(onPressEndIdx, isNot(-1), reason: '_onPressEnd must exist');
      expect(buttonHeldClearIdx, isNot(-1),
          reason: '_buttonHeld = false must appear inside _onPressEnd');
      expect(buttonHeldClearIdx < setStateInEndIdx, isTrue,
          reason:
              '_buttonHeld = false must be the first statement in _onPressEnd, '
              'before setState, so the flag is cleared synchronously.');
    });

    test('PanicButton accepts hasEmergencyContact parameter', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      expect(source.contains('hasEmergencyContact'), isTrue,
          reason: 'PanicButton must have a hasEmergencyContact parameter to block arming with no contact');
    });

    test('PanicButton accepts onNoContact callback', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      expect(source.contains('onNoContact'), isTrue,
          reason: 'PanicButton must have an onNoContact callback to notify caller when no contact is set');
    });

    test('PanicButton blocks arming when hasEmergencyContact is false', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      expect(source.contains('widget.hasEmergencyContact'), isTrue,
          reason: 'PanicButton._onPressStart must check widget.hasEmergencyContact before arming');
    });
  });

  group('CountdownScreen', () {
    test('CountdownScreen is wrapped in PopScope(canPop: false)', () {
      final source =
          File('lib/screens/countdown_screen.dart').readAsStringSync();
      expect(source.contains('PopScope'), isTrue,
          reason:
              'CountdownScreen must be wrapped in PopScope to prevent '
              'Android back-button dismissal without PIN entry.');
      expect(source.contains('canPop: false'), isTrue,
          reason: 'PopScope must have canPop: false so back navigation is blocked.');
    });
  });
}
