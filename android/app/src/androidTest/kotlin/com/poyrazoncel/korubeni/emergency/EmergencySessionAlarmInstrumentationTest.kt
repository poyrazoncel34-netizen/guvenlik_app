package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.content.Intent
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
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
}
