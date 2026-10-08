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
    fun `boot identity of the elapsed deadline round-trips and legacy records read as unknown`() {
        val store = DeviceProtectedEmergencySessionStore(context)
        assertTrue(
            store.write(armedEnvelope().copy(elapsedBootCount = 42, elapsedStampMs = 9_000L)),
        )
        val stored = (store.read(SessionSlot.LONG_RUNNING) as SessionRead.Present).envelope
        assertEquals(42, stored.elapsedBootCount)
        assertEquals(9_000L, stored.elapsedStampMs)

        // A record written before the fields existed (audit A-02) is still a
        // valid ARMED session -- its boot is simply unknown, never corrupted.
        rawPrefs.edit()
            .remove("session_long_elapsedBootCount")
            .remove("session_long_elapsedStampMs")
            .commit()
        val legacy = store.read(SessionSlot.LONG_RUNNING)
        assertTrue(legacy is SessionRead.Present)
        assertEquals(
            UNKNOWN_BOOT_COUNT,
            (legacy as SessionRead.Present).envelope.elapsedBootCount,
        )
        assertEquals(-1L, legacy.envelope.elapsedStampMs)
        assertEquals(LifecycleState.ARMED, legacy.envelope.lifecycleState)
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

    @Test
    fun `acknowledged outcome is not resurrected by a later fallback rewrite`() {
        // expireFallback() fires up to 24h after dispatch and consumeFallback-
        // Target() fires when the user taps the fallback notification. Both
        // re-write the SAME terminal envelope to drop the retained target. The
        // journal used to append on every terminal write, so either one handed
        // an already-acknowledged incident back from pendingOutcomes() as if it
        // were new -- a day later, with no new information.
        val store = DeviceProtectedEmergencySessionStore(context)
        val terminal = armedEnvelope().copy(
            lifecycleState = LifecycleState.REQUEST_FAILED,
            fallbackOutcome = FallbackOutcome.POSTED,
            fallbackExpiresAtMs = 1_800_000_090_000L,
        )
        assertTrue(store.write(terminal))
        assertEquals(1, store.pendingOutcomes().size)

        assertTrue(store.acknowledgeOutcome(terminal.token))
        assertTrue(store.pendingOutcomes().isEmpty())

        // Exactly what expireFallback() writes: same terminal state, target
        // dropped, fallback marked expired.
        assertTrue(
            store.write(
                terminal.copy(
                    target = "",
                    fallbackOutcome = FallbackOutcome.EXPIRED,
                    fallbackExpiresAtMs = 0L,
                ),
            ),
        )
        assertTrue(
            "an acknowledged outcome must stay acknowledged",
            store.pendingOutcomes().isEmpty(),
        )

        // A genuine change of terminal state is still new information.
        assertTrue(
            store.write(terminal.copy(lifecycleState = LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED)),
        )
        assertEquals(1, store.pendingOutcomes().size)
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
