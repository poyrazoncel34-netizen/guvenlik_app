package com.poyrazoncel.korubeni.emergency

import android.app.AlarmManager
import android.content.Context
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
        armSession(probeToken())
    }

    @Test
    fun armTypedSessionForExactRevocationReboot() {
        assumeTrue(probeMode() == "armExactRevoked")
        armSession(exactRevocationToken())
    }

    @Test
    fun assertExactAlarmAccessWasActuallyRevoked() {
        assumeTrue(probeMode() == "assertExactRevoked")
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        assertFalse(alarmManager.canScheduleExactAlarms())
    }

    private fun armSession(token: SessionToken) {
        val now = System.currentTimeMillis()
        val store = DeviceProtectedEmergencySessionStore(context)
        store.clearAll()
        val result = EmergencySessionRuntime.coordinator(context).arm(
            ArmRequest(
                protocolVersion = EMERGENCY_PROTOCOL_VERSION,
                randomId = token.randomId,
                kind = SessionKind.PANIC,
                mainDeadlineMs = now + 1_800_000L,
                finalDeadlineMs = now + 1_800_000L,
                // The script hard-blocks this probe to an ephemeral emulator
                // and uninstalls the package in a trap. All-zero is accepted by
                // the parser but cannot identify a configured real contact.
                target = "0000000",
                entitlementDecision = EntitlementDecision.AUTHORIZED,
                pinConfigured = true,
                requestedGeneration = 1L,
            ),
        )
        assertTrue(
            "production arm prerequisites were not established: $result",
            result is ArmResult.Armed,
        )
        val armed = store.read(SessionSlot.PANIC) as SessionRead.Present
        assertEquals(LifecycleState.ARMED, armed.envelope.lifecycleState)
        // A pre-reboot elapsed value can remain greater than the new boot's
        // uptime even when BOOT_COMPLETED never ran. Zero is a test-only
        // sentinel: the post-reboot assertion can pass only if native
        // reconciliation rebases from the durable wall deadline.
        assertTrue(store.write(armed.envelope.copy(elapsedRealtimeDeadlineMs = 0L)))
    }

    @Test
    fun verifyManifestBootReceiverRestoredTypedSession() {
        assumeTrue(probeMode() == "verify")
        verifyRestoredSession(
            token = probeToken(),
            expectedSchedulingMode = SchedulingMode.EXACT_AND_INEXACT,
        )
    }

    @Test
    fun verifyExactRevocationRestoredInexactBackup() {
        assumeTrue(probeMode() == "verifyExactRevoked")
        verifyRestoredSession(
            token = exactRevocationToken(),
            expectedSchedulingMode = SchedulingMode.INEXACT_ONLY,
        )
    }

    private fun verifyRestoredSession(
        token: SessionToken,
        expectedSchedulingMode: SchedulingMode,
    ) {
        val store = DeviceProtectedEmergencySessionStore(context)
        try {
            val present = store.read(SessionSlot.PANIC) as SessionRead.Present
            assertEquals(token, present.envelope.token)
            assertEquals(LifecycleState.ARMED, present.envelope.lifecycleState)
            assertEquals(expectedSchedulingMode, present.envelope.schedulingMode)
            assertTrue(present.envelope.elapsedRealtimeDeadlineMs > SystemClock.elapsedRealtime())
        } finally {
            EmergencySessionRuntime.coordinator(context).cancel(token)
            store.clearAll()
        }
    }

    private fun probeToken() = SessionToken(
        protocolVersion = EMERGENCY_PROTOCOL_VERSION,
        randomId = "phase3-real-reboot",
        generation = 1L,
        kind = SessionKind.PANIC,
    )

    private fun exactRevocationToken() = SessionToken(
        protocolVersion = EMERGENCY_PROTOCOL_VERSION,
        randomId = "phase3-exact-revoked-reboot",
        generation = 1L,
        kind = SessionKind.PANIC,
    )

    private fun probeMode(): String? = InstrumentationRegistry
        .getArguments()
        .getString("phase3Probe")
}
