# Native pre-expiry warning (Check-In / Safe Walk) — design, NOT IMPLEMENTED

**Status:** `SPECIFIED / NOT_BUILT`. This document exists so the gap is a scoped
piece of work rather than an undocumented hole.

## The gap

When a Check-In or Safe Walk session reaches its main deadline while Flutter is
alive, the Dart ticker shows the grace warning. When the process is dead, no
warning is produced at all: `AndroidEmergencySessionAlarmScheduler.schedule`
(`android/app/src/main/kotlin/.../AndroidEmergencySessionRuntime.kt:181`)
registers exactly one alarm, at `elapsedRealtimeDeadlineMs` — the FINAL
deadline — and `claimAndDispatch` refuses to act before `finalDeadlineMs`
(`EmergencySessionCoordinator.kt:244`). `mainDeadlineMs` is used only by Dart.

`NativeNotificationText.checkInGraceStarted` / `checkInExpired` copy exists and
has zero callers (verified by grep over `android/app/src/main`).

User-visible consequence: the app is killed, the grace window passes in
silence, and the phone then places a call to the emergency contact with no
prior signal the user could have acted on.

## Why it was not implemented in the hardening pass

The change lands in the one place with the strongest existing evidence:
`EmergencySessionCoordinatorTest.kt` holds 90 tests including three
1,000-iteration interleaving families (cancel-vs-receiver, Dart-vs-exact-vs-
inexact, generation races). Adding a second alarm adds new interleavings —
grace-vs-cancel, grace-vs-dispatch, grace-after-reboot, grace with a stale
generation — and shipping alarm-scheduling code into the dispatch path without
companion evidence at that standard would trade a missing notification for a
risk to the call itself. That is the wrong trade for this app.

## Specification

1. **Scope:** `SessionSlot.LONG_RUNNING` only, and only when
   `mainDeadlineMs < finalDeadlineMs`. Panic has no grace window.
2. **Scheduling:** a second `setExactAndAllowWhileIdle` (falling back to
   `setAndAllowWhileIdle`) at `mainDeadline`, with a PendingIntent request code
   distinct from the dispatch alarm and derived from the same
   `SessionToken` (kind + randomId + generation).
3. **Receiver:** read-only with respect to the state machine. It may ONLY read
   the envelope and post `NativeNotificationText.checkInGraceStarted`. It must
   never write the envelope, never claim, never dispatch. This keeps the new
   failure mode "a notification that should not have appeared" rather than "a
   call that should not have happened".
4. **Preconditions before posting:** envelope present, `lifecycleState == ARMED`,
   token generation matches, `now >= mainDeadline`, `now < finalDeadline`.
   Any mismatch: post nothing.
5. **Cancellation:** the grace alarm is cancelled everywhere the dispatch alarm
   is (`cancel`, `wipe`, terminal commit, reboot reconciliation), and the
   posted notification is cleared when the session reaches any terminal state.
6. **Reboot:** `reconcileAfterBoot` rebases both alarms onto the new
   `elapsedRealtime` base. A main deadline already in the past does not fire a
   retroactive warning; only a future one is rescheduled.

## Required evidence before this ships

- Kotlin unit tests for each precondition in (4) and each cancellation path
  in (5).
- A 1,000-iteration interleaving family for grace-vs-cancel and
  grace-vs-dispatch, matching the existing three.
- A reboot test asserting both alarms are rebased and that a past main deadline
  produces no warning.
- Emulator instrumentation confirming the notification appears with the app
  process killed (`adb shell am kill`), on at least API 29 and the current
  target API.
- The device matrix row is not closed by emulator evidence alone.
