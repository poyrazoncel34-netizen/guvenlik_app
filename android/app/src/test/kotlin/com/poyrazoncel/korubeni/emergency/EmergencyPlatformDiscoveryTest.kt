package com.poyrazoncel.korubeni.emergency

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class EmergencyPlatformDiscoveryTest {
    @Test
    fun `by-kind read discovers a native session without a Dart token`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val context = activity.applicationContext
        val store = DeviceProtectedEmergencySessionStore(context)
        store.clearAll()
        val token = SessionToken(
            protocolVersion = EMERGENCY_PROTOCOL_VERSION,
            randomId = "native-without-dart-projection",
            generation = 1L,
            kind = SessionKind.CHECK_IN,
        )
        val envelope = EmergencySessionEnvelope(
            token = token,
            lifecycleState = LifecycleState.ARMED,
            target = "+905001234567",
            mainDeadlineMs = 10_000L,
            finalDeadlineMs = 20_000L,
            elapsedRealtimeDeadlineMs = 30_000L,
            schedulingMode = SchedulingMode.EXACT_AND_INEXACT,
        )
        require(store.write(envelope))
        val result = RecordingResult()

        EmergencyPlatformHandler(activity).onMethodCall(
            MethodCall(
                "readEmergencySessionByKind",
                mapOf(
                    "protocolVersion" to EMERGENCY_PROTOCOL_VERSION,
                    "kind" to SessionKind.CHECK_IN.wireValue,
                ),
            ),
            result,
        )

        assertNull(result.errorCode)
        val response = result.successValue as Map<*, *>
        assertEquals("present", response["type"])
        val session = response["session"] as Map<*, *>
        assertEquals(token.toMap(), session["token"])
    }

    @Test
    fun `by-kind read fails closed for an unsupported protocol`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val result = RecordingResult()

        EmergencyPlatformHandler(activity).onMethodCall(
            MethodCall(
                "readEmergencySessionByKind",
                mapOf(
                    "protocolVersion" to EMERGENCY_PROTOCOL_VERSION + 1,
                    "kind" to SessionKind.CHECK_IN.wireValue,
                ),
            ),
            result,
        )

        val response = result.successValue as Map<*, *>
        assertEquals("corrupted", response["type"])
        assertEquals("unsupportedProtocol", response["reasonCode"])
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
