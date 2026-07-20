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
class LegacySafetyAuthorityTest {
    @Test
    fun `all legacy safety channel methods are explicitly not implemented`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val handler = EmergencyPlatformHandler(activity)
        val methods = listOf(
            "scheduleCheckIn",
            "didCheckInAlarmFire",
            "getCheckInDeadlineState",
            "cancelCheckIn",
            "executeEmergencyNative",
            "scheduleCountdownAlarm",
            "cancelCountdownAlarm",
            "didCountdownAlarmFire",
            "clearEmergencyPrefs",
        )

        methods.forEach { method ->
            val result = RecordingResult()
            handler.onMethodCall(MethodCall(method, emptyMap<String, Any?>()), result)
            assertTrue("$method must fail closed", result.notImplemented)
            assertNull(result.successValue)
            assertNull(result.errorCode)
        }
    }

    @Test
    fun `typed wipe clears legacy credential protected targets after completion`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val context = activity.applicationContext
        DeviceProtectedEmergencySessionStore(context).clearAll()
        EmergencyPrefs.prefs(context).edit()
            .putString(EmergencyPrefs.KEY_CHECK_IN_PRIMARY_NUMBER, "+905001234567")
            .putString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, "+905009998877")
            .commit()
        val diagnostics = DeviceProtectedNativeSafetyEventRing(context) { 99L }
        assertTrue(
            diagnostics.record(NativeSafetyEventCode.PANIC_RECEIVER_BOUNDARY_FAILURE),
        )
        val result = RecordingResult()

        EmergencyPlatformHandler(activity).onMethodCall(
            MethodCall("wipeEmergencySessions", emptyMap<String, Any?>()),
            result,
        )

        assertEquals("completed", (result.successValue as Map<*, *>)["type"])
        assertTrue(EmergencyPrefs.prefs(context).all.isEmpty())
        assertTrue(diagnostics.read().isEmpty())
    }

    private class RecordingResult : MethodChannel.Result {
        var successValue: Any? = null
        var errorCode: String? = null
        var notImplemented: Boolean = false

        override fun success(result: Any?) {
            successValue = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            this.errorCode = errorCode
        }

        override fun notImplemented() {
            notImplemented = true
        }
    }
}
