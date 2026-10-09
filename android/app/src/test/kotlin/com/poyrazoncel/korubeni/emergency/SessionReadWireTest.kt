package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Test

/** Y-14: every session read tells Dart whether exact alarms are allowed now. */
class SessionReadWireTest {
    @Test
    fun `a read carries the live exact-alarm permission`() {
        val absent = SessionReadWire.of(ReadSessionResult.Absent, exactAlarmPermitted = false)
        assertEquals("absent", absent["type"])
        assertEquals(false, absent["exactAlarmPermitted"])

        val corrupted = SessionReadWire.of(ReadSessionResult.Corrupted("x"), exactAlarmPermitted = true)
        assertEquals("corrupted", corrupted["type"])
        assertEquals(true, corrupted["exactAlarmPermitted"])
    }
}
