package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class CheckInSchedulerTest {

    private val context = RuntimeEnvironment.getApplication()

    @Before
    fun setUp() {
        EmergencyPrefs.prefs(context).edit().clear().commit()
    }

    @Test
    fun `restoreAfterBoot treats type-corrupt deadline as corrupted state`() {
        val prefs = EmergencyPrefs.prefs(context)
        prefs.edit()
            .putBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, true)
            .putString(EmergencyPrefs.KEY_CHECK_IN_DEADLINE, "not-a-long")
            .commit()

        CheckInScheduler.restoreAfterBoot(context)

        val pending = EmergencyEventBus.consumePendingTrigger(context)
        assertNotNull("Corrupt boot restore must persist a recovery event", pending)
        assertEquals("checkInCorrupted", pending!!["type"])
        assertFalse(
            "Corrupt check-in state must be cleared after recovery",
            prefs.getBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, false),
        )
    }

    @Test
    fun `hasActiveSession does not throw when active flag has wrong type`() {
        EmergencyPrefs.prefs(context).edit()
            .putString(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, "true")
            .commit()

        assertFalse(CheckInScheduler.hasActiveSession(context))
    }
}
