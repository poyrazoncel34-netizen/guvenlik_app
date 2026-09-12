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
    fun `terminal journal survives slot reuse and cold start until acknowledged`() {
        val store = DeviceProtectedEmergencySessionStore(context)
        val terminal = armedEnvelope().copy(
            lifecycleState = LifecycleState.MANUAL_ACTION_REQUIRED,
            callRequestOutcome = CallRequestOutcome.FAILED,
            fallbackOutcome = FallbackOutcome.POSTED,
            completedAtMs = 1_700_000_180_000L,
        )
        assertTrue(store.write(terminal))
        assertTrue(store.write(terminal))
        assertTrue(store.write(armedEnvelope().copy(token = terminal.token.copy(randomId = "next"))))
        val restored = DeviceProtectedEmergencySessionStore(context)
        val outcomes = restored.pendingOutcomes()
        assertEquals(1, outcomes.size)
        val session = outcomes.single()["session"] as Map<*, *>
        assertEquals("", session["target"])
        assertEquals("failed", session["callRequestOutcome"])
        assertEquals("posted", session["fallbackOutcome"])
        assertEquals(1_700_000_180_000L, session["completedAtMs"])
        assertFalse(outcomes.toString().contains(terminal.target))
        assertTrue(restored.acknowledgeOutcome(terminal.token))
        assertTrue(DeviceProtectedEmergencySessionStore(context).pendingOutcomes().isEmpty())
    }

    @Test
    fun `corrupt journal entry does not hide valid pending outcomes`() {
        val store = DeviceProtectedEmergencySessionStore(context)
        assertTrue(store.write(armedEnvelope().copy(lifecycleState = LifecycleState.REQUEST_FAILED)))
        rawPrefs.edit().putString("outcome_corrupt", "{broken").commit()
        assertEquals(1, DeviceProtectedEmergencySessionStore(context).pendingOutcomes().size)
        assertTrue(rawPrefs.contains("outcome_corrupt"))
    }

    @Test
    fun `wipe removes pending outcomes and cancellation creates no history`() {
        val store = DeviceProtectedEmergencySessionStore(context)
        assertTrue(store.write(armedEnvelope().copy(lifecycleState = LifecycleState.CANCELLED)))
        assertTrue(store.pendingOutcomes().isEmpty())
        assertTrue(store.write(armedEnvelope().copy(lifecycleState = LifecycleState.REQUEST_FAILED)))
        assertEquals(1, store.pendingOutcomes().size)
        assertTrue(store.clearAll())
        assertTrue(store.pendingOutcomes().isEmpty())
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
