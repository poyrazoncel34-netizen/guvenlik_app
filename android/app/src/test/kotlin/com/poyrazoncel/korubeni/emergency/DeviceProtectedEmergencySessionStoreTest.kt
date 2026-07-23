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
class DeviceProtectedEmergencySessionStoreTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val deviceContext get() = context.createDeviceProtectedStorageContext()
    private val rawPrefs get() = deviceContext.getSharedPreferences(
        "korubeni_emergency_session_v1",
        Context.MODE_PRIVATE,
    )

    @Before
    fun setUp() {
        rawPrefs.edit().clear().commit()
    }

    @Test
    fun `device protected envelope contains no PIN RevenueCat location or contact name`() {
        val store = DeviceProtectedEmergencySessionStore(context)
        assertTrue(store.write(armedEnvelope()))

        val serializedKeys = rawPrefs.all.keys.joinToString("|").lowercase()

        assertFalse(serializedKeys.contains("pin"))
        assertFalse(serializedKeys.contains("lockout"))
        assertFalse(serializedKeys.contains("revenue"))
        assertFalse(serializedKeys.contains("location"))
        assertFalse(serializedKeys.contains("contactname"))
        assertEquals("+905001234567", rawPrefs.getString("session_long_target", null))
    }

    @Test
    fun `unknown schema is corrupted and never interpreted as armed`() {
        rawPrefs.edit()
            .putInt("session_long_schemaVersion", 99)
            .commit()

        val read = DeviceProtectedEmergencySessionStore(context).read(SessionSlot.LONG_RUNNING)

        assertTrue(read is SessionRead.Corrupted)
        assertEquals("unknownSchema", (read as SessionRead.Corrupted).reasonCode)
    }

    @Test
    fun `cancel tombstone synchronously removes target`() {
        val store = DeviceProtectedEmergencySessionStore(context)
        assertTrue(store.write(armedEnvelope()))
        val cancelled = armedEnvelope().copy(
            lifecycleState = LifecycleState.CANCELLED,
            target = "",
        )

        assertTrue(store.write(cancelled))

        val restored = store.read(SessionSlot.LONG_RUNNING) as SessionRead.Present
        assertEquals(LifecycleState.CANCELLED, restored.envelope.lifecycleState)
        assertEquals("", restored.envelope.target)
    }

    @Test
    fun `inexact only scheduling mode survives device protected round trip`() {
        val store = DeviceProtectedEmergencySessionStore(context)
        val degraded = armedEnvelope().copy(schedulingMode = SchedulingMode.INEXACT_ONLY)

        assertTrue(store.write(degraded))

        val restored = store.read(SessionSlot.LONG_RUNNING) as SessionRead.Present
        assertEquals(SchedulingMode.INEXACT_ONLY, restored.envelope.schedulingMode)
        assertEquals(degraded.token, restored.envelope.token)
    }

    private fun armedEnvelope() = EmergencySessionEnvelope(
        token = SessionToken(
            protocolVersion = EMERGENCY_PROTOCOL_VERSION,
            randomId = "device-store-test",
            generation = 1,
            kind = SessionKind.CHECK_IN,
        ),
        lifecycleState = LifecycleState.ARMED,
        target = "+905001234567",
        mainDeadlineMs = 1_800_000_000_000L,
        finalDeadlineMs = 1_800_000_060_000L,
        elapsedRealtimeDeadlineMs = 120_000L,
        schedulingMode = SchedulingMode.EXACT_AND_INEXACT,
    )
}
