package com.poyrazoncel.korubeni.emergency

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class EmergencyPlatformReadinessTest {
    @Test
    fun `device state exposes every fail closed readiness capability`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val result = RecordingResult()

        EmergencyPlatformHandler(activity).onMethodCall(
            MethodCall("getDeviceState", emptyMap<String, Any?>()),
            result,
        )

        assertNull(result.errorCode)
        val state = result.successValue as Map<*, *>
        val requiredBooleanFields = setOf(
            "supportedOs",
            "telephonyCalling",
            "telecomAvailable",
            "dialHandlerAvailable",
            "batteryOptimizationsIgnored",
            "canScheduleExactAlarms",
            "callPermissionGranted",
            "notificationsEnabled",
            "alertChannelHigh",
        )
        assertTrue(state.keys.containsAll(requiredBooleanFields))
        requiredBooleanFields.forEach { field ->
            assertTrue("$field must be a Boolean", state[field] is Boolean)
        }
        assertEquals(true, state["supportedOs"])
    }

    private class RecordingResult : MethodChannel.Result {
        var successValue: Any? = null
        var errorCode: String? = null

        override fun success(result: Any?) {
            successValue = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            this.errorCode = errorCode
        }

        override fun notImplemented() {
            errorCode = "notImplemented"
        }
    }
}
