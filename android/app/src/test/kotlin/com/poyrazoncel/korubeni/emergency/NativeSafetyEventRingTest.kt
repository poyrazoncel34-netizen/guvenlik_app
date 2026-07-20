package com.poyrazoncel.korubeni.emergency

import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class NativeSafetyEventRingTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val deviceContext get() = context.createDeviceProtectedStorageContext()
    private val rawPrefs get() = deviceContext.getSharedPreferences(
        "korubeni_native_safety_events_v1",
        Context.MODE_PRIVATE,
    )

    @Before
    fun setUp() {
        rawPrefs.edit().clear().commit()
    }

    @Test
    fun `ring retains only the newest 64 allowlisted events`() {
        var now = 1_000L
        val ring = DeviceProtectedNativeSafetyEventRing(context) { now++ }

        repeat(80) {
            assertTrue(ring.record(NativeSafetyEventCode.BOOT_RECEIVER_BOUNDARY_FAILURE))
        }

        val events = ring.read()
        assertEquals(64, events.size)
        assertEquals(1_016L, events.first().occurredAtMs)
        assertEquals(1_079L, events.last().occurredAtMs)
        assertTrue(events.all {
            it.code == NativeSafetyEventCode.BOOT_RECEIVER_BOUNDARY_FAILURE
        })
    }

    @Test
    fun `corrupt storage is replaced by one valid allowlisted event`() {
        rawPrefs.edit().putString("events", "not-json:+905551234567").commit()
        val ring = DeviceProtectedNativeSafetyEventRing(context) { 42L }

        assertTrue(ring.record(NativeSafetyEventCode.CLOCK_RECEIVER_BOUNDARY_FAILURE))

        val events = ring.read()
        assertEquals(1, events.size)
        assertEquals(42L, events.single().occurredAtMs)
        assertEquals(
            NativeSafetyEventCode.CLOCK_RECEIVER_BOUNDARY_FAILURE,
            events.single().code,
        )
        assertFalse(rawPrefs.getString("events", "").orEmpty().contains("+905551234567"))
    }

    @Test
    fun `receiver guard persists only its fixed code and never exception text`() {
        EmergencyReceiverGuard.run(
            context,
            NativeSafetyEventCode.BOOT_RECEIVER_BOUNDARY_FAILURE,
        ) {
            throw IllegalStateException("secret +905551234567 token=private")
        }

        val events = DeviceProtectedNativeSafetyEventRing(context).read()
        assertEquals(1, events.size)
        assertEquals(
            NativeSafetyEventCode.BOOT_RECEIVER_BOUNDARY_FAILURE,
            events.single().code,
        )
        val serialized = rawPrefs.getString("events", "").orEmpty()
        assertFalse(serialized.contains("secret"))
        assertFalse(serialized.contains("+905551234567"))
        assertFalse(serialized.contains("private"))
    }

    @Test
    fun `clear is synchronous and removes every diagnostic event`() {
        val ring = DeviceProtectedNativeSafetyEventRing(context) { 7L }
        assertTrue(ring.record(NativeSafetyEventCode.PANIC_RECEIVER_BOUNDARY_FAILURE))

        assertTrue(ring.clear())

        assertTrue(ring.read().isEmpty())
        assertTrue(rawPrefs.all.isEmpty())
    }
}
