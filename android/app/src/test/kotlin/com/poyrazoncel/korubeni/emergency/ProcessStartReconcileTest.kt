package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Closure audit 2026-10-10, API 29 emulator: a force-stop deleted an armed
 * Check-In's alarms (4 -> 0 pending) and reopening the app restored none; the
 * session still read ARMED with nothing left to fire once the app was closed.
 * Android 15+ re-delivers BOOT_COMPLETED to a force-stopped app when it starts
 * again; API 29-34 does not, so the app reconciles once per process itself.
 */
class ProcessStartReconcileTest {
    @Before
    fun freshProcess() = ProcessStartReconcile.resetForTest()

    @Test
    fun `the first UI start of a process reconciles`() {
        var runs = 0
        ProcessStartReconcile.once { runs++ }
        assertEquals(1, runs)
    }

    @Test
    fun `later starts in the same process do not reconcile again`() {
        var runs = 0
        repeat(3) { ProcessStartReconcile.once { runs++ } }
        assertEquals(1, runs)
    }
}
