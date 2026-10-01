package com.poyrazoncel.korubeni.quickaccess

import com.poyrazoncel.korubeni.emergency.EmergencyPrefs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The quick-access hand-off must not share EmergencyPrefs.KEY_PENDING_TRIGGER:
 * that key holds one payload and is written by the alarm receivers when the
 * event sink is detached. A widget tap overwriting a pending `checkInExpired`
 * would lose the fact that native had already dispatched.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class PanicRequestStoreTest {

    private val context = RuntimeEnvironment.getApplication()

    @Before
    fun setUp() {
        EmergencyPrefs.prefs(context).edit().clear().commit()
    }

    @Test
    fun `no request pending by default`() {
        assertNull(PanicRequestStore.consume(context))
    }

    @Test
    fun `submitted request is readable`() {
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_WIDGET)

        assertEquals(PanicRequestStore.SOURCE_WIDGET, PanicRequestStore.consume(context))
    }

    @Test
    fun `consume clears so one press yields one countdown`() {
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_TILE)

        assertEquals(PanicRequestStore.SOURCE_TILE, PanicRequestStore.consume(context))
        assertNull("second read must be empty", PanicRequestStore.consume(context))
    }

    @Test
    fun `request does not clobber a pending native trigger`() {
        EmergencyPrefs.prefs(context).edit()
            .putString(EmergencyPrefs.KEY_PENDING_TRIGGER, """{"type":"checkInExpired"}""")
            .commit()

        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_TILE)

        val pending = EmergencyPrefs.prefs(context)
            .getString(EmergencyPrefs.KEY_PENDING_TRIGGER, null)
        assertNotNull("a dispatched check-in must still be reconcilable", pending)
        assertEquals(true, pending?.contains("checkInExpired"))
    }

    @Test
    fun `a pending native trigger is untouched by consume`() {
        EmergencyPrefs.prefs(context).edit()
            .putString(EmergencyPrefs.KEY_PENDING_TRIGGER, """{"type":"checkInExpired"}""")
            .commit()
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_WIDGET)

        PanicRequestStore.consume(context)

        assertNotNull(
            EmergencyPrefs.prefs(context).getString(EmergencyPrefs.KEY_PENDING_TRIGGER, null),
        )
    }

    @Test
    fun `KVKK wipe removes the pending request`() {
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_WIDGET)

        EmergencyPrefs.clear(context)

        assertNull(PanicRequestStore.consume(context))
    }

    @Test
    fun `store writes no contact number and no deadline`() {
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_WIDGET)

        // Intent only: a quick-access surface must not become a second place
        // where a target or a deadline is decided.
        //
        // This used to assert `all.size == 1` and read the single value. A bare
        // count says nothing about WHAT the extra entry is, so it would have
        // failed on the freshness stamp -- which is neither a target nor a
        // deadline -- while still passing if a phone number had been written
        // into the one key it did check. The assertions below name the property
        // the test is actually for.
        val all = EmergencyPrefs.prefs(context).all

        assertEquals(
            "the hand-off owns exactly these two keys",
            setOf("quick_panic_pending_source", "quick_panic_requested_elapsed_ms"),
            all.keys,
        )
        assertEquals(PanicRequestStore.SOURCE_WIDGET, all["quick_panic_pending_source"])
        assertTrue(
            "the stamp is an age reading, not a wall-clock deadline to fire at",
            all["quick_panic_requested_elapsed_ms"] is Long,
        )
        all.forEach { (key, value) ->
            assertTrue(
                "no key may name a dispatch target or deadline: $key",
                !key.contains("number") && !key.contains("deadline"),
            )
            if (value is String) {
                assertTrue(
                    "a string value here must be a source label, never a dialable target",
                    !Regex("[0-9]{7,}").containsMatchIn(value),
                )
            }
        }
    }

    // ---------------------------------------------------------------------
    // Freshness window. A recorded press that never reached Flutter used to
    // wait forever, so opening the app days later dropped the user straight
    // into a real countdown.
    // ---------------------------------------------------------------------

    @Test
    fun `a press replayed inside the window is honoured`() {
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_WIDGET, now = 1_000L)

        assertEquals(
            PanicRequestStore.SOURCE_WIDGET,
            PanicRequestStore.consume(context, now = 1_000L + 30_000L),
        )
    }

    @Test
    fun `a press replayed exactly at the window edge is honoured`() {
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_TILE, now = 1_000L)

        // Inclusive on purpose: the boundary belongs to the user, not to the
        // discard rule.
        assertEquals(
            PanicRequestStore.SOURCE_TILE,
            PanicRequestStore.consume(
                context,
                now = 1_000L + PanicRequestStore.FRESHNESS_WINDOW_MS,
            ),
        )
    }

    @Test
    fun `a press older than the window is discarded`() {
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_WIDGET, now = 1_000L)

        assertNull(
            "a press the user stopped expecting must not open a countdown",
            PanicRequestStore.consume(
                context,
                now = 1_000L + PanicRequestStore.FRESHNESS_WINDOW_MS + 1L,
            ),
        )
    }

    @Test
    fun `a press that survived a reboot is discarded`() {
        // elapsedRealtime() restarts at zero on boot, so a pre-reboot stamp is
        // LARGER than the current reading and the age is negative. Without the
        // lower bound that reads as fresh -- the exact case this window closes.
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_TILE, now = 9_000_000L)

        assertNull(PanicRequestStore.consume(context, now = 4_000L))
    }

    @Test
    fun `a record with no timestamp is discarded`() {
        // Written by a build that predates the window: unknown age is not
        // evidence of youth.
        EmergencyPrefs.prefs(context).edit()
            .putString("quick_panic_pending_source", PanicRequestStore.SOURCE_WIDGET)
            .commit()

        assertNull(PanicRequestStore.consume(context, now = 1_000L))
    }

    @Test
    fun `a discarded press does not survive to the next read`() {
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_WIDGET, now = 1_000L)
        val tooLate = 1_000L + PanicRequestStore.FRESHNESS_WINDOW_MS + 1L

        assertNull(PanicRequestStore.consume(context, now = tooLate))
        // Both keys must be gone, or the stale press is re-evaluated on every
        // resume for the rest of the process's life.
        assertNull(PanicRequestStore.consume(context, now = tooLate))
        assertTrue(
            "no fragment of the discarded request may remain",
            EmergencyPrefs.prefs(context).all.isEmpty(),
        )
    }
}
