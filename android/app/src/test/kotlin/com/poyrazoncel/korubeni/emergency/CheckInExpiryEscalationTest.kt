package com.poyrazoncel.korubeni.emergency

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

/**
 * M2 - Native-backup escalation for the check-in / safe-walk dead-man's-switch.
 *
 * SPEC 3.2 + 3.5: when the grace alarm fires (Dart isolate possibly dead under
 * Doze/app-kill), the receiver must call ONLY the persisted primary number
 * natively, mark a dedup flag, and never call 112 / never run a failover list.
 *
 * Literal pref-key strings are used on purpose so this suite compiles and fails
 * at RUNTIME against the un-implemented receiver (genuine RED), without any
 * production change.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class CheckInExpiryEscalationTest {

    private val context = RuntimeEnvironment.getApplication()
    private val shadowApp get() = Shadows.shadowOf(RuntimeEnvironment.getApplication())

    // Mirrors CheckInScheduler.keyFor(SESSION_CHECK_IN, base) == base.
    private val keyPrimary = "check_in_primary_number"
    private val keyFired = "check_in_alarm_fired"

    @Before
    fun setUp() {
        ShadowLog.setupLogging()
        EmergencyPrefs.prefs(context).edit().clear().commit()
    }

    private fun armGraceExpiry(primary: String?, active: Boolean = true) {
        val editor = EmergencyPrefs.prefs(context).edit()
            .putBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, active)
            .putString(EmergencyPrefs.KEY_CHECK_IN_PHASE, CheckInScheduler.PHASE_GRACE)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_GRACE_MS, 0L)
        if (primary != null) editor.putString(keyPrimary, primary)
        editor.commit()
    }

    private fun fireReceiver() {
        val intent = Intent(context, CheckInAlarmReceiver::class.java)
            .putExtra("sessionId", CheckInScheduler.SESSION_CHECK_IN)
        CheckInAlarmReceiver().onReceive(context, intent)
        Thread.sleep(300)
    }

    @Test
    fun graceExpiryActiveSessionCallsPrimaryNumber() {
        armGraceExpiry("+905001234567")
        fireReceiver()
        val started = shadowApp.nextStartedActivity
        assertNotNull("Native backup must dispatch a call on grace expiry", started)
        assertTrue(
            "Must dial the configured primary number",
            started!!.dataString!!.contains("905001234567"),
        )
    }

    @Test
    fun graceExpiryMarksNativeFiredDedupFlag() {
        armGraceExpiry("+905001234567")
        fireReceiver()
        assertTrue(
            "Native escalation must set the check-in alarm-fired dedup flag",
            EmergencyPrefs.prefs(context).getBoolean(keyFired, false),
        )
    }

    @Test
    fun graceExpiryWithoutCallPhoneUsesDialToPrimaryNot112() {
        // Robolectric grants no permissions -> CALL_PHONE denied.
        armGraceExpiry("+905001234567")
        fireReceiver()
        val started = shadowApp.nextStartedActivity
        assertNotNull(started)
        assertEquals(Intent.ACTION_DIAL, started!!.action)
        assertEquals(
            "Check-in escalation must NEVER fall back to 112",
            false,
            started.dataString == "tel:112",
        )
        assertTrue(started.dataString!!.contains("905001234567"))
    }

    @Test
    fun graceExpiryWithBlankPrimaryDoesNotCallOrCrash() {
        // Requirement (b): edge-case of the no-112 decision.
        armGraceExpiry("")
        fireReceiver() // must not throw
        assertNull(
            "Blank primary number must NOT trigger any call (no synthetic 112)",
            shadowApp.nextStartedActivity,
        )
    }

    @Test
    fun graceExpiryWhenInactiveDoesNotCall() {
        // Cancel-after-confirm guard: KEY_CHECK_IN_ACTIVE == false rejects the call.
        armGraceExpiry("+905001234567", active = false)
        fireReceiver()
        assertNull(
            "Inactive (cancelled) session must reject the native call",
            shadowApp.nextStartedActivity,
        )
    }

    @Test
    fun bootRestoreOfExpiredSessionEscalatesNatively() {
        val now = System.currentTimeMillis()
        EmergencyPrefs.prefs(context).edit()
            .putBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, true)
            .putString(EmergencyPrefs.KEY_CHECK_IN_PHASE, CheckInScheduler.PHASE_GRACE)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_DEADLINE, now - 1_000L)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_GRACE_MS, 0L)
            .putString(keyPrimary, "+905001234567")
            .commit()

        CheckInScheduler.restoreAfterBoot(context)
        Thread.sleep(300)

        val started = shadowApp.nextStartedActivity
        assertNotNull("Boot-restore expired path must call, not just notify", started)
        assertTrue(started!!.dataString!!.contains("905001234567"))
        assertTrue(EmergencyPrefs.prefs(context).getBoolean(keyFired, false))
    }
}
