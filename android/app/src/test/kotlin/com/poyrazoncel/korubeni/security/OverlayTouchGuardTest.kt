package com.poyrazoncel.korubeni.security

import android.view.MotionEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Pure decisions only: no Activity and no window. Robolectric is used solely
 * because MotionEvent's flag constants live in the Android SDK; nothing here
 * touches a real view hierarchy. The policy split is the safety-relevant part,
 * so it is tested where it cannot be flaky.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class OverlayTouchGuardTest {

    @Test
    fun `wire values decode to their policies`() {
        assertEquals(OverlayTouchGuard.Policy.OFF, OverlayTouchGuard.policyFrom("off"))
        assertEquals(OverlayTouchGuard.Policy.WARN, OverlayTouchGuard.policyFrom("warn"))
        assertEquals(OverlayTouchGuard.Policy.BLOCK, OverlayTouchGuard.policyFrom("block"))
    }

    @Test
    fun `an unrecognised policy decodes to null, never to a weaker one`() {
        // A platform-channel argument is input. Falling back to OFF here would
        // turn a typo into a silently disabled guard.
        assertNull(OverlayTouchGuard.policyFrom(null))
        assertNull(OverlayTouchGuard.policyFrom(""))
        assertNull(OverlayTouchGuard.policyFrom("OFF"))
        assertNull(OverlayTouchGuard.policyFrom("warn "))
        assertNull(OverlayTouchGuard.policyFrom("strict"))
    }

    @Test
    fun `only BLOCK hands touches to the framework filter`() {
        // WARN must NOT set it: that is the whole reason the two policies exist.
        // Discarding touches on a gateway surface can lock an owner out of their
        // own safety app, panic button included.
        assertFalse(OverlayTouchGuard.filterTouches(OverlayTouchGuard.Policy.OFF))
        assertFalse(OverlayTouchGuard.filterTouches(OverlayTouchGuard.Policy.WARN))
        assertTrue(OverlayTouchGuard.filterTouches(OverlayTouchGuard.Policy.BLOCK))
    }

    @Test
    fun `obscured is read from the at-the-touch-point flag only`() {
        assertTrue(OverlayTouchGuard.isObscured(MotionEvent.FLAG_WINDOW_IS_OBSCURED))
        assertTrue(
            OverlayTouchGuard.isObscured(
                MotionEvent.FLAG_WINDOW_IS_OBSCURED or
                    MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED,
            ),
        )
        assertFalse(OverlayTouchGuard.isObscured(0))
        // PARTIALLY_OBSCURED alone fires when something covers the window
        // somewhere other than the touch point, which includes ordinary
        // harmless chrome; warning on it would be constant noise.
        assertFalse(
            OverlayTouchGuard.isObscured(MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED),
        )
    }

    @Test
    fun `both active policies report, so a discarded touch is never silent`() {
        assertTrue(
            OverlayTouchGuard.shouldReport(OverlayTouchGuard.Policy.WARN, true, false),
        )
        assertTrue(
            "a BLOCKed touch must still explain itself; a dead button is its own defect",
            OverlayTouchGuard.shouldReport(OverlayTouchGuard.Policy.BLOCK, true, false),
        )
    }

    @Test
    fun `nothing is reported without a sensitive surface or without an overlay`() {
        assertFalse(
            OverlayTouchGuard.shouldReport(OverlayTouchGuard.Policy.OFF, true, false),
        )
        assertFalse(
            OverlayTouchGuard.shouldReport(OverlayTouchGuard.Policy.WARN, false, false),
        )
        assertFalse(
            OverlayTouchGuard.shouldReport(OverlayTouchGuard.Policy.BLOCK, false, false),
        )
    }

    @Test
    fun `the report fires once per activation, not once per event`() {
        // One tap is DOWN plus MOVE plus UP; a scroll is dozens. A warning on
        // every one of them is noise the user learns to dismiss.
        assertFalse(
            OverlayTouchGuard.shouldReport(OverlayTouchGuard.Policy.WARN, true, true),
        )
        assertFalse(
            OverlayTouchGuard.shouldReport(OverlayTouchGuard.Policy.BLOCK, true, true),
        )
    }
}
