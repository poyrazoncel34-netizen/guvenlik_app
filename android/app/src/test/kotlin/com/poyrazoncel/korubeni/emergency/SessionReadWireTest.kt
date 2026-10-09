package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Test

/** Y-14: every session read tells Dart whether exact alarms are allowed now. */
class SessionReadWireTest {
    private val armed = ReadSessionResult.Present(
        EmergencySessionEnvelope(
            token = SessionToken(EMERGENCY_PROTOCOL_VERSION, "wire-test-1", 1L, SessionKind.CHECK_IN),
            lifecycleState = LifecycleState.ARMED,
            target = "+905001234567",
            mainDeadlineMs = 1_000L,
            finalDeadlineMs = 2_000L,
            elapsedRealtimeDeadlineMs = 2_000L,
            schedulingMode = SchedulingMode.EXACT_AND_INEXACT,
        ),
    )

    @Test
    fun `a read carries the live exact-alarm permission`() {
        val absent = SessionReadWire.of(ReadSessionResult.Absent) { false }
        assertEquals("absent", absent["type"])
        assertEquals(false, absent["exactAlarmPermitted"])

        val corrupted = SessionReadWire.of(ReadSessionResult.Corrupted("x")) { true }
        assertEquals("corrupted", corrupted["type"])
        assertEquals(true, corrupted["exactAlarmPermitted"])
    }

    // The one case Dart acts on: an ARMED session whose exact alarms Android
    // deleted must reach Dart as not permitted, next to the session itself.
    @Test
    fun `an armed session read carries the flag beside the session`() {
        val revoked = SessionReadWire.of(armed) { false }
        assertEquals("present", revoked["type"])
        assertEquals(false, revoked["exactAlarmPermitted"])
        assertEquals("armed", (revoked["session"] as Map<*, *>)["lifecycleState"])

        assertEquals(true, SessionReadWire.of(armed) { true }["exactAlarmPermitted"])
    }

    // A failing permission query (e.g. a system_server restart) must not fail
    // the whole read, and must err toward "degraded", never toward "protected".
    @Test
    fun `a permission query that throws reads as not permitted`() {
        val read = SessionReadWire.of(armed) { throw IllegalStateException("binder died") }
        assertEquals("present", read["type"])
        assertEquals(false, read["exactAlarmPermitted"])
    }
}
