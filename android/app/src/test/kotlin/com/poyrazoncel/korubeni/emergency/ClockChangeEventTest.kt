package com.poyrazoncel.korubeni.emergency

import android.content.Intent
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

/**
 * Audit Y-01 (2026-10-08): the receiver rebased native deadlines on TIME_SET
 * but told nobody. The Dart listener for `safetyClockChanged` existed and was
 * never triggered, so a foreground Check-In kept projecting the OLD wall
 * deadline: "Süre doldu" thirteen minutes early after +1 h, "134:19" with
 * fourteen minutes left after -2 h (API 35 emulator).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class ClockChangeEventTest {
    private val context = RuntimeEnvironment.getApplication()

    private class RecordingSink : EventChannel.EventSink {
        val events = mutableListOf<Any?>()
        override fun success(event: Any?) {
            events += event
        }
        override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) = Unit
        override fun endOfStream() = Unit
    }

    @After
    fun detach() = EmergencyEventBus.detach()

    @Test
    fun `a wall clock change tells a running engine to re-read its sessions`() {
        val sink = RecordingSink()
        EmergencyEventBus.attach(sink)

        ClockChangeReceiver().onReceive(context, Intent(Intent.ACTION_TIME_CHANGED))
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertEquals(1, sink.events.size)
        assertEquals("safetyClockChanged", (sink.events.single() as Map<*, *>)["type"])
    }

    @Test
    fun `a time zone change does the same`() {
        val sink = RecordingSink()
        EmergencyEventBus.attach(sink)

        ClockChangeReceiver().onReceive(context, Intent(Intent.ACTION_TIMEZONE_CHANGED))
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertEquals(1, sink.events.size)
    }

    @Test
    fun `without an engine nothing is parked in the single pending slot`() {
        val prefs = EmergencyPrefs.prefs(context)
        prefs.edit().putString(EmergencyPrefs.KEY_PENDING_TRIGGER, "{\"type\":\"emergencySessionDispatched\"}").commit()

        ClockChangeReceiver().onReceive(context, Intent(Intent.ACTION_TIME_CHANGED))
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertTrue(
            "a dispatch outcome waiting for Dart must not be overwritten",
            prefs.getString(EmergencyPrefs.KEY_PENDING_TRIGGER, null)!!.contains("emergencySessionDispatched"),
        )
    }

    @Test
    fun `an unrelated broadcast emits nothing`() {
        val sink = RecordingSink()
        EmergencyEventBus.attach(sink)

        ClockChangeReceiver().onReceive(context, Intent(Intent.ACTION_SCREEN_ON))
        Shadows.shadowOf(Looper.getMainLooper()).idle()

        assertFalse(sink.events.isNotEmpty())
    }
}
