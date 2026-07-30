import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/countdown_announcement.dart';

/// Extracted from countdown_screen.dart (size ratchet). The sparse schedule is
/// what stops TalkBack from speaking every single second of a panic countdown.
void main() {
  group('bucketFor', () {
    test('announces 10 alone', () {
      expect(CountdownAnnouncement.bucketFor(10), 10);
    });

    test('collapses 9 and 8 into one announcement', () {
      expect(CountdownAnnouncement.bucketFor(9), 8);
      expect(CountdownAnnouncement.bucketFor(8), 8);
    });

    test('collapses 7, 6 and 5 into one announcement', () {
      expect(CountdownAnnouncement.bucketFor(7), 5);
      expect(CountdownAnnouncement.bucketFor(6), 5);
      expect(CountdownAnnouncement.bucketFor(5), 5);
    });

    test('announces every second from 4 down to 1', () {
      expect(CountdownAnnouncement.bucketFor(4), 4);
      expect(CountdownAnnouncement.bucketFor(3), 3);
      expect(CountdownAnnouncement.bucketFor(2), 2);
      expect(CountdownAnnouncement.bucketFor(1), 1);
    });

    test('goes silent at zero', () {
      expect(CountdownAnnouncement.bucketFor(0), isNull);
      expect(CountdownAnnouncement.bucketFor(-1), isNull);
    });

    test('clamps values above the countdown length', () {
      expect(CountdownAnnouncement.bucketFor(30), 10);
    });

    test('produces at most one label change per bucket boundary', () {
      final labels = [
        for (var s = 10; s >= 0; s--) CountdownAnnouncement.bucketFor(s),
      ];
      final changes = <int?>[];
      for (final label in labels) {
        if (changes.isEmpty || changes.last != label) changes.add(label);
      }

      // 10, 8, 5, 4, 3, 2, 1, null -> eight announcements over ten seconds.
      expect(changes, [10, 8, 5, 4, 3, 2, 1, null]);
    });
  });
}
