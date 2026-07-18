package com.poyrazoncel.korubeni.emergency

import android.content.Intent
import android.os.SystemClock
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class AlarmClockRecoveryTest {

    private val context = RuntimeEnvironment.getApplication()

    @Before
    fun setUp() {
        EmergencyPrefs.prefs(context).edit().clear().commit()
        DeviceProtectedEmergencySessionStore(context).clearAll()
    }

    @Test
    fun `wall clock jump keeps monotonic remaining duration`() {
        val elapsedDeadline = 150_000L
        val rebased = AlarmDeadlineClock.wallDeadlineFromElapsed(
            elapsedDeadlineMs = elapsedDeadline,
            nowElapsedMs = 100_000L,
            nowWallMs = 9_000_000L,
        )

        assertEquals(9_050_000L, rebased)
    }

    @Test
    fun `elapsed deadline conversion saturates instead of overflowing`() {
        assertEquals(
            Long.MAX_VALUE,
            AlarmDeadlineClock.elapsedDeadlineFromWall(
                wallDeadlineMs = Long.MAX_VALUE,
                nowWallMs = 0L,
                nowElapsedMs = Long.MAX_VALUE - 10L,
            ),
        )
    }

    @Test
    fun `boot receiver does not restore tokenless legacy countdown`() {
        val prefs = EmergencyPrefs.prefs(context)
        prefs.edit()
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE, true)
            .putLong(EmergencyPrefs.KEY_COUNTDOWN_DEADLINE_MS, System.currentTimeMillis() + 60_000L)
            .putString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, "+905001234567")
            .putString(EmergencyPrefs.KEY_COUNTDOWN_DISPATCH_ID, "boot-countdown")
            .commit()

        BootCompletedReceiver().onReceive(
            context,
            Intent(Intent.ACTION_BOOT_COMPLETED),
        )

        assertEquals(0L, prefs.getLong(EmergencyPrefs.KEY_COUNTDOWN_ELAPSED_DEADLINE_MS, 0L))
    }

    @Test
    fun `time change receiver does not rebase tokenless legacy countdown`() {
        val prefs = EmergencyPrefs.prefs(context)
        val elapsedDeadline = SystemClock.elapsedRealtime() + 45_000L
        val legacyWallDeadline = System.currentTimeMillis() + 3_600_000L
        prefs.edit()
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE, true)
            .putLong(EmergencyPrefs.KEY_COUNTDOWN_DEADLINE_MS, legacyWallDeadline)
            .putLong(EmergencyPrefs.KEY_COUNTDOWN_ELAPSED_DEADLINE_MS, elapsedDeadline)
            .putString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, "+905001234567")
            .putString(EmergencyPrefs.KEY_COUNTDOWN_DISPATCH_ID, "clock-countdown")
            .commit()

        ClockChangeReceiver().onReceive(
            context,
            Intent(Intent.ACTION_TIME_CHANGED),
        )

        assertEquals(
            legacyWallDeadline,
            prefs.getLong(EmergencyPrefs.KEY_COUNTDOWN_DEADLINE_MS, 0L),
        )
    }

    @Test
    fun `time change receiver does not rebase tokenless legacy check-in`() {
        val prefs = EmergencyPrefs.prefs(context)
        val elapsedDeadline = SystemClock.elapsedRealtime() + 75_000L
        val legacyWallDeadline = System.currentTimeMillis() + 3_600_000L
        prefs.edit()
            .putBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, true)
            .putString(EmergencyPrefs.KEY_CHECK_IN_PHASE, "main")
            .putLong(EmergencyPrefs.KEY_CHECK_IN_DEADLINE, legacyWallDeadline)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_GRACE_MS, 60_000L)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_ELAPSED_DEADLINE_MS, elapsedDeadline)
            .putString(EmergencyPrefs.KEY_CHECK_IN_PRIMARY_NUMBER, "+905001234567")
            .commit()

        ClockChangeReceiver().onReceive(context, Intent(Intent.ACTION_TIME_CHANGED))

        assertEquals(
            legacyWallDeadline,
            prefs.getLong(EmergencyPrefs.KEY_CHECK_IN_DEADLINE, 0L),
        )
    }
}
