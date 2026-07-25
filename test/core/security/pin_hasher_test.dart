import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/pin_hasher.dart';

void main() {
  test('the stored record never contains the PIN', () {
    final record = PinHasher.encode('4821', iterations: 1000);

    expect(record.contains('4821'), isFalse);
    expect(record.startsWith('pbkdf2_sha256\$1000\$'), isTrue);
  });

  test('the same PIN produces a different record every time', () {
    final first = PinHasher.encode('4821', iterations: 1000);
    final second = PinHasher.encode('4821', iterations: 1000);

    expect(
      first,
      isNot(second),
      reason: 'a per-record salt is what stops two identical PINs from being '
          'recognisable as identical',
    );
    expect(PinHasher.matches(stored: first, candidate: '4821'), isTrue);
    expect(PinHasher.matches(stored: second, candidate: '4821'), isTrue);
  });

  test('verification accepts only the right PIN', () {
    final record = PinHasher.encode('4821', iterations: 1000);

    expect(PinHasher.matches(stored: record, candidate: '4821'), isTrue);
    for (final wrong in <String>['4822', '1284', '', '48210', '482']) {
      expect(PinHasher.matches(stored: record, candidate: wrong), isFalse);
    }
  });

  test('the iteration count is read back from the record, not assumed', () {
    final record = PinHasher.encode('1357', iterations: 2000);

    expect(record.contains('\$2000\$'), isTrue);
    expect(
      PinHasher.matches(stored: record, candidate: '1357'),
      isTrue,
      reason:
          'raising the default later must not lock out records written with '
          'the old cost',
    );
  });

  test('a corrupt record fails closed instead of throwing', () {
    for (final broken in <String>[
      'pbkdf2_sha256\$notanumber\$c2FsdA==\$aGFzaA==',
      'pbkdf2_sha256\$1000\$!!!not-base64!!!\$aGFzaA==',
      'pbkdf2_sha256\$1000\$c2FsdA==',
      'pbkdf2_sha256\$0\$c2FsdA==\$aGFzaA==',
      '',
    ]) {
      expect(
        () => PinHasher.matches(stored: broken, candidate: '4821'),
        returnsNormally,
      );
      expect(PinHasher.matches(stored: broken, candidate: '4821'), isFalse);
    }
  });

  test('a pre-hash raw PIN is recognised as legacy', () {
    expect(PinHasher.isLegacyPlaintext('4821'), isTrue);
    expect(
      PinHasher.isLegacyPlaintext(PinHasher.encode('4821', iterations: 1000)),
      isFalse,
    );
    expect(PinHasher.isLegacyPlaintext(''), isFalse);
  });

  test('the shipped cost stays inside the emergency-path budget', () {
    expect(PinHasher.defaultIterations, greaterThanOrEqualTo(100000));
    final stopwatch = Stopwatch()..start();
    PinHasher.encode('4821');
    stopwatch.stop();
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(2000),
      reason:
          'PIN verification sits on the cancel-an-armed-session path; a slow '
          'derivation is a safety cost, not just a UX one.',
    );
  });
}
