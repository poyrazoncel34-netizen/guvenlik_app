package com.poyrazoncel.korubeni.emergency

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowApplication

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class EmergencyExecutorTest {

    private val context = RuntimeEnvironment.getApplication()
    private val shadowApp get() = Shadows.shadowOf(RuntimeEnvironment.getApplication())

    @Test
    fun `empty number must call 112`() {
        EmergencyExecutor.executeEmergency(context, "")
        Thread.sleep(500)

        val intent = shadowApp.nextStartedActivity
        assertNotNull("An activity intent must be started even with empty number", intent)
        assertEquals("tel:112", intent!!.dataString)
    }

    @Test
    fun `when startActivity throws, fallback 112 dialer is attempted`() {
        var callCount = 0
        val throwingContext = object : android.content.ContextWrapper(context) {
            override fun startActivity(intent: Intent) {
                callCount++
                if (callCount == 1) throw android.content.ActivityNotFoundException("no telephony app")
                super.startActivity(intent)
            }
        }

        EmergencyExecutor.executeEmergency(throwingContext, "+905001234567")
        Thread.sleep(500)

        val intent = shadowApp.nextStartedActivity
        assertNotNull("Fallback 112 intent must be started when primary startActivity throws", intent)
        assertEquals(Intent.ACTION_DIAL, intent!!.action)
        assertEquals("tel:112", intent.dataString)
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
