package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.content.Intent
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class EmergencySessionAlarmInstrumentationTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val scheduler = AndroidEmergencySessionAlarmScheduler(context)
    private val token = SessionToken(
        protocolVersion = EMERGENCY_PROTOCOL_VERSION,
        randomId = "instrumented-alarm",
        generation = 1L,
        kind = SessionKind.PANIC,
    )

    @After
    fun cleanUp() {
        scheduler.cancel(token)
        DeviceProtectedEmergencySessionStore(context).clearAll()
    }

    @Test
    fun typedSchedulerAlwaysAcceptsAnInexactBackupOnSupportedDevice() {
        val now = System.currentTimeMillis()
        val envelope = EmergencySessionEnvelope(
            token = token,
            lifecycleState = LifecycleState.ARMED,
            target = "0000000",
            mainDeadlineMs = now + 600_000L,
            finalDeadlineMs = now + 600_000L,
            elapsedRealtimeDeadlineMs = SystemClock.elapsedRealtime() + 600_000L,
            schedulingMode = SchedulingMode.EXACT_AND_INEXACT,
        )

        val result = scheduler.schedule(envelope)

        assertTrue(result.inexactAccepted)
    }

    @Test
    fun tokenlessLegacyBroadcastCannotDispatch() {
        val store = DeviceProtectedEmergencySessionStore(context)
        store.clearAll()

        CountdownAlarmReceiver().onReceive(
            context,
            Intent(AndroidEmergencySessionAlarmScheduler.ACTION_DISPATCH),
        )

        assertTrue(store.read(SessionSlot.PANIC) is SessionRead.Absent)
    }

    @Test
    fun staleGenerationCannotDispatchThroughRealReceiver() {
        val store = DeviceProtectedEmergencySessionStore(context)
        val now = System.currentTimeMillis()
        assertTrue(
            store.write(
                EmergencySessionEnvelope(
                    token = token,
                    lifecycleState = LifecycleState.ARMED,
                    target = "0000000",
                    mainDeadlineMs = now + 600_000L,
                    finalDeadlineMs = now + 600_000L,
                    elapsedRealtimeDeadlineMs = SystemClock.elapsedRealtime() + 600_000L,
                    schedulingMode = SchedulingMode.EXACT_AND_INEXACT,
                ),
            ),
        )

        CountdownAlarmReceiver().onReceive(
            context,
            dispatchIntent(token.copy(generation = token.generation + 1L)),
        )

        val present = store.read(SessionSlot.PANIC) as SessionRead.Present
        assertEquals(token, present.envelope.token)
        assertEquals(LifecycleState.ARMED, present.envelope.lifecycleState)
        assertEquals("0000000", present.envelope.target)
    }

    @Test
    fun cancelledTombstoneSuppressesRealReceiverDelivery() {
        val store = DeviceProtectedEmergencySessionStore(context)
        val now = System.currentTimeMillis()
        assertTrue(
            store.write(
                EmergencySessionEnvelope(
                    token = token,
                    lifecycleState = LifecycleState.CANCELLED,
                    target = "",
                    mainDeadlineMs = now,
                    finalDeadlineMs = now,
                    elapsedRealtimeDeadlineMs = SystemClock.elapsedRealtime(),
                    schedulingMode = SchedulingMode.NONE,
                ),
            ),
        )

        CountdownAlarmReceiver().onReceive(context, dispatchIntent(token))

        val present = store.read(SessionSlot.PANIC) as SessionRead.Present
        assertEquals(LifecycleState.CANCELLED, present.envelope.lifecycleState)
        assertEquals("", present.envelope.target)
        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, present.envelope.callRequestOutcome)
        assertEquals(FallbackOutcome.NOT_ATTEMPTED, present.envelope.fallbackOutcome)
    }

    @Test
    fun alarmCancellationIsIdempotentOnPlatformScheduler() {
        scheduler.cancel(token)
        scheduler.cancel(token)

        assertTrue(DeviceProtectedEmergencySessionStore(context).read(SessionSlot.PANIC) is SessionRead.Absent)
    }

    private fun dispatchIntent(value: SessionToken) = Intent(
        context,
        CountdownAlarmReceiver::class.java,
    ).apply {
        action = AndroidEmergencySessionAlarmScheduler.ACTION_DISPATCH
        putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_PROTOCOL_VERSION, value.protocolVersion)
        putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_RANDOM_ID, value.randomId)
        putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_GENERATION, value.generation)
        putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_KIND, value.kind.wireValue)
    }
}
