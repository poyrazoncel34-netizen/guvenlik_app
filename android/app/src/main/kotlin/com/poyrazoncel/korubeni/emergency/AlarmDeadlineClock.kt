package com.poyrazoncel.korubeni.emergency

import android.os.SystemClock

/**
 * Bridges wall-clock AlarmManager deadlines and monotonic timer semantics.
 *
 * RTC_WAKEUP requires epoch milliseconds, but a user changing the wall clock
 * must not shorten or lengthen an already-running safety timer. The matching
 * elapsed-realtime deadline is therefore persisted for the current boot and is
 * used to rebase RTC alarms after TIME_SET/TIMEZONE_CHANGED. After reboot,
 * elapsedRealtime resets and boot restoration intentionally rebuilds it from
 * the persisted wall deadline.
 */
object AlarmDeadlineClock {
    fun elapsedDeadlineFromWall(
        wallDeadlineMs: Long,
        nowWallMs: Long = System.currentTimeMillis(),
        nowElapsedMs: Long = SystemClock.elapsedRealtime(),
    ): Long {
        val remaining = positiveDifference(wallDeadlineMs, nowWallMs)
        return saturatingAdd(nowElapsedMs, remaining)
    }

    fun wallDeadlineFromElapsed(
        elapsedDeadlineMs: Long,
        nowElapsedMs: Long = SystemClock.elapsedRealtime(),
        nowWallMs: Long = System.currentTimeMillis(),
    ): Long {
        val remaining = positiveDifference(elapsedDeadlineMs, nowElapsedMs)
        return saturatingAdd(nowWallMs, remaining)
    }

    fun remainingMs(
        elapsedDeadlineMs: Long,
        nowElapsedMs: Long = SystemClock.elapsedRealtime(),
    ): Long = positiveDifference(elapsedDeadlineMs, nowElapsedMs)

    private fun positiveDifference(later: Long, earlier: Long): Long {
        if (later <= earlier) return 0L
        return if (earlier < 0L && later > Long.MAX_VALUE + earlier) {
            Long.MAX_VALUE
        } else {
            later - earlier
        }
    }

    private fun saturatingAdd(left: Long, right: Long): Long {
        if (right <= 0L) return left
        return if (left > Long.MAX_VALUE - right) Long.MAX_VALUE else left + right
    }
}
