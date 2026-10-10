package com.poyrazoncel.korubeni.emergency

import java.util.concurrent.atomic.AtomicBoolean

/**
 * Runs the same-boot safety reconcile once per process, at the first UI start.
 *
 * Force-stop deletes every alarm of the package while an armed Check-In or
 * Safe Walk record stays ARMED. Android 15+ re-delivers BOOT_COMPLETED to a
 * force-stopped app when it next starts, and [BootCompletedReceiver]
 * reconciles; API 29-34 does not, so reopening the app restored no alarm and
 * nothing would fire once it was closed again (closure audit 2026-10-10, API
 * 29 emulator). The reconcile is idempotent: an ARMED record is re-scheduled
 * for its same deadline, a due one follows the reboot policy, and a dispatch
 * already in flight in this process is deduplicated by the coordinator.
 */
object ProcessStartReconcile {
    private val ran = AtomicBoolean(false)

    fun once(reconcile: () -> Unit) {
        if (ran.compareAndSet(false, true)) reconcile()
    }

    /** A fresh process, for tests only. */
    internal fun resetForTest() = ran.set(false)
}
