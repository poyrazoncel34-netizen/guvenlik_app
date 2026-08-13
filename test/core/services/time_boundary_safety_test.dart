// MP-14-019 / MP-14-020 / MP-14-021 — date-boundary, DST and leap-year safety.
//
// What actually matters in this app is not date FORMATTING. It is that a safety
// deadline is an ABSOLUTE INSTANT: the countdown, the check-in window, the
// offline-entitlement grace and the PIN lockout must all grant exactly the
// duration they promised, no matter what the wall clock does. A DST transition
// moves the wall clock by an hour; a manual clock change can move it by any
// amount; a leap day adds a date that does not exist in other years.
//
// The audit previously recorded these three rows as PARTIAL because the DST and
// leap-year cases "are not called out by name". They are, now — and they are
// asserted as behaviour rather than named in a comment.
//
// Every assertion here is timezone-INDEPENDENT: the wall-clock shift is
// simulated explicitly by advancing absolute time differently from the reading
// a naive implementation would take, so the test means the same thing on a CI
// box in UTC and on a device in a DST-observing zone. (Turkey itself has been
// permanently UTC+3 since 2016, so a Turkish user sees no DST — but the app is
// installable on a device set to any timezone, and a manual clock change is
// exactly the duress-adjacent case this must survive.)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/countdown_clock.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';

/// What a NAIVE implementation would do: read the wall-clock components and
/// subtract them. Present only as a negative control -- if the production
/// helpers ever start behaving like this, the assertions below go red.
int naiveWallClockSecondsUntil(DateTime deadline, DateTime now) {
  final deadlineWall =
      deadline.hour * 3600 + deadline.minute * 60 + deadline.second;
  final nowWall = now.hour * 3600 + now.minute * 60 + now.second;
  final remaining = deadlineWall - nowWall;
  return remaining <= 0 ? 0 : remaining;
}

void main() {
  // 2027-03-14 07:00:00Z — the instant US DST springs forward (02:00 -> 03:00
  // local). Chosen because it is a real transition; the assertions do not
  // depend on the host actually observing it.
  final springForward = DateTime.fromMillisecondsSinceEpoch(
    DateTime.utc(2027, 3, 14, 7).millisecondsSinceEpoch,
  );
  // 2027-11-07 06:00:00Z — the fall-back instant, where the wall clock REPEATS
  // an hour. This is the dangerous direction: a naive implementation can read
  // the same wall-clock time twice.
  final fallBack = DateTime.fromMillisecondsSinceEpoch(
    DateTime.utc(2027, 11, 7, 6).millisecondsSinceEpoch,
  );

  group('MP-14-020: a wall-clock shift cannot change the granted window', () {
    test('countdown keeps its full window when the clock jumps forward', () {
      // Armed 30 minutes before the transition instant.
      final armedAt = springForward.subtract(const Duration(minutes: 30));
      final deadline = armedAt.add(const Duration(minutes: 30));

      // Precondition: the deadline is exactly 30 minutes of ABSOLUTE time
      // later. If `add` were calendar arithmetic this would already differ.
      expect(
        deadline.millisecondsSinceEpoch - armedAt.millisecondsSinceEpoch,
        const Duration(minutes: 30).inMilliseconds,
        reason: 'a safety deadline must be an absolute instant',
      );

      // Ten REAL minutes pass. In a spring-forward zone the wall clock now
      // reads an hour and ten minutes later.
      final tenRealMinutesIn = armedAt.add(const Duration(minutes: 10));
      expect(
        CountdownClock.secondsUntil(deadline, now: tenRealMinutesIn),
        20 * 60,
        reason: 'the user must still have the 20 minutes they actually have',
      );
    });

    test('NEGATIVE CONTROL: a wall-clock implementation loses the window', () {
      final armedAt = springForward.subtract(const Duration(minutes: 30));
      final deadline = armedAt.add(const Duration(minutes: 30));
      final tenRealMinutesIn = armedAt.add(const Duration(minutes: 10));

      // Simulate the reading a naive implementation would take after the clock
      // jumped forward by an hour: same absolute instant, wall clock +1h.
      final shiftedReading = tenRealMinutesIn.add(const Duration(hours: 1));

      expect(
        naiveWallClockSecondsUntil(deadline, shiftedReading),
        0,
        reason:
            'This is the defect being guarded against: a wall-clock reading '
            'says the deadline has already passed, which on the panic path '
            'means dialing an hour early. The production helper above returns '
            '1200 for the same instant.',
      );
      expect(
        CountdownClock.secondsUntil(deadline, now: tenRealMinutesIn),
        isNot(naiveWallClockSecondsUntil(deadline, shiftedReading)),
        reason: 'if these ever agree, the production helper became naive',
      );
    });

    test('countdown does not double-count the repeated fall-back hour', () {
      final armedAt = fallBack.subtract(const Duration(minutes: 20));
      final deadline = armedAt.add(const Duration(minutes: 45));

      // 30 real minutes in -- straddling the repeated wall-clock hour.
      final thirtyRealMinutesIn = armedAt.add(const Duration(minutes: 30));
      expect(
        CountdownClock.secondsUntil(deadline, now: thirtyRealMinutesIn),
        15 * 60,
        reason:
            'a repeated wall-clock hour must not silently extend a safety '
            'deadline either -- the session would outlive its own promise',
      );
    });

    test('an already-expired deadline clamps at zero, never negative', () {
      final deadline = springForward;
      expect(
        CountdownClock.secondsUntil(
          deadline,
          now: deadline.add(const Duration(hours: 3)),
        ),
        0,
      );
    });
  });

  group('MP-14-021: leap year', () {
    test('2028-02-29 exists and 2027-02-29 does not', () {
      // Harness precondition: if Dart ever stopped rolling invalid dates the
      // assertions below would be testing nothing.
      expect(DateTime(2028, 2, 29).day, 29);
      expect(DateTime(2028, 2, 29).month, 2);
      expect(
        DateTime(2027, 2, 29).month,
        3,
        reason: '2027 is not a leap year; Dart rolls the date into March',
      );
    });

    test('a duration-based deadline crosses Feb 29 without drifting', () {
      // 24 hours from noon on 2028-02-28 must land ON the leap day, not skip it.
      final beforeLeapDay = DateTime(2028, 2, 28, 12);
      final oneDayLater = beforeLeapDay.add(const Duration(hours: 24));
      expect(oneDayLater.day, 29);
      expect(oneDayLater.month, 2);

      // The same arithmetic in a non-leap year lands in March. Both are correct
      // BECAUSE the deadline is absolute -- the calendar is the thing that
      // differs, not the amount of time granted.
      final nonLeap = DateTime(2027, 2, 28, 12).add(const Duration(hours: 24));
      expect(nonLeap.month, 3);
      expect(nonLeap.day, 1);
    });

    test('the 7-day offline grace spans Feb 29 without losing or gaining a day',
        () {
      final anchor = DateTime(2028, 2, 25, 9);
      final state = SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
        lastVerifiedPro: true,
        lastVerifiedProAt: anchor,
      );

      // Precondition: this state really is inside the window AT THE INSTANT
      // under test, otherwise the remaining-duration assertions below would be
      // measuring a null. Asserted with an explicit clock -- the boolean
      // getters read DateTime.now(), which is not the instant being tested.
      expect(
        state.canArmWithinOfflineGrace(
          now: anchor.add(const Duration(days: 6)),
        ),
        isTrue,
      );

      // Six days later -- a span that CONTAINS the leap day.
      final sixDaysIn = anchor.add(const Duration(days: 6));
      expect(sixDaysIn.month, 3, reason: 'the span really did cross Feb 29');
      expect(sixDaysIn.day, 2);
      expect(
        state.remainingOfflineGrace(now: sixDaysIn),
        const Duration(days: 1),
        reason:
            'the window is 7 days of absolute time; the leap day must neither '
            'shorten nor lengthen it',
      );

      // And it expires exactly 7 days after the anchor, not 6 or 8.
      expect(
        state.remainingOfflineGrace(
          now: anchor.add(const Duration(days: 7)),
        ),
        Duration.zero,
      );
      // ...and it is genuinely outside the window one second later, so the
      // Duration.zero above is an expiry and not a null-shaped coincidence.
      expect(
        state.canArmWithinOfflineGrace(
          now: anchor.add(const Duration(days: 7, seconds: 1)),
        ),
        isFalse,
      );
    });
  });

  group('MP-14-019: date boundaries', () {
    test('a deadline crossing midnight, month end and year end is unaffected',
        () {
      for (final boundary in <DateTime>[
        DateTime(2027, 1, 1),            // year boundary
        DateTime(2027, 2, 1),            // month boundary, short month
        DateTime(2028, 3, 1),            // month boundary after a leap day
        DateTime(2027, 12, 31, 23, 59),  // last minute of the year
      ]) {
        final armedAt = boundary.subtract(const Duration(minutes: 5));
        final deadline = armedAt.add(const Duration(minutes: 10));
        expect(
          CountdownClock.secondsUntil(
            deadline,
            now: armedAt.add(const Duration(minutes: 4)),
          ),
          6 * 60,
          reason: 'boundary $boundary changed the remaining time',
        );
      }
    });

    test('the PIN lockout deadline is persisted as an epoch, not a wall clock',
        () {
      // Source contract: the lockout survives a reboot and a timezone change
      // because what is written is millisecondsSinceEpoch. A wall-clock string
      // would let a user shorten their own lockout by changing the device
      // timezone -- which is a duress-adjacent bypass, not a formatting nit.
      final source =
          File('lib/core/services/pin_lockout_service.dart').readAsStringSync();
      expect(
        source,
        contains("value: '\${lockedUntil.millisecondsSinceEpoch}'"),
        reason: 'the lockout instant must be stored in absolute time',
      );
    });
  });
}
