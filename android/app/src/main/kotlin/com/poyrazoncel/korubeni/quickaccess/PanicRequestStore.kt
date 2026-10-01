package com.poyrazoncel.korubeni.quickaccess

import android.content.Context
import android.os.SystemClock
import com.poyrazoncel.korubeni.emergency.EmergencyPrefs

/**
 * Durable hand-off for a panic request that arrived from a quick-access surface
 * (home-screen widget, Quick Settings tile) before Flutter was attached.
 *
 * Deliberately NOT EmergencyPrefs.KEY_PENDING_TRIGGER: that key holds at most
 * one payload, and the alarm receivers write it when the event sink is detached.
 * Sharing it would let a widget tap overwrite a pending `checkInExpired` -- an
 * event that means native has ALREADY dispatched -- leaving the Dart projection
 * claiming a session was still running. Two independent producers get two keys.
 *
 * This store carries intent only. It never arms a session, never dials, and
 * never touches a contact: the request is replayed into the one existing arm
 * path (SubscriptionGate -> CountdownScreen -> PanicArmPolicy).
 *
 * ## Why the request expires
 *
 * The request used to be stored with no notion of when it was made. If Flutter
 * could not start -- process killed, OEM task killer, device powered off -- the
 * record simply waited. The user then opened the app normally DAYS later and
 * landed straight in a real countdown they had long stopped expecting. That is
 * a reliability defect, not an attack: the trampoline is not exported, so no
 * foreign app can plant a request. What it produces is an unwanted emergency
 * call, which this project treats as a real cost.
 *
 * So a submit stamps a monotonic timestamp and a consume outside the window
 * discards the request.
 */
object PanicRequestStore {
    private const val KEY_PENDING = "quick_panic_pending_source"

    /**
     * When the pending request was recorded, on the monotonic clock.
     *
     * NOT `System.currentTimeMillis()`. A wall clock is user-settable, so a
     * stale request could be made to look fresh simply by moving the device
     * clock. `SystemClock.elapsedRealtime()` cannot be set, and it counts
     * through sleep -- which matters here, because the whole scenario is a
     * device that was asleep or off between the press and the next launch.
     */
    private const val KEY_REQUESTED_AT = "quick_panic_requested_elapsed_ms"

    /** Quick-access surfaces that may submit a request. */
    const val SOURCE_WIDGET = "widget"
    const val SOURCE_TILE = "tile"

    /**
     * How long a recorded press may wait for Flutter before it stops counting.
     *
     * Three minutes is chosen against the only thing that legitimately delays a
     * replay: a cold start, including permission prompts and the PIN gate. It is
     * generous for that and still closes the "pressed days ago" case. Shorter
     * risks discarding a real press on a slow device, and in this app a lost
     * panic press is the more expensive of the two mistakes.
     */
    const val FRESHNESS_WINDOW_MS = 3L * 60L * 1000L

    /**
     * Records a pending request.
     *
     * Uses commit() rather than apply(): the process is about to start an
     * Activity and may be killed before an async write lands, which would drop
     * the user's panic press silently. Both values go in ONE edit, so a reader
     * can never see a source without its timestamp.
     *
     * [now] is injectable so the expiry rule is testable without waiting on a
     * real clock; it follows the same pattern as EmergencySessionCoordinator.
     */
    fun submit(
        context: Context,
        source: String,
        now: Long = SystemClock.elapsedRealtime(),
    ) {
        EmergencyPrefs.prefs(context)
            .edit()
            .putString(KEY_PENDING, source)
            .putLong(KEY_REQUESTED_AT, now)
            .commit()
    }

    /**
     * Returns the pending source and clears it, so one press produces at most
     * one countdown even if Flutter asks twice (init plus resume).
     *
     * Clearing happens BEFORE the freshness decision and regardless of its
     * outcome. A request that is too old must not survive to be re-evaluated on
     * the next resume, and a half-cleared record would be worse than either
     * answer.
     *
     * A missing or unreadable timestamp reads as "not fresh". Unknown age is not
     * evidence of youth, and this store writes both values together, so the only
     * way to see one without the other is a record from a build that predates
     * the window -- which by definition is old.
     */
    fun consume(
        context: Context,
        now: Long = SystemClock.elapsedRealtime(),
    ): String? {
        val prefs = EmergencyPrefs.prefs(context)
        val source = prefs.getString(KEY_PENDING, null)
        val requestedAt = if (prefs.contains(KEY_REQUESTED_AT)) {
            runCatching { prefs.getLong(KEY_REQUESTED_AT, -1L) }.getOrDefault(-1L)
        } else {
            -1L
        }
        if (source == null && requestedAt < 0L) return null
        prefs.edit().remove(KEY_PENDING).remove(KEY_REQUESTED_AT).commit()
        if (source == null || requestedAt < 0L) return null
        return source.takeIf { isFresh(requestedAt, now) }
    }

    /**
     * True while the press is still recent.
     *
     * The lower bound is not redundant. `elapsedRealtime()` restarts at zero on
     * reboot, so a request recorded before a restart leaves a stamp that is
     * LARGER than the current reading and the age comes out negative. Treating
     * that as fresh would reintroduce exactly the case this window exists to
     * close -- a press that survived a power cycle is old by definition.
     */
    private fun isFresh(requestedAt: Long, now: Long): Boolean {
        val age = now - requestedAt
        return age in 0L..FRESHNESS_WINDOW_MS
    }
}
