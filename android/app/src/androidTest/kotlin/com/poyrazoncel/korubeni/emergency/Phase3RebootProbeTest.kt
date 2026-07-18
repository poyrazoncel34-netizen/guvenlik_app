package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Two-stage probe driven only by scripts/phase3_emulator_reboot_probe.sh. */
@RunWith(AndroidJUnit4::class)
class Phase3RebootProbeTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun armTypedSessionForRealReboot() {
        assumeTrue(probeMode() == "arm")
        val now = System.currentTimeMillis()
        val store = DeviceProtectedEmergencySessionStore(context)
        store.clearAll()
        assertTrue(
            store.write(
                EmergencySessionEnvelope(
                    token = probeToken(),
                    lifecycleState = LifecycleState.ARMED,
                    // This probe is hard-blocked to an ephemeral emulator and
                    // uninstalls the package in a trap. All-zero is callable by
                    // the parser but cannot identify a real configured contact.
                    target = "0000000",
                    mainDeadlineMs = now + 1_800_000L,
                    finalDeadlineMs = now + 1_800_000L,
                    elapsedRealtimeDeadlineMs = 0L,
                    schedulingMode = SchedulingMode.EXACT_AND_INEXACT,
                ),
            ),
        )
    }

    @Test
    fun verifyManifestBootReceiverRestoredTypedSession() {
        assumeTrue(probeMode() == "verify")
        val store = DeviceProtectedEmergencySessionStore(context)
        try {
            val present = store.read(SessionSlot.PANIC) as SessionRead.Present
            assertEquals(probeToken(), present.envelope.token)
            assertEquals(LifecycleState.ARMED, present.envelope.lifecycleState)
            assertTrue(present.envelope.elapsedRealtimeDeadlineMs > SystemClock.elapsedRealtime())
        } finally {
            EmergencySessionRuntime.coordinator(context).cancel(probeToken())
            store.clearAll()
        }
    }

    private fun probeToken() = SessionToken(
        protocolVersion = EMERGENCY_PROTOCOL_VERSION,
        randomId = "phase3-real-reboot",
        generation = 1L,
        kind = SessionKind.PANIC,
    )

    private fun probeMode(): String? = InstrumentationRegistry
        .getArguments()
        .getString("phase3Probe")
}
