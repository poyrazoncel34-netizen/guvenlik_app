package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
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

    /**
     * OD-1 PATH B on a device: the real [CountdownAlarmReceiver], reached the
     * way AlarmManager reaches it, with the real Direct Boot store and the real
     * Telecom requester.
     *
     * The JVM parity test proves the coordinator's decision. This proves the
     * component actually wired to the alarm honours it -- which is the half
     * that was broken: `claimAndDispatch` had no age limit, so this receiver
     * placed an automatic emergency call hours after the deadline while the
     * reconcile path offered a manual action for the identical record.
     */
    @Test
    fun overdueAlarmDeliveryIsOfferedNotDialled() {
        assumeTrue(args.getString(ARG_MODE) == "alarm")
        val envelope = seed(overdueByMs = 60L * 60L * 1_000L)

        deliverAlarm(envelope.token)

        val after = read(envelope.token)
        Log.i(
            TAG,
            "ALARM_OVERDUE state=${after?.lifecycleState?.wireValue} " +
                "call=${after?.callRequestOutcome?.wireValue} " +
                "fallback=${after?.fallbackOutcome?.wireValue}",
        )
        assertEquals(
            "an hour-late alarm delivery must not reach Telecom",
            CallRequestOutcome.NOT_ATTEMPTED,
            after?.callRequestOutcome,
        )
        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, after?.lifecycleState)
        assertEquals(FallbackOutcome.POSTED, after?.fallbackOutcome)
    }

    /** The negative control for the alarm path. */
    @Test
    fun recentAlarmDeliveryIsStillDialled() {
        assumeTrue(args.getString(ARG_MODE) == "alarm-control")
        val envelope = seed(overdueByMs = 30L * 1_000L)

        deliverAlarm(envelope.token)

        val after = read(envelope.token)
        Log.i(
            TAG,
            "ALARM_CONTROL state=${after?.lifecycleState?.wireValue} " +
                "call=${after?.callRequestOutcome?.wireValue}",
        )
        assertTrue(
            "a 30s-late alarm delivery must still be dispatched automatically",
            after?.callRequestOutcome != CallRequestOutcome.NOT_ATTEMPTED,
        )
    }

    /**
     * The two paths, on the same device, against the same record age. This is
     * the parity assertion OD-1 is actually about: before the fix these two
     * modes produced manualActionRequired and requestSubmittedUnconfirmed
     * respectively.
     */
    @Test
    fun bothPathsAgreeOnAnOverdueRecord() {
        assumeTrue(args.getString(ARG_MODE) == "parity")
        val overdue = 60L * 60L * 1_000L

        val viaReconcile = seed(overdueByMs = overdue)
        EmergencySessionRuntime.coordinator(context).reconcileAfterBoot()
        val reconcileState = read(viaReconcile.token)?.lifecycleState
        val reconcileCall = read(viaReconcile.token)?.callRequestOutcome

        clearSlot()
        val viaAlarm = seed(overdueByMs = overdue)
        deliverAlarm(viaAlarm.token)
        val alarmState = read(viaAlarm.token)?.lifecycleState
        val alarmCall = read(viaAlarm.token)?.callRequestOutcome

        Log.i(
            TAG,
            "PARITY reconcile=${reconcileState?.wireValue}/${reconcileCall?.wireValue} " +
                "alarm=${alarmState?.wireValue}/${alarmCall?.wireValue}",
        )
        assertEquals("the two paths disagree about the same record", reconcileState, alarmState)
        assertEquals(reconcileCall, alarmCall)
        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, alarmState)
        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, alarmCall)
    }

    /**
     * The wall-clock attack, on a device, inside ONE boot.
     *
     * The record is seeded with a monotonic deadline that is still in the
     * future and a WALL deadline that is already hours in the past -- exactly
     * what the store holds after the user (or the network) moved the clock
     * forward while the app was not running, so no TIME_SET was delivered.
     * A live session must survive that: not called, not terminated, still armed.
     *
     * The reconcile here is `reconcileCurrentBoot`, deliberately, and NOT
     * `reconcileAfterBoot`. A same-boot record is what the current-boot paths
     * actually see -- ACTION_USER_UNLOCKED, ACTION_MY_PACKAGE_REPLACED, the
     * exact-alarm grant broadcast, and MainActivity's process-start reconcile.
     * `reconcileAfterBoot` is reachable only from BOOT_COMPLETED /
     * LOCKED_BOOT_COMPLETED (verified: BootCompletedReceiver is its only
     * caller), where an armed record is by construction from a PREVIOUS boot,
     * so that path rebuilds the elapsed deadline from the wall deadline on
     * purpose -- after a reboot the wall deadline is the only reference that
     * survived. Pairing it with a current-boot stamp describes a device state
     * Android cannot produce, and an earlier version of this probe did exactly
     * that and blamed the coordinator for it. The cross-boot case is asserted
     * separately in [aForwardWallJumpAcrossARebootIsOffered].
     */
    @Test
    fun aForwardWallJumpDoesNotTerminateALiveSession() {
        assumeTrue(args.getString(ARG_MODE) == "wall-forward")
        val envelope = seed(
            overdueByMs = 2L * 60L * 60L * 1_000L,
            monotonicRemainingMs = 60_000L,
        )

        EmergencySessionRuntime.coordinator(context).reconcileCurrentBoot()
        deliverAlarm(envelope.token)

        val after = read(envelope.token)
        Log.i(
            TAG,
            "WALL_FORWARD state=${after?.lifecycleState?.wireValue} " +
                "call=${after?.callRequestOutcome?.wireValue} " +
                "fallback=${after?.fallbackOutcome?.wireValue}",
        )
        assertEquals(
            "a session with 60 s left must not reach Telecom",
            CallRequestOutcome.NOT_ATTEMPTED,
            after?.callRequestOutcome,
        )
        assertEquals(
            "a live session must not be terminated by a wall-clock jump",
            LifecycleState.ARMED,
            after?.lifecycleState,
        )
        assertEquals(FallbackOutcome.NOT_ATTEMPTED, after?.fallbackOutcome)
    }

    /**
     * The cross-boot half of the wall-clock attack, and the opposite verdict.
     *
     * After a real reboot elapsedRealtime has restarted, so the persisted wall
     * deadline is the only evidence of when the session was due. If the clock
     * also moved forward while the phone was off, that evidence says "hours
     * overdue" and cannot be checked against anything. The owner's rule for an
     * uncertain cross-boot age is the safe direction: offer, never surprise the
     * user with an automatic call.
     */
    @Test
    fun aForwardWallJumpAcrossARebootIsOffered() {
        assumeTrue(args.getString(ARG_MODE) == "wall-forward-boot")
        // No monotonic stamp: that is what a record from another boot amounts to.
        val envelope = seed(overdueByMs = 2L * 60L * 60L * 1_000L)

        EmergencySessionRuntime.coordinator(context).reconcileAfterBoot()

        val after = read(envelope.token)
        Log.i(
            TAG,
            "WALL_FORWARD_BOOT state=${after?.lifecycleState?.wireValue} " +
                "call=${after?.callRequestOutcome?.wireValue}",
        )
        assertEquals(
            "an uncertain cross-boot age must not reach Telecom",
            CallRequestOutcome.NOT_ATTEMPTED,
            after?.callRequestOutcome,
        )
        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, after?.lifecycleState)
    }

    /**
     * The opposite direction, which is the one that loses a call: the monotonic
     * deadline has passed, the ELAPSED_REALTIME alarm fires on time, and the
     * stored WALL deadline is still in the future because the clock was set
     * back. Measured before the fix: 0 calls, session stuck ARMED, reconcile
     * rescheduling the same already-past elapsed deadline forever.
     */
    @Test
    fun aBackwardWallJumpDoesNotBlockADueDispatch() {
        assumeTrue(args.getString(ARG_MODE) == "wall-back")
        val envelope = seed(
            overdueByMs = -60L * 60L * 1_000L,
            monotonicRemainingMs = -30_000L,
        )

        deliverAlarm(envelope.token)

        val after = read(envelope.token)
        Log.i(
            TAG,
            "WALL_BACK state=${after?.lifecycleState?.wireValue} " +
                "call=${after?.callRequestOutcome?.wireValue}",
        )
        assertTrue(
            "a monotonically due session must still be dispatched",
            after?.callRequestOutcome != CallRequestOutcome.NOT_ATTEMPTED,
        )
    }

    /**
     * Builds and delivers the exact broadcast
     * [AndroidEmergencySessionAlarmScheduler] hands to AlarmManager, into the
     * real receiver, so [EmergencyReceiverGuard] and the intent's own token
     * parsing are on the path too.
     */
    private fun deliverAlarm(token: SessionToken) {
        val receiver = if (token.kind == SessionKind.PANIC) {
            CountdownAlarmReceiver()
        } else {
            CheckInAlarmReceiver()
        }
        val intent = Intent(
            context,
            if (token.kind == SessionKind.PANIC) {
                CountdownAlarmReceiver::class.java
            } else {
                CheckInAlarmReceiver::class.java
            },
        ).apply {
            action = AndroidEmergencySessionAlarmScheduler.ACTION_DISPATCH
            data = Uri.Builder()
                .scheme("korubeni")
                .authority("emergency-session")
                .appendPath(token.kind.wireValue)
                .appendPath(token.randomId)
                .appendPath(token.generation.toString())
                .appendPath("exact")
                .appendPath(AndroidEmergencySessionAlarmScheduler.ACTION_DISPATCH)
                .build()
            putExtra(
                AndroidEmergencySessionAlarmScheduler.EXTRA_PROTOCOL_VERSION,
                token.protocolVersion,
            )
            putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_RANDOM_ID, token.randomId)
            putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_GENERATION, token.generation)
            putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_KIND, token.kind.wireValue)
        }
        assertEquals(
            "the probe's intent must parse to the seeded token",
            token,
            AndroidEmergencySessionAlarmScheduler.tokenFromIntent(intent),
        )
        receiver.onReceive(context, intent)
    }

    private fun clearSlot() {
        assertTrue("slot clear failed", DeviceProtectedEmergencySessionStore(context).clearAll())
    }

    /**
     * @param overdueByMs how far the WALL deadline is in the past (negative =
     *   still in the future).
     * @param monotonicRemainingMs when non-null, the record also carries a
     *   CURRENT-boot elapsed stamp whose deadline is this many ms away
     *   (negative = already passed), which is what makes the two clocks
     *   disagree on purpose. Null keeps the historical behaviour: no monotonic
     *   stamp at all, so only the wall deadline exists.
     */
    private fun seed(
        overdueByMs: Long,
        lifecycleState: LifecycleState = LifecycleState.ARMED,
        monotonicRemainingMs: Long? = null,
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
        val elapsedNow = SystemClock.elapsedRealtime()
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
            elapsedRealtimeDeadlineMs = monotonicRemainingMs?.let { elapsedNow + it } ?: 0L,
            // A stamp only counts as monotonic evidence when it belongs to this
            // boot, so the real boot identity is read, not faked.
            elapsedBootCount = monotonicRemainingMs?.let { BootIdentity.current(context) }
                ?: UNKNOWN_BOOT_COUNT,
            elapsedBootId = monotonicRemainingMs?.let { BootIdentity.bootId().orEmpty() } ?: "",
            elapsedStampMs = monotonicRemainingMs?.let { elapsedNow } ?: -1L,
            target = target,
            schedulingMode = SchedulingMode.NONE,
        )
        assertTrue("seed write failed", store.write(envelope))
        Log.i(
            TAG,
            "SEEDED state=${lifecycleState.wireValue} overdueByMs=$overdueByMs " +
                "monotonicRemainingMs=$monotonicRemainingMs",
        )
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
