// Verifies the countdown screen surfaces the remaining-time announcement
// to screen readers via a Semantics liveRegion, and that the announcement
// schedule is sparse enough to avoid TalkBack spamming every second.
//
// Convention in this repo: widget tests for screens are source-level
// contracts (see panic_button_test.dart, panic_button_instant_call_test.dart).
// Full integration testing is impractical for CountdownScreen because it
// depends on platform channels (WakelockPlus, AlarmManager, AudioContext,
// haptics) and a configured ServiceLocator.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/countdown_screen.dart').readAsStringSync();
  });

  group('CountdownScreen liveRegion contract', () {
    test('wraps countdown number in Semantics(liveRegion: true)', () {
      expect(
        source.contains('liveRegion: true'),
        isTrue,
        reason:
            'TalkBack will not announce countdown updates unless the surrounding '
            'Semantics widget is marked liveRegion: true.',
      );
    });

    test('uses the countdown_seconds_remaining translation key', () {
      expect(
        source.contains("'countdown_seconds_remaining'"),
        isTrue,
        reason: 'liveRegion label must use the localized announcement key.',
      );
    });

    test('declares the sparse bucket helper _liveCountdownBucket', () {
      expect(
        source.contains('_liveCountdownBucket'),
        isTrue,
        reason:
            'Sparse announcement bucketing must exist so TalkBack does not '
            'speak every second — that would be noise during the panic flow.',
      );
    });

    test('bucket helper covers 10, 8, 5 thresholds plus per-second 4..1', () {
      final bucketStart = source.indexOf('_liveCountdownBucket(int seconds)');
      expect(
        bucketStart,
        isNot(-1),
        reason: '_liveCountdownBucket signature missing',
      );
      final window = source.substring(
        bucketStart,
        (bucketStart + 600).clamp(0, source.length),
      );
      expect(window.contains('seconds >= 10'), isTrue, reason: '10s bucket missing');
      expect(window.contains('seconds >= 8'), isTrue, reason: '8s bucket missing');
      expect(window.contains('seconds >= 5'), isTrue, reason: '5s bucket missing');
      expect(window.contains('seconds >= 1'), isTrue, reason: 'Per-second 4..1 fall-through missing');
    });

    test('content inside the live region is excluded from semantics', () {
      expect(
        source.contains('ExcludeSemantics('),
        isTrue,
        reason:
            'Without ExcludeSemantics the inner Text widgets would still '
            'be announced, defeating the bucketed schedule.',
      );
    });
  });

  group('Translation keys for liveRegion are present', () {
    test('tr-TR.json defines countdown_seconds_remaining with {seconds} arg', () {
      final tr =
          jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(tr.containsKey('countdown_seconds_remaining'), isTrue);
      expect(
        (tr['countdown_seconds_remaining'] as String).contains('{seconds}'),
        isTrue,
        reason:
            'Localized announcement must interpolate the bucket number — '
            'a hardcoded sentence would lose the remaining-time info.',
      );
    });

    test('en-US.json defines countdown_seconds_remaining with {seconds} arg', () {
      final en =
          jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(en.containsKey('countdown_seconds_remaining'), isTrue);
      expect(
        (en['countdown_seconds_remaining'] as String).contains('{seconds}'),
        isTrue,
      );
    });
  });
}
