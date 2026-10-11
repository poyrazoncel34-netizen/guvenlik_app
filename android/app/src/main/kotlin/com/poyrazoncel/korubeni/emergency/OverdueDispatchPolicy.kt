package com.poyrazoncel.korubeni.emergency

/**
 * THE one place that decides whether a safety deadline may still be dialled
 * automatically, and on which clock that is judged (owner decision OD-1,
 * 2026-10-10).
 *
 * Before this existed the same rule was written out at four call sites and
 * missing from a fifth, so one Android component called the contact while
 * another offered a manual action for the identical record:
 *
 *  - `reconcileArmedFromWall` and reconcile's CLAIMED branch capped the age at
 *    [MAX_OVERDUE_DISPATCH_MS], read off the WALL clock.
 *  - `reconcileAfterClockChange` capped it on the MONOTONIC clock.
 *  - `claimAndDispatch` -- the single funnel for CountdownAlarmReceiver,
 *    CheckInAlarmReceiver and the Dart `dispatchEmergencySession` channel --
 *    had no cap at all, so a late AlarmManager delivery placed an automatic
 *    emergency call hours after the deadline (audit A-001's own defect, left
 *    open on the path that fires most often).
 *
 * ## The age boundary
 *
 * `overdueMs` is `now - finalDeadline` on the authoritative clock.
 *
 * | overdueMs                    | verdict       |
 * |------------------------------|---------------|
 * | `< 0`                        | [Verdict.NOT_DUE] |
 * | `0 .. MAX_OVERDUE_DISPATCH_MS` inclusive | [Verdict.DISPATCH] |
 * | `> MAX_OVERDUE_DISPATCH_MS`  | [Verdict.OFFER_MANUAL] |
 *
 * So exactly 5:00.000 late still dials and 5:00.001 does not. The inclusive
 * edge is deliberate and matches the `>` comparisons this replaced, so moving
 * the rule into one place did not silently shift the boundary by a millisecond.
 *
 * The limit itself is a product decision, not a technical one. A short
 * interruption -- a reboot, a brief power-off, a Doze-delayed alarm -- stays on
 * the automatic path, while the "days later" surprise call ends entirely. Both
 * errors are real: an unwanted outgoing call cannot be taken back, and a missed
 * call in a live emergency is worse. 5 minutes is where the owner drew it.
 *
 * ## Which clock is the authority
 *
 * Inside one boot, NOT the wall clock. Safety alarms are scheduled on
 * `ELAPSED_REALTIME_WAKEUP` (AndroidEmergencySessionAlarmScheduler), which
 * counts sleep and which the user cannot move, so the interval the app promised
 * is a monotonic interval. Judging its age on a clock the user can change
 * produced two measured defects, in opposite directions:
 *
 *  - wall moved FORWARD two hours while the app was stopped (so no TIME_SET was
 *    ever delivered): a Check-In with 118 s genuinely left was declared more
 *    than 5 minutes overdue and terminated as MANUAL_ACTION_REQUIRED.
 *  - wall moved BACK one hour: the elapsed alarm fired exactly on time and the
 *    wall gate refused it, then every reconcile rescheduled the same already-
 *    past elapsed deadline and refused again -- 0 calls placed, session stuck
 *    ARMED, for as long as the clock was set back.
 *
 * Monotonic evidence only exists while the record's elapsed stamp belongs to
 * the CURRENT boot; elapsedRealtime restarts at zero, so across a reboot the
 * persisted wall deadline is the only reference there is, and it is used. That
 * is why [decide] takes `monotonicOverdueMs` as nullable rather than guessing.
 */
object OverdueDispatchPolicy {
    /** How late an automatic emergency call may still be placed. */
    const val MAX_OVERDUE_DISPATCH_MS = 5L * 60L * 1_000L

    enum class Verdict {
        /** The deadline has not arrived on the authoritative clock. */
        NOT_DUE,

        /** Due, and fresh enough to call the primary contact automatically. */
        DISPATCH,

        /**
         * Due, but too old to call on the user's behalf. The existing
         * MANUAL_ACTION_REQUIRED + fallback notification path offers the call
         * instead; nothing new is invented for this state.
         */
        OFFER_MANUAL,
    }

    /**
     * Which clock [Decision.overdueMs] was measured on.
     *
     * Consumed by the tests, which assert the monotonic clock wins whenever it
     * has an opinion. NOT written to any log: an earlier comment here said
     * "for logging" and nothing logged it (security review F6). Stated plainly
     * rather than left as an aspiration, so nobody hunts for a log that does
     * not exist.
     */
    enum class ClockAuthority { MONOTONIC, WALL }

    data class Decision(
        val verdict: Verdict,
        val authority: ClockAuthority,
        val overdueMs: Long,
    )

    /**
     * @param wallOverdueMs `System.currentTimeMillis() - finalDeadlineMs`.
     * @param monotonicOverdueMs `elapsedRealtime() - elapsedRealtimeDeadlineMs`,
     *   or null when this record carries no elapsed stamp from the current boot
     *   and the monotonic clock therefore says nothing about it.
     */
    fun decide(wallOverdueMs: Long, monotonicOverdueMs: Long?): Decision {
        val authority =
            if (monotonicOverdueMs == null) ClockAuthority.WALL else ClockAuthority.MONOTONIC
        val overdueMs = monotonicOverdueMs ?: wallOverdueMs
        val verdict = when {
            overdueMs < 0L -> Verdict.NOT_DUE
            overdueMs <= MAX_OVERDUE_DISPATCH_MS -> Verdict.DISPATCH
            else -> Verdict.OFFER_MANUAL
        }
        return Decision(verdict, authority, overdueMs)
    }
}
