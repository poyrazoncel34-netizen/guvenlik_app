package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

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
}
