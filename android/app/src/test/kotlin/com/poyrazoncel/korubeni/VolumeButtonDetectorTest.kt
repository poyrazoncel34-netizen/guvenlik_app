package com.poyrazoncel.korubeni

import android.view.KeyEvent
import io.flutter.plugin.common.EventChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class VolumeButtonDetectorTest {
    private class RecordingSink : EventChannel.EventSink {
        val events = mutableListOf<Any?>()

        override fun success(event: Any?) {
            events += event
        }

        override fun error(code: String, message: String?, details: Any?) = Unit

        override fun endOfStream() = Unit
    }

    private fun down(keyCode: Int = KeyEvent.KEYCODE_VOLUME_DOWN) =
        KeyEvent(KeyEvent.ACTION_DOWN, keyCode)

    private fun up(keyCode: Int = KeyEvent.KEYCODE_VOLUME_DOWN) =
        KeyEvent(KeyEvent.ACTION_UP, keyCode)

    @Test
    fun `disabled detector never consumes volume keys`() {
        val detector = VolumeButtonDetector()
        val sink = RecordingSink()
        detector.onListen(null, sink)

        assertFalse(detector.onKeyEvent(down()))
        assertFalse(detector.onKeyEvent(up()))
        assertEquals(emptyList<Any?>(), sink.events)
    }

    @Test
    fun `enabled detector requires a live Flutter listener`() {
        val detector = VolumeButtonDetector()
        detector.setEnabled(true)

        assertFalse(detector.onKeyEvent(down()))
    }

    @Test
    fun `three rapid volume presses emit exactly one panic event`() {
        val detector = VolumeButtonDetector()
        val sink = RecordingSink()
        detector.onListen(null, sink)
        detector.setEnabled(true)

        repeat(3) {
            assertTrue(detector.onKeyEvent(down()))
            assertTrue(detector.onKeyEvent(up()))
        }

        assertEquals(listOf("volume_panic"), sink.events)

        repeat(3) { detector.onKeyEvent(down()) }
        assertEquals(
            "the five-second cooldown must suppress a rapid duplicate",
            listOf("volume_panic"),
            sink.events,
        )
    }

    @Test
    fun `wrong keys pass through and disabling clears a partial pattern`() {
        val detector = VolumeButtonDetector()
        val sink = RecordingSink()
        detector.onListen(null, sink)
        detector.setEnabled(true)

        assertFalse(detector.onKeyEvent(down(KeyEvent.KEYCODE_BACK)))
        repeat(2) { detector.onKeyEvent(down()) }
        detector.setEnabled(false)
        detector.setEnabled(true)
        detector.onKeyEvent(down())

        assertEquals(emptyList<Any?>(), sink.events)
    }
}
