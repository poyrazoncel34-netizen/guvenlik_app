package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.os.SystemClock
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Native Doze dispatch probe, driven only by scripts/native_doze_dispatch_probe.sh.
 *
 * Arms a real PANIC session through the production coordinator, then WAITS
 * inside the test while the host turns the screen off and forces deep Doze.
 * Waiting in-process is deliberate: AndroidJUnitRunner force-stops its target
 * when instrumentation finishes, which cancels the app's alarms, so an "arm,
 * exit, check later" design would silently measure nothing.
 *
 * A pass proves: with deep Doze forced and the screen off, the production
 * alarm fired and the native kernel reached Telecom without Flutter, billing
 * or a visible Activity. It does NOT prove delivery after the process has been
 * killed (instrumentation keeps it alive) or any OEM battery-manager behaviour.
 *
 * Both methods are skipped unless the script passes -e nativeDozeProbe, so
 * CI's connected test run never arms a session or places a call.
 */
@RunWith(AndroidJUnit4::class)
class NativeDozeDispatchProbeTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val args = InstrumentationRegistry.getArguments()

    @Test
    fun armWaitForDozeAndRecordDispatch() {
        assumeTrue(args.getString(ARG_MODE) == "run")
        val target = args.getString(ARG_TARGET).orEmpty()
        assertTrue("$ARG_TARGET is required", target.isNotBlank())
        val delaySeconds = args.getString(ARG_DELAY)?.toLongOrNull() ?: 90L
        assertTrue("$ARG_DELAY must be 30..600", delaySeconds in 30L..600L)

        val store = DeviceProtectedEmergencySessionStore(context)
        val existing = store.read(SessionSlot.PANIC)
        if (existing !is SessionRead.Absent && args.getString(ARG_ALLOW_REPLACE) != "1") {
            // Never print the record: it can carry a real contact number.
            fail("PANIC slot is not empty; refusing to overwrite a session record")
        }

        val coordinator = EmergencySessionRuntime.coordinator(context)
        val deadline = System.currentTimeMillis() + delaySeconds * 1_000L
        val result = coordinator.arm(
            ArmRequest(
                protocolVersion = EMERGENCY_PROTOCOL_VERSION,
                randomId = "$RANDOM_ID_PREFIX${System.currentTimeMillis()}",
                kind = SessionKind.PANIC,
                mainDeadlineMs = deadline,
                finalDeadlineMs = deadline,
                target = target,
                entitlementDecision = EntitlementDecision.AUTHORIZED,
                pinConfigured = true,
            ),
        )
        if (result !is ArmResult.Armed) {
            fail("arm refused: ${result.toMap()}")
            return
        }
        Log.i(TAG, "ARMED deadlineMs=$deadline delaySeconds=$delaySeconds")

        var outcome: EmergencySessionEnvelope? = null
        try {
            val giveUpAt = deadline + GRACE_AFTER_DEADLINE_MS
            while (System.currentTimeMillis() < giveUpAt) {
                val envelope = (store.read(SessionSlot.PANIC) as? SessionRead.Present)?.envelope
                if (envelope != null && envelope.token == result.token) {
                    outcome = envelope
                    if (envelope.lifecycleState.isTerminal) break
                }
                SystemClock.sleep(POLL_MS)
            }
            val state = outcome?.lifecycleState?.wireValue ?: "absent"
            val call = outcome?.callRequestOutcome?.wireValue ?: "none"
            val fallback = outcome?.fallbackOutcome?.wireValue ?: "none"
            val completedAt = outcome?.completedAtMs ?: 0L
            val latenessMs = if (completedAt > 0L) completedAt - deadline else -1L
            Log.i(TAG, "RESULT state=$state call=$call fallback=$fallback latenessMs=$latenessMs")

            assertTrue(
                "session did not reach a terminal state within " +
                    "${GRACE_AFTER_DEADLINE_MS / 1_000L}s of its deadline (state=$state)",
                outcome?.lifecycleState?.isTerminal == true,
            )
            assertNotEquals(
                "the native kernel never attempted the call",
                CallRequestOutcome.NOT_ATTEMPTED,
                outcome?.callRequestOutcome,
            )
        } finally {
            val now = (store.read(SessionSlot.PANIC) as? SessionRead.Present)?.envelope
            if (now != null && now.token == result.token && !now.lifecycleState.isTerminal) {
                coordinator.cancel(result.token)
                Log.i(TAG, "CLEANUP cancelled unfinished probe session")
            }
        }
    }

    /** Safety net for an interrupted run: an ARMED record left behind would dispatch after reboot. */
    @Test
    fun cancelLeftoverProbeSession() {
        assumeTrue(args.getString(ARG_MODE) == "cancel")
        val store = DeviceProtectedEmergencySessionStore(context)
        val envelope = (store.read(SessionSlot.PANIC) as? SessionRead.Present)?.envelope
        if (envelope == null ||
            !envelope.token.randomId.startsWith(RANDOM_ID_PREFIX) ||
            envelope.lifecycleState.isTerminal
        ) {
            Log.i(TAG, "CANCEL nothing to cancel")
            return
        }
        val cancel = EmergencySessionRuntime.coordinator(context).cancel(envelope.token)
        Log.i(TAG, "CANCEL leftover probe session result=${cancel::class.simpleName}")
    }

    private companion object {
        const val TAG = "NativeDozeProbe"
        const val ARG_MODE = "nativeDozeProbe"
        const val ARG_TARGET = "nativeDozeTarget"
        const val ARG_DELAY = "nativeDozeDelaySeconds"
        const val ARG_ALLOW_REPLACE = "nativeDozeAllowReplace"
        const val RANDOM_ID_PREFIX = "native-doze-probe-"
        const val GRACE_AFTER_DEADLINE_MS = 180_000L
        const val POLL_MS = 1_000L
    }
}
