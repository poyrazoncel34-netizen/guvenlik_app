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
import org.robolectric.shadows.ShadowApplication
import org.robolectric.shadows.ShadowLog

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class EmergencyExecutorTest {

    private val context = RuntimeEnvironment.getApplication()
    private val shadowApp get() = Shadows.shadowOf(RuntimeEnvironment.getApplication())

    @Before
    fun setUp() {
        ShadowLog.setupLogging()
    }

    @Test
    fun `empty number must NOT start any call (no synthetic 112)`() {
        val result = EmergencyExecutor.executeEmergency(context, "")
        Thread.sleep(500)

        assertEquals("Empty target must report failure, not call 112", "failed", result["status"])
        val intent = shadowApp.nextStartedActivity
        assertNull("No call/dial intent may be started for an empty target", intent)
    }

    @Test
    fun `when dispatch fails, NO 112 fallback intent is attempted`() {
        var callCount = 0
        val throwingContext = object : android.content.ContextWrapper(context) {
            override fun startActivity(intent: Intent) {
                callCount++
                if (callCount == 1) throw android.content.ActivityNotFoundException("no telephony app")
                super.startActivity(intent)
            }
        }

        val result = EmergencyExecutor.executeEmergency(throwingContext, "+905001234567")
        Thread.sleep(500)

        assertEquals("Total dispatch failure must report failed, not call 112", "failed", result["status"])
        assertNull(
            "No 112 fallback intent may be started when primary startActivity throws",
            shadowApp.nextStartedActivity,
        )
    }

    @Test
    fun `FALLBACK_112 is never logged when startActivity throws`() {
        var callCount = 0
        val throwingContext = object : android.content.ContextWrapper(context) {
            override fun startActivity(intent: Intent) {
                callCount++
                if (callCount == 1) throw android.content.ActivityNotFoundException("no app")
                super.startActivity(intent)
            }
        }

        EmergencyExecutor.executeEmergency(throwingContext, "+905001234567")
        Thread.sleep(500)

        val logged = ShadowLog.getLogs().any { it.msg.contains("FALLBACK_112") }
        assertEquals("Executor must not log a 112 fallback any more", false, logged)
    }

    @Test
    fun `EMERGENCY_CALL_TRIGGERED is logged on every executeEmergency call`() {
        EmergencyExecutor.executeEmergency(context, "+905001234567")
        Thread.sleep(500)

        val logged = ShadowLog.getLogs().any { it.msg.contains("EMERGENCY_CALL_TRIGGERED") }
        assertTrue("EMERGENCY_CALL_TRIGGERED must be logged on every emergency dispatch", logged)
    }

    @Test
    fun `no CALL_PHONE permission uses ACTION_DIAL not ACTION_CALL`() {
        // Robolectric grants no permissions by default — CALL_PHONE is denied
        val result = EmergencyExecutor.executeEmergency(context, "+905001234567")
        Thread.sleep(500)

        val intent = shadowApp.nextStartedActivity
        assertNotNull("Intent must be started even without CALL_PHONE", intent)
        assertEquals(
            "Must fall back to ACTION_DIAL when CALL_PHONE not granted",
            Intent.ACTION_DIAL,
            intent!!.action,
        )
        assertEquals(
            "Dialer fallback must report dialerOpened — it counts as a " +
                "successful dispatch (sets the dedup flag), unlike failed",
            "dialerOpened",
            result["status"],
        )
    }

    @Test
    fun `formatted number is sanitized before dialing (audit F5)`() {
        // Older builds persisted RAW formatted numbers into native prefs;
        // the executor must strip separators at dial time (defense layer).
        EmergencyExecutor.executeEmergency(context, "(0555) 010-20-30")
        Thread.sleep(500)

        val intent = shadowApp.nextStartedActivity
        assertNotNull("Formatted-but-valid number must still dial", intent)
        assertEquals(
            "Separators must be stripped before the tel: URI is built",
            "05550102030",
            intent!!.data?.schemeSpecificPart,
        )
    }

    @Test
    fun `separator-only input places no call and reports failed (audit F5)`() {
        val result = EmergencyExecutor.executeEmergency(context, "() -")
        Thread.sleep(500)

        assertEquals(
            "Input that sanitizes to empty must take the empty-target failed " +
                "path, never dial a garbage URI",
            "failed",
            result["status"],
        )
        assertNull(
            "No intent may be started for a separator-only target",
            shadowApp.nextStartedActivity,
        )
    }

    @Test
    fun `executeEmergency never throws even if context is problematic`() {
        var threw = false
        try {
            EmergencyExecutor.executeEmergency(context, "")
            Thread.sleep(200)
        } catch (e: Exception) {
            threw = true
        }
        assertEquals("executeEmergency must never propagate exceptions to the caller", false, threw)
    }
}
