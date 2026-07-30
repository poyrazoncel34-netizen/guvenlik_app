package com.poyrazoncel.korubeni.quickaccess

import com.poyrazoncel.korubeni.emergency.EmergencyPrefs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
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
        val all = EmergencyPrefs.prefs(context).all
        assertEquals(1, all.size)
        assertEquals(PanicRequestStore.SOURCE_WIDGET, all.values.first())
    }
}
