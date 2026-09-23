package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * A-001 device probe: an ARMED session whose deadline passed long ago must be
 * OFFERED, not dialled, when reconcile runs on app open / boot / unlock.
 *
 * Why this exists as an instrumentation test rather than only a JVM one: the
 * JVM tests drive fakes. This drives the REAL Direct Boot store, the REAL
 * production coordinator wiring (AndroidEmergencySessionRuntime), the REAL
 * notification poster and the REAL Telecom requester on a device. The defect
 * being closed was first OBSERVED on a device (see
 * docs/audit/device-verification-2026-09-13-force-stop.md), so the fix is
 * evidenced the same way.
 *
 * The session is written straight into the store instead of going through
 * arm(): arm() correctly refuses a deadline in the past, and the condition
 * under test is precisely a record whose deadline is already hours old --
 * which is how it looks after a force-stop or a power-off.
 *
 * Both methods are skipped unless the runner passes -e overdueProbe, so a
 * normal connected-test run never writes a session record.
 */
@RunWith(AndroidJUnit4::class)
class OverdueSessionProbeTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val args = InstrumentationRegistry.getArguments()

    @Test
    fun overdueSessionIsOfferedNotDialled() {
        assumeTrue(args.getString(ARG_MODE) == "overdue")
        val envelope = seed(overdueByMs = 60L * 60L * 1_000L)

        EmergencySessionRuntime.coordinator(context).reconcileAfterBoot()

        val after = read(envelope.token)
        Log.i(
            TAG,
            "OVERDUE state=${after?.lifecycleState?.wireValue} " +
                "call=${after?.callRequestOutcome?.wireValue} " +
                "fallback=${after?.fallbackOutcome?.wireValue}",
        )
        assertEquals(
            "an hour-old session must not reach Telecom",
            CallRequestOutcome.NOT_ATTEMPTED,
            after?.callRequestOutcome,
        )
        assertEquals(
            LifecycleState.MANUAL_ACTION_REQUIRED,
            after?.lifecycleState,
        )
        assertEquals(FallbackOutcome.POSTED, after?.fallbackOutcome)
    }

    /**
     * The negative control. Without it, a probe that simply failed to run
     * would look identical to a pass: "no call happened" proves nothing unless
     * a call demonstrably happens on the other side of the boundary.
     */
    @Test
    fun recentlyOverdueSessionIsStillDialled() {
        assumeTrue(args.getString(ARG_MODE) == "control")
        val envelope = seed(overdueByMs = 30L * 1_000L)

        EmergencySessionRuntime.coordinator(context).reconcileAfterBoot()

        val after = read(envelope.token)
        Log.i(
            TAG,
            "CONTROL state=${after?.lifecycleState?.wireValue} " +
                "call=${after?.callRequestOutcome?.wireValue}",
        )
        assertTrue(
            "a 30s-late session must still be dispatched automatically",
            after?.callRequestOutcome != CallRequestOutcome.NOT_ATTEMPTED,
        )
    }

    /**
     * R3: the same freshness rule must hold for a record left in CLAIMED.
     *
     * CLAIMED is a durable uncertainty boundary, not timeless permission to
     * call: the process can die after the claim commit but before any external
     * side effect. Until this probe, the CLAIMED branch of reconcile dialled
     * with NO age limit, so a record stranded by a force-stop could place an
     * emergency call days later. The ARMED half was measured on
     * 2026-09-20; that record states the CLAIMED branch was left unmeasured.
     */
    @Test
    fun staleClaimedSessionIsOfferedNotDialled() {
        assumeTrue(args.getString(ARG_MODE) == "claimed")
        val envelope = seed(
            overdueByMs = 60L * 60L * 1_000L,
            lifecycleState = LifecycleState.CLAIMED,
        )

        EmergencySessionRuntime.coordinator(context).reconcileAfterBoot()

        val after = read(envelope.token)
        Log.i(
            TAG,
            "CLAIMED_STALE state=${after?.lifecycleState?.wireValue} " +
                "call=${after?.callRequestOutcome?.wireValue} " +
                "fallback=${after?.fallbackOutcome?.wireValue}",
        )
        assertEquals(
            "an hour-old CLAIMED record must not reach Telecom",
            CallRequestOutcome.NOT_ATTEMPTED,
            after?.callRequestOutcome,
        )
        assertEquals(
            LifecycleState.MANUAL_ACTION_REQUIRED,
            after?.lifecycleState,
        )
        assertEquals(FallbackOutcome.POSTED, after?.fallbackOutcome)
    }

    /**
     * The negative control for the CLAIMED pair. A probe that silently failed
     * to run would otherwise be indistinguishable from a pass.
     */
    @Test
    fun recentlyClaimedSessionIsStillDialled() {
        assumeTrue(args.getString(ARG_MODE) == "claimed-control")
        val envelope = seed(
            overdueByMs = 30L * 1_000L,
            lifecycleState = LifecycleState.CLAIMED,
        )

        EmergencySessionRuntime.coordinator(context).reconcileAfterBoot()

        val after = read(envelope.token)
        Log.i(
            TAG,
            "CLAIMED_CONTROL state=${after?.lifecycleState?.wireValue} " +
                "call=${after?.callRequestOutcome?.wireValue}",
        )
        assertTrue(
            "a 30s-late CLAIMED record must still be dispatched automatically",
            after?.callRequestOutcome != CallRequestOutcome.NOT_ATTEMPTED,
        )
    }

    private fun seed(
        overdueByMs: Long,
        lifecycleState: LifecycleState = LifecycleState.ARMED,
    ): EmergencySessionEnvelope {
        val target = args.getString(ARG_TARGET).orEmpty()
        assertTrue("$ARG_TARGET is required", target.isNotBlank())
        val store = DeviceProtectedEmergencySessionStore(context)
        val existing = store.read(SessionSlot.PANIC)
        if (existing !is SessionRead.Absent && args.getString(ARG_ALLOW_REPLACE) != "1") {
            // Never print the record: it can carry a real contact number.
            fail("PANIC slot is not empty; refusing to overwrite a session record")
        }
        val now = System.currentTimeMillis()
        val deadline = now - overdueByMs
        val envelope = EmergencySessionEnvelope(
            token = SessionToken(
                protocolVersion = EMERGENCY_PROTOCOL_VERSION,
                randomId = "$RANDOM_ID_PREFIX$now",
                generation = 1L,
                kind = SessionKind.PANIC,
            ),
            lifecycleState = lifecycleState,
            mainDeadlineMs = deadline,
            finalDeadlineMs = deadline,
            elapsedRealtimeDeadlineMs = 0L,
            target = target,
            schedulingMode = SchedulingMode.NONE,
        )
        assertTrue("seed write failed", store.write(envelope))
        Log.i(TAG, "SEEDED state=${lifecycleState.wireValue} overdueByMs=$overdueByMs")
        return envelope
    }

    private fun read(token: SessionToken): EmergencySessionEnvelope? {
        val store = DeviceProtectedEmergencySessionStore(context)
        val envelope = (store.read(SessionSlot.PANIC) as? SessionRead.Present)?.envelope
        return if (envelope?.token == token) envelope else null
    }

    private companion object {
        const val TAG = "OverdueProbe"
        const val ARG_MODE = "overdueProbe"
        const val ARG_TARGET = "overdueProbeTarget"
        const val ARG_ALLOW_REPLACE = "overdueProbeAllowReplace"
        const val RANDOM_ID_PREFIX = "overdue-probe-"
    }
}
