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
import org.robolectric.shadows.ShadowSystemClock
import java.time.Duration

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

    /** The injected elapsedRealtime (ms). Starts at 0, as it does at boot. */
    private var nowMs = 0L

    private fun enabledDetector(sink: RecordingSink) =
        VolumeButtonDetector(elapsedRealtimeMs = { nowMs }).apply {
            onListen(null, sink)
            setEnabled(true)
        }

    private fun down(keyCode: Int = KeyEvent.KEYCODE_VOLUME_DOWN) =
        KeyEvent(KeyEvent.ACTION_DOWN, keyCode)

    private fun up(keyCode: Int = KeyEvent.KEYCODE_VOLUME_DOWN) =
        KeyEvent(KeyEvent.ACTION_UP, keyCode)

    /** The DOWN Android repeats while a key is held: repeatCount > 0. */
    private fun heldDown(repeatCount: Int, keyCode: Int = KeyEvent.KEYCODE_VOLUME_DOWN) =
        KeyEvent(0L, 0L, KeyEvent.ACTION_DOWN, keyCode, repeatCount)

    /** One full press: (DOWN swallowed, UP swallowed). */
    private fun VolumeButtonDetector.press(
        keyCode: Int = KeyEvent.KEYCODE_VOLUME_DOWN,
    ): Pair<Boolean, Boolean> = onKeyEvent(down(keyCode)) to onKeyEvent(up(keyCode))

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

        repeat(2) {
            assertFalse(detector.onKeyEvent(down()))
            assertFalse(detector.onKeyEvent(up()))
        }
        assertTrue(detector.onKeyEvent(down()))
        assertTrue(detector.onKeyEvent(up()))

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

    // The production default, not the injected test clock. Deep sleep moves
    // elapsedRealtime only, so a wall-clock or uptimeMillis default would
    // still see the first two presses inside the window.
    @Test
    fun `the default clock is the monotonic elapsedRealtime`() {
        val detector = VolumeButtonDetector()
        val sink = RecordingSink()
        detector.onListen(null, sink)
        detector.setEnabled(true)

        repeat(2) { detector.onKeyEvent(down()) }
        ShadowSystemClock.simulateDeepSleep(Duration.ofMillis(2_001))
        detector.onKeyEvent(down())
        assertEquals(
            "2001 ms of elapsedRealtime later the first two presses are out of the window",
            emptyList<Any?>(),
            sink.events,
        )

        repeat(2) { detector.onKeyEvent(down()) }
        assertEquals(listOf("volume_panic"), sink.events)
    }

    // A 0L "never triggered" marker reads as a trigger at boot and holds a
    // phantom five-second cooldown over the first real pattern.
    @Test
    fun `the first pattern after boot is not held off by a phantom cooldown`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)

        repeat(3) { detector.onKeyEvent(down()) }

        assertEquals(listOf("volume_panic"), sink.events)
    }

    @Test
    fun `a single press reaches the system`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)

        assertEquals(false to false, detector.press())
        assertEquals(emptyList<Any?>(), sink.events)
    }

    @Test
    fun `three rapid presses swallow only the triggering press and emit one event`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)

        assertEquals(false to false, detector.press())
        nowMs = 300
        assertEquals(false to false, detector.press(KeyEvent.KEYCODE_VOLUME_UP))
        nowMs = 600
        assertEquals(true to true, detector.press())

        assertEquals(listOf("volume_panic"), sink.events)
    }

    @Test
    fun `presses inside the cooldown neither trigger nor get swallowed`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(3) { detector.press() }

        for (t in listOf(3_500L, 4_000L, 4_999L)) {
            nowMs = t
            assertEquals("t=$t", false to false, detector.press())
        }

        assertEquals(listOf("volume_panic"), sink.events)
    }

    // The 4999 ms press falls inside the cooldown. Had it counted, the 5100 ms
    // press would already complete a pattern.
    @Test
    fun `the next pattern after the cooldown needs three fresh presses`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(3) { detector.press() }
        nowMs = 4_999
        detector.press()

        nowMs = 5_000
        assertEquals(false to false, detector.press())
        nowMs = 5_100
        assertEquals(false to false, detector.press())
        nowMs = 5_200
        assertEquals(true to true, detector.press())

        assertEquals(listOf("volume_panic", "volume_panic"), sink.events)
    }

    @Test
    fun `a disabled detector swallows nothing even for a full pattern`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        detector.setEnabled(false)

        repeat(3) {
            assertEquals(false to false, detector.press())
        }

        assertEquals(emptyList<Any?>(), sink.events)
    }

    @Test
    fun `a press older than two seconds is not counted`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)

        for (t in listOf(0L, 1_000L, 2_001L)) {
            nowMs = t
            assertEquals("t=$t", false to false, detector.press())
        }

        assertEquals(emptyList<Any?>(), sink.events)
    }

    @Test
    fun `a press exactly two seconds old still counts`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        detector.press()
        nowMs = 1_000
        detector.press()

        nowMs = 2_000
        assertEquals(true to true, detector.press())
        assertEquals(listOf("volume_panic"), sink.events)
    }

    // Holding a key to change the volume must not read as three presses.
    @Test
    fun `a held key is one press, not a pattern`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)

        assertFalse(detector.onKeyEvent(down()))
        // Android repeats a held key after ~400 ms, then every ~50 ms.
        for (count in 1..20) {
            nowMs = 400L + 50L * count
            assertFalse("repeat $count", detector.onKeyEvent(heldDown(count)))
        }
        assertFalse(detector.onKeyEvent(up()))

        assertEquals(emptyList<Any?>(), sink.events)
    }

    @Test
    fun `a held triggering press stays swallowed until it is released`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(2) { detector.press() }

        assertTrue(detector.onKeyEvent(down()))
        for (count in 1..5) {
            assertTrue("repeat $count", detector.onKeyEvent(heldDown(count)))
        }
        assertTrue(detector.onKeyEvent(up()))

        assertEquals(listOf("volume_panic"), sink.events)
    }

    // Dart cancels its subscription on `inactive`, which can land between the
    // triggering DOWN and its UP. A lone UP must not reach the system.
    @Test
    fun `the triggering key-up stays swallowed after the listener drops`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(2) { detector.press() }
        assertTrue(detector.onKeyEvent(down()))

        detector.onCancel(null)

        assertTrue(detector.onKeyEvent(up()))
    }

    @Test
    fun `the triggering key-up stays swallowed after the detector is disabled`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(2) { detector.press() }
        assertTrue(detector.onKeyEvent(down()))

        detector.setEnabled(false)

        assertTrue(detector.onKeyEvent(up()))
    }

    @Test
    fun `a lost key-up does not leave the next press swallowed`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(2) { detector.press() }
        assertTrue(detector.onKeyEvent(down()))

        nowMs = 6_000
        assertEquals(false to false, detector.press())
    }

    @Test
    fun `a lost key-up is forgotten even when the listener is gone`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(2) { detector.press() }
        assertTrue(detector.onKeyEvent(down())) // its UP never arrives

        detector.onCancel(null)

        assertEquals(false to false, detector.press())
    }

    @Test
    fun `a lost key-up is forgotten even inside the cooldown`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(2) { detector.press() }
        assertTrue(detector.onKeyEvent(down())) // its UP never arrives

        nowMs = 100

        assertEquals(false to false, detector.press())
    }

    // Rocker overlap: a press of the other key during the cooldown must
    // neither take nor release the triggering key's pending key-up.
    @Test
    fun `the other volume key keeps its own key-up decision`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(2) { detector.press() }

        assertTrue(detector.onKeyEvent(down()))
        assertFalse(detector.onKeyEvent(down(KeyEvent.KEYCODE_VOLUME_UP)))
        assertFalse(detector.onKeyEvent(up(KeyEvent.KEYCODE_VOLUME_UP)))
        assertTrue(detector.onKeyEvent(up()))
    }

    @Test
    fun `a held triggering press stays swallowed after the listener drops`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)
        repeat(2) { detector.press() }
        assertTrue(detector.onKeyEvent(down()))

        detector.onCancel(null)

        for (count in 1..3) {
            assertTrue("repeat $count", detector.onKeyEvent(heldDown(count)))
        }
        assertTrue(detector.onKeyEvent(up()))
    }

    // Focus can arrive while a key is already held: repeats whose initial
    // DOWN was never seen here are neither counted nor swallowed.
    @Test
    fun `repeats without a seen initial press are never counted`() {
        val sink = RecordingSink()
        val detector = enabledDetector(sink)

        for (count in 1..5) {
            assertFalse("repeat $count", detector.onKeyEvent(heldDown(count)))
        }

        assertEquals(emptyList<Any?>(), sink.events)
    }
}
