package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.os.SystemClock

/**
 * The device's monotonic clock, for Dart, which has none that survives its
 * own process (audit Y-05, 2026-10-08).
 *
 * The PIN lockout stored a wall-clock deadline: on an API 35 emulator moving
 * the clock forward one hour ended an 86 s lockout at once, and moving it back
 * two hours locked the owner out for 7431 s. elapsedRealtime cannot be set by
 * the user and counts deep sleep; [bootCount] tells Dart whether a stored
 * elapsed deadline belongs to this boot at all.
 */
object MonotonicClockSnapshot {
    fun of(
        context: Context,
        elapsedRealtimeMs: () -> Long = { SystemClock.elapsedRealtime() },
    ): Map<String, Any> = mapOf(
        "elapsedRealtimeMs" to elapsedRealtimeMs(),
        "bootCount" to BootIdentity.current(context),
    )
}
