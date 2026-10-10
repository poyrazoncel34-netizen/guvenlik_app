package com.poyrazoncel.korubeni.emergency

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * OD-1 (owner decision 2026-10-10): the 5-minute freshness policy must be the
 * SAME on every native execution path, and inside one boot it must be judged on
 * the sleep-counting monotonic clock rather than the wall clock.
 *
 * The defect this file reproduces first and then pins:
 *
 *  - [EmergencySessionCoordinator.reconcileArmedFromWall] (exact-alarm regrant,
 *    unlock, package replacement, process-start reconcile) refused to dial a
 *    session more than 5 minutes overdue and offered MANUAL_ACTION_REQUIRED.
 *  - [EmergencySessionCoordinator.claimAndDispatch] -- the single funnel for
 *    CountdownAlarmReceiver, CheckInAlarmReceiver and the Dart
 *    `dispatchEmergencySession` channel -- had NO age limit at all. A late
 *    AlarmManager delivery placed an automatic emergency call hours after the
 *    deadline, which is the outcome audit A-001 exists to prevent.
 *
 * So the same record, with the same semantics, called or did not call purely
 * because of which Android component happened to reach it first.
 *
 * The clock half matters just as much: alarms are scheduled on
 * ELAPSED_REALTIME_WAKEUP (AndroidEmergencySessionAlarmScheduler), so a wall
 * clock the user moved cannot move a deadline -- but every overdue decision
 * except the TIME_SET one was read off that wall clock.
 */
class OverdueDispatchParityTest {
    private val now = 1_700_000_000_000L
    private val sessionMs = 120_000L

    @Test
    fun `reconcile and the alarm receiver agree six minutes past the deadline`() {
        val sixMinutes = 6L * 60_000L

        val viaReconcile = Harness().apply {
            armAndAge(sixMinutes)
            coordinator.reconcileCurrentBoot()
        }
        val viaReceiver = Harness().apply {
            val token = armAndAge(sixMinutes)
            coordinator.claimAndDispatch(token)
        }

        assertEquals(
            "the two paths must not disagree about the same record",
            viaReconcile.state(),
            viaReceiver.state(),
        )
        assertEquals(
            "a six-minute-old deadline must not reach Telecom on the alarm path",
            emptyList<String>(),
            viaReceiver.calls.targets,
        )
        assertEquals(
            LifecycleState.MANUAL_ACTION_REQUIRED,
            viaReceiver.state(),
        )
    }

    /**
     * The negative control. "No call happened" proves nothing unless a call
     * demonstrably happens on the other side of the boundary.
     */
    @Test
    fun `both paths still dial a session only thirty seconds past the deadline`() {
        val thirtySeconds = 30_000L

        val viaReconcile = Harness().apply {
            armAndAge(thirtySeconds)
            coordinator.reconcileCurrentBoot()
        }
        val viaReceiver = Harness().apply {
            val token = armAndAge(thirtySeconds)
            coordinator.claimAndDispatch(token)
        }

        assertEquals(listOf(TARGET), viaReconcile.calls.targets)
        assertEquals(listOf(TARGET), viaReceiver.calls.targets)
        assertEquals(viaReconcile.state(), viaReceiver.state())
        assertEquals(
            LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED,
            viaReceiver.state(),
        )
    }

    /**
     * The wall clock is not an authority for an interval inside one boot. A
     * user (or the network) moving it forward two hours while the app was
     * stopped must not convert a running Check-In into "too late to call".
     */
    @Test
    fun `a wall clock jumped forward does not make a live session overdue`() {
        val harness = Harness()
        val token = harness.arm()
        // One minute of real time passes on the monotonic clock, while the wall
        // clock gains two hours and no TIME_SET was delivered (the app was not
        // running). 118 s of the session are genuinely left.
        harness.elapsed += 60_000L
        harness.wall += 60_000L + 2L * 3_600_000L

        harness.coordinator.reconcileCurrentBoot()
        harness.coordinator.claimAndDispatch(token)

        assertEquals(
            "nothing is due yet on the clock that measures the interval",
            emptyList<String>(),
            harness.calls.targets,
        )
        assertEquals(LifecycleState.ARMED, harness.state())
        assertEquals(
            "a live session must not be offered as a missed one",
            emptyList<FallbackReason>(),
            harness.fallback.reasons,
        )
    }

    /**
     * Surviving a forward wall-clock jump is not enough: the session must stay
     * PROTECTED through it.
     *
     * Two counterfactual mutants survived without this test
     * (OD1-M2, OD1-M9), because "no call was placed" is also what a session
     * that quietly stopped being armed looks like. What has to hold is:
     *
     *  1. the alarm is rescheduled, so the deadline still fires;
     *  2. the monotonic deadline does NOT move -- the promise was an interval;
     *  3. the stored WALL deadline is rebuilt from that interval, because Dart
     *     renders the countdown from it and no TIME_SET was ever delivered (the
     *     app was not running when the clock moved), so the stored value is
     *     simply wrong and would show a two-hour-old countdown.
     */
    @Test
    fun `a forward wall jump keeps the session armed, rescheduled and honestly dated`() {
        val harness = Harness()
        harness.arm()
        val monotonicDeadline = harness.store.current!!.elapsedRealtimeDeadlineMs
        val armScheduleCount = harness.alarms.scheduled.size

        // One minute of real time; the wall clock gains two hours on top.
        harness.elapsed += 60_000L
        harness.wall += 60_000L + 2L * 3_600_000L

        harness.coordinator.reconcileCurrentBoot()

        val after = harness.store.current!!
        assertEquals(LifecycleState.ARMED, after.lifecycleState)
        assertEquals(
            "the deadline must be re-armed, not merely left alone",
            armScheduleCount + 1,
            harness.alarms.scheduled.size,
        )
        assertEquals(
            "the interval the session promised must not move",
            monotonicDeadline,
            after.elapsedRealtimeDeadlineMs,
        )
        assertEquals(
            "the wall deadline Dart renders must match the 60 s actually left",
            harness.wall + 60_000L,
            after.finalDeadlineMs,
        )
        assertEquals(
            "the grace phase length is preserved across the correction",
            60_000L,
            after.finalDeadlineMs - after.mainDeadlineMs,
        )
        assertEquals(
            "the rescheduled alarm carries the corrected deadline",
            harness.wall + 60_000L,
            harness.alarms.scheduled.last().finalDeadlineMs,
        )
    }

    /**
     * OD-1c, found on an API 36 emulator while running the wall-clock attack
     * against a REAL 2-hour Check-In, and traced field by field:
     *
     * | step | state | elapsedStamp | elapsedDeadline | wall |
     * |---|---|---|---|---|
     * | armed            | armed  | 3744486 | 11004481 | +2 h |
     * | force-stop       | armed  | 3744486 | 11004481 | +2 h |
     * | wall +1 day      | armed  | 3744486 | 11004481 | past |
     * | reopen           | **requestSubmittedUnconfirmed** | 3765708 | **3765708** | past |
     *
     * The boot identity never changed (`/proc/sys/kernel/random/boot_id` and
     * `settings get global boot_count` both constant, uptime strictly
     * increasing), so this was the SAME boot and the monotonic deadline was
     * valid -- two hours of protection still to run. `reconcileAfterBoot`
     * rebased it anyway, because `rebaseElapsedFromWall` meant "always": it
     * recomputed the elapsed deadline as
     * `elapsedNow + max(0, wallDeadline - wallNow)`, which with a wall clock
     * now past the deadline collapses to "due right now". The alarm then fired
     * immediately and the contact was called two hours early.
     *
     * This is reachable without any emulator quirk. Android 15+ re-delivers
     * BOOT_COMPLETED after a force-stop -- this repository measured that
     * itself while closing FS-01 (4 -> 0 -> 4 alarms on API 36) -- and a
     * force-stop plus a clock change is an ordinary week on a phone with an
     * aggressive task killer and automatic network time.
     *
     * The rule: a boot broadcast is a reason to DISTRUST an elapsed deadline,
     * never a reason to overwrite one the boot identity proves belongs to this
     * boot. After a genuine reboot the identity differs (and elapsedRealtime
     * has restarted), so the rebase still happens exactly as before.
     */
    @Test
    fun `a boot broadcast in the same boot does not rebase a live elapsed deadline`() {
        val harness = Harness()
        val token = harness.arm()
        val monotonicDeadline = harness.store.current!!.elapsedRealtimeDeadlineMs

        // Force-stopped, then the wall clock gains a day while nothing runs.
        harness.elapsed += 21_000L
        harness.wall += 21_000L + 24L * 3_600_000L

        // Android 15+ re-delivers BOOT_COMPLETED on the next start.
        harness.coordinator.reconcileAfterBoot()
        harness.coordinator.claimAndDispatch(token)

        assertEquals(
            "the contact must not be called two hours early",
            emptyList<String>(),
            harness.calls.targets,
        )
        assertEquals(LifecycleState.ARMED, harness.state())
        assertEquals(
            "a same-boot elapsed deadline must survive a boot broadcast",
            monotonicDeadline,
            harness.store.current!!.elapsedRealtimeDeadlineMs,
        )
    }

    /**
     * Fail-closed: a stamp ABOVE the current elapsed clock is not proof of
     * anything, whatever boot identity the record claims.
     *
     * elapsedRealtime never runs backwards inside a boot, so a record claiming
     * this boot's id while carrying a stamp from the future is either a
     * previous boot's record that kept a stale id, or a corrupted one. Either
     * way the elapsed deadline it carries could be days out, so it must be
     * rebuilt from the wall deadline rather than trusted -- the same direction
     * as a reboot. Without this check an unverifiable record would keep a
     * deadline nothing can bound (mutant OD1-M12).
     */
    @Test
    fun `a stamp from the future is not proof of the current boot`() {
        val harness = Harness()
        harness.arm()
        val armed = harness.store.current!!
        // Same boot id and count, but a stamp an hour above the elapsed clock.
        harness.store.current = armed.copy(
            elapsedStampMs = harness.elapsed + 3_600_000L,
            elapsedRealtimeDeadlineMs = harness.elapsed + 3_600_000L + sessionMs,
        )
        harness.wall += 30_000L

        harness.coordinator.reconcileAfterBoot()

        val after = harness.store.current!!
        assertEquals(LifecycleState.ARMED, after.lifecycleState)
        assertEquals(
            "an unverifiable elapsed deadline must be rebuilt from the wall one",
            harness.elapsed + (sessionMs - 30_000L),
            after.elapsedRealtimeDeadlineMs,
        )
        assertEquals(emptyList<String>(), harness.calls.targets)
    }

    /**
     * The control that keeps the fix honest: after a REAL reboot the elapsed
     * deadline is meaningless and MUST be rebuilt from the persisted wall
     * deadline, which is the only reference that survived.
     */
    @Test
    fun `a real reboot still rebuilds the elapsed deadline from the wall deadline`() {
        val harness = Harness()
        harness.arm()
        val staleMonotonicDeadline = harness.store.current!!.elapsedRealtimeDeadlineMs

        // Rebooted 30 s into the session: new boot identity, elapsed restarted.
        harness.wall += 30_000L
        harness.boot += 1
        harness.elapsed = 8_000L

        harness.coordinator.reconcileAfterBoot()

        val after = harness.store.current!!
        assertEquals(LifecycleState.ARMED, after.lifecycleState)
        assertEquals(
            "the previous boot's uptime must not survive the reboot",
            true,
            after.elapsedRealtimeDeadlineMs != staleMonotonicDeadline,
        )
        assertEquals(
            "the rebuilt deadline is the remaining wall time from now",
            harness.elapsed + (sessionMs - 30_000L),
            after.elapsedRealtimeDeadlineMs,
        )
        assertEquals(emptyList<String>(), harness.calls.targets)
    }

    /**
     * The control for the correction above: with both clocks moving together --
     * every ordinary device, every ordinary reconcile -- nothing is rewritten.
     * Without this, the drift tolerance could be zero and the store would take
     * a write on every single reconcile.
     */
    @Test
    fun `an undisturbed clock is never rewritten by reconcile`() {
        val harness = Harness()
        harness.arm()
        val before = harness.store.current!!

        harness.elapsed += 30_000L
        harness.wall += 30_000L
        harness.coordinator.reconcileCurrentBoot()

        val after = harness.store.current!!
        assertEquals(before.finalDeadlineMs, after.finalDeadlineMs)
        assertEquals(before.mainDeadlineMs, after.mainDeadlineMs)
        assertEquals(before.elapsedRealtimeDeadlineMs, after.elapsedRealtimeDeadlineMs)
    }

    /**
     * The mirror image, and the dangerous direction: the monotonic deadline has
     * genuinely passed, the ELAPSED_REALTIME alarm fires on time, and the wall
     * clock was set BACK. Refusing here is a missed emergency call.
     */
    @Test
    fun `a wall clock set back does not block a monotonically due dispatch`() {
        val harness = Harness()
        val token = harness.arm()
        harness.elapsed += sessionMs
        harness.wall = now - 3_600_000L

        harness.coordinator.claimAndDispatch(token)

        assertEquals(listOf(TARGET), harness.calls.targets)
        assertEquals(
            LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED,
            harness.state(),
        )
    }

    /**
     * OD-1's required matrix: every boundary age against every native entry
     * point that can reach a dispatch, asserting they all land on the SAME
     * verdict. A table test, because the defect was not a wrong verdict -- it
     * was two paths holding different ones.
     *
     * The five paths and the Android events behind them:
     *  - `claimAndDispatch`   CountdownAlarmReceiver, CheckInAlarmReceiver, and
     *                         the Dart `dispatchEmergencySession` channel.
     *  - `reconcileCurrentBoot` ACTION_MY_PACKAGE_REPLACED, ACTION_USER_UNLOCKED,
     *                         ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
     *                         and MainActivity's process-start reconcile (which
     *                         is what runs after a force-stop reopen).
     *  - `reconcileAfterBoot` BOOT_COMPLETED / LOCKED_BOOT_COMPLETED.
     *  - `reconcileAfterClockChange` TIME_SET / TIMEZONE_CHANGED.
     */
    @Test
    fun `every path reaches the same verdict at every boundary age`() {
        val limit = OverdueDispatchPolicy.MAX_OVERDUE_DISPATCH_MS
        val ages = listOf(
            -1L to Expected.NOT_DUE,
            0L to Expected.CALLED,
            1L to Expected.CALLED,
            limit - 1L to Expected.CALLED,
            limit to Expected.CALLED,
            limit + 1L to Expected.OFFERED,
            6L * 60_000L to Expected.OFFERED,
            3_600_000L to Expected.OFFERED,
        )
        val paths = listOf<Pair<String, (Harness, SessionToken) -> Unit>>(
            "claimAndDispatch" to { h, t -> h.coordinator.claimAndDispatch(t) },
            "reconcileCurrentBoot" to { h, _ -> h.coordinator.reconcileCurrentBoot() },
            "reconcileAfterBoot" to { h, _ -> h.coordinator.reconcileAfterBoot() },
            "reconcileAfterClockChange" to { h, _ -> h.coordinator.reconcileAfterClockChange() },
            "timezoneThenAlarm" to { h, t ->
                h.coordinator.reconcileAfterClockChange()
                h.coordinator.claimAndDispatch(t)
            },
        )
        val disagreements = mutableListOf<String>()
        for ((overdueBy, expected) in ages) {
            for ((name, run) in paths) {
                val harness = Harness()
                val token = harness.armAndAge(overdueBy)
                run(harness, token)
                val observed = harness.observed()
                if (observed != expected) {
                    disagreements += "age=${overdueBy}ms path=$name " +
                        "expected=$expected observed=$observed " +
                        "state=${harness.state()} calls=${harness.calls.targets.size}"
                }
            }
        }
        assertEquals(emptyList<String>(), disagreements)
    }

    /**
     * Reboot recovery. elapsedRealtime restarts at zero, so the persisted wall
     * deadline is the only reference that survives -- but it must be judged by
     * the SAME 5-minute rule, and a reboot must not be able to resurrect a
     * session that is hours old.
     */
    @Test
    fun `reboot recovery applies the same limit on the only clock it has`() {
        val limit = OverdueDispatchPolicy.MAX_OVERDUE_DISPATCH_MS
        val cases = listOf(
            -1L to Expected.NOT_DUE,
            0L to Expected.CALLED,
            limit to Expected.CALLED,
            limit + 1L to Expected.OFFERED,
            3_600_000L to Expected.OFFERED,
        )
        val disagreements = mutableListOf<String>()
        for ((overdueBy, expected) in cases) {
            val harness = Harness()
            harness.arm()
            // Reboot: new boot identity, elapsed clock restarted near zero, and
            // the wall clock is where the session's deadline already passed.
            harness.wall += sessionMs + overdueBy
            harness.boot += 1
            harness.elapsed = 9_000L

            harness.coordinator.reconcileAfterBoot()

            val observed = harness.observed()
            if (observed != expected) {
                disagreements += "reboot age=${overdueBy}ms expected=$expected " +
                    "observed=$observed state=${harness.state()}"
            }
        }
        assertEquals(emptyList<String>(), disagreements)
    }

    /**
     * Exact-alarm permission re-grant on a session that is still live. This is
     * the path OD-1 names first, and the one a user actually walks: Panic is
     * refused, they open Settings, grant "Alarms & reminders", come back.
     * Granting a permission must re-arm the session, never terminate it.
     */
    @Test
    fun `permission regrant on a live session re-arms it instead of ending it`() {
        val harness = Harness()
        harness.arm()
        harness.elapsed += 30_000L
        harness.wall += 30_000L

        // ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> reconcileCurrentBoot
        harness.coordinator.reconcileCurrentBoot()

        assertEquals(Expected.NOT_DUE, harness.observed())
        assertEquals(LifecycleState.ARMED, harness.state())
        assertEquals(
            "the regrant must put the exact alarm back",
            2,
            harness.alarms.scheduled.size,
        )
    }

    /**
     * Process-start reconcile after a force-stop (FS-01's fix) must obey the
     * limit too: force-stop deletes the alarms, so the record can be found
     * arbitrarily late, and that is exactly the "days later" case.
     */
    @Test
    fun `process start reconcile after a force stop obeys the limit`() {
        val fresh = Harness().apply {
            val token = armAndAge(60_000L)
            // Force-stop deleted the alarms; MainActivity.onCreate reconciles.
            coordinator.reconcileCurrentBoot()
            assertEquals(Expected.CALLED, observed())
            assertEquals(1, calls.targets.size)
            token
        }
        val stale = Harness().apply {
            armAndAge(26L * 3_600_000L)
            coordinator.reconcileCurrentBoot()
        }

        assertEquals(Expected.CALLED, fresh.observed())
        assertEquals(Expected.OFFERED, stale.observed())
        assertEquals(emptyList<String>(), stale.calls.targets)
    }

    /**
     * A record with no monotonic stamp at all (written before that field
     * existed, or seeded by the device probe) must still be judged -- on the
     * wall clock, which is all it has -- and not fall through into dialling.
     */
    @Test
    fun `a record without a monotonic stamp still obeys the limit`() {
        val harness = Harness()
        val token = harness.arm()
        val stamped = harness.store.current!!
        harness.store.current = stamped.copy(
            elapsedStampMs = -1L,
            elapsedRealtimeDeadlineMs = 0L,
        )
        harness.wall += sessionMs + 6L * 60_000L

        harness.coordinator.claimAndDispatch(token)

        assertEquals(Expected.OFFERED, harness.observed())
        assertEquals(emptyList<String>(), harness.calls.targets)
    }

    /** A cancelled or already terminal session is never resurrected. */
    @Test
    fun `a cancelled session is not dispatched or offered by any path`() {
        val limit = OverdueDispatchPolicy.MAX_OVERDUE_DISPATCH_MS
        for (overdueBy in listOf(0L, limit, limit + 1L, 3_600_000L)) {
            val harness = Harness()
            val token = harness.arm()
            harness.coordinator.cancel(token)
            harness.elapsed += sessionMs + overdueBy
            harness.wall += sessionMs + overdueBy

            harness.coordinator.claimAndDispatch(token)
            harness.coordinator.reconcileCurrentBoot()
            harness.coordinator.reconcileAfterBoot()
            harness.coordinator.reconcileAfterClockChange()

            assertEquals("age=$overdueBy", LifecycleState.CANCELLED, harness.state())
            assertEquals("age=$overdueBy", emptyList<String>(), harness.calls.targets)
            assertEquals(
                "age=$overdueBy",
                emptyList<FallbackReason>(),
                harness.fallback.reasons,
            )
        }
    }

    /** Duplicate delivery of the overdue offer must not produce two calls. */
    @Test
    fun `repeated delivery of an overdue record offers once and never dials`() {
        val harness = Harness()
        val token = harness.armAndAge(6L * 60_000L)

        harness.coordinator.claimAndDispatch(token)
        harness.coordinator.claimAndDispatch(token)
        harness.coordinator.reconcileCurrentBoot()
        harness.coordinator.claimAndDispatch(token)

        assertEquals(emptyList<String>(), harness.calls.targets)
        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, harness.state())
        assertEquals(
            listOf(FallbackReason.OVERDUE_NOT_DISPATCHED),
            harness.fallback.reasons,
        )
    }

    /**
     * Property: for a random age and a random order of the native events the OS
     * may deliver, a session more than the limit overdue never reaches Telecom,
     * and one inside the limit reaches it exactly once.
     */
    @Test
    fun `property -- random event orders never break the limit`() {
        val limit = OverdueDispatchPolicy.MAX_OVERDUE_DISPATCH_MS
        val random = Random(20261010)
        repeat(1_500) { iteration ->
            val overdueBy = random.nextLong(0L, 4L * limit)
            val harness = Harness()
            val token = harness.armAndAge(overdueBy)
            val events = listOf<(Harness) -> Unit>(
                { it.coordinator.claimAndDispatch(token) },
                { it.coordinator.reconcileCurrentBoot() },
                { it.coordinator.reconcileAfterBoot() },
                { it.coordinator.reconcileAfterClockChange() },
            ).shuffled(random)
            events.forEach { it(harness) }

            val context = "iteration=$iteration overdueBy=$overdueBy state=${harness.state()}"
            if (overdueBy > limit) {
                assertEquals(context, emptyList<String>(), harness.calls.targets)
                assertEquals(context, LifecycleState.MANUAL_ACTION_REQUIRED, harness.state())
            } else {
                assertEquals(context, listOf(TARGET), harness.calls.targets)
                assertEquals(
                    context,
                    LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED,
                    harness.state(),
                )
            }
        }
    }

    /**
     * Property: a random wall-clock jump inside one boot changes nothing. The
     * monotonic clock is the authority, so the user (or the network) moving the
     * wall clock cannot start, stop, lengthen or shorten a session.
     */
    @Test
    fun `property -- a wall clock jump inside one boot changes no verdict`() {
        val limit = OverdueDispatchPolicy.MAX_OVERDUE_DISPATCH_MS
        val random = Random(20261012)
        val day = 24L * 3_600_000L
        repeat(1_500) { iteration ->
            val overdueBy = random.nextLong(-sessionMs, 4L * limit)
            val jump = random.nextLong(-day, day)

            val reference = Harness().apply { armAndAge(overdueBy) }
            val jumped = Harness().apply {
                armAndAge(overdueBy)
                wall += jump
            }
            reference.coordinator.reconcileCurrentBoot()
            reference.coordinator.claimAndDispatch(reference.token!!)
            jumped.coordinator.reconcileCurrentBoot()
            jumped.coordinator.claimAndDispatch(jumped.token!!)

            assertEquals(
                "iteration=$iteration overdueBy=$overdueBy jump=$jump",
                reference.observed(),
                jumped.observed(),
            )
        }
    }

    /** What a path did, reduced to the only three outcomes that matter. */
    private enum class Expected { NOT_DUE, CALLED, OFFERED }

    /** Guards the reproduction itself: the harness really does arm and age. */
    @Test
    fun `harness sanity -- an un-aged session is not dispatchable`() {
        val harness = Harness()
        val token = harness.arm()

        harness.coordinator.claimAndDispatch(token)

        assertEquals(emptyList<String>(), harness.calls.targets)
        assertNotEquals(null, harness.store.current)
        assertEquals(LifecycleState.ARMED, harness.state())
    }

    private inner class Harness {
        var wall = now
        var elapsed = 50_000L
        var boot = 7
        var token: SessionToken? = null
        val store = FakeStore()
        val calls = FakeCalls()
        val alarms = FakeAlarms()
        val fallback = FakeFallback()
        val coordinator = EmergencySessionCoordinator(
            store = store,
            alarmScheduler = alarms,
            fallbackPoster = fallback,
            callRequester = calls,
            capabilityProvider = { request ->
                readyCapabilities.copy(
                    pinConfigured = request.pinConfigured,
                    callableTarget = EmergencyTargetValidator.isCallable(request.target),
                    entitlementDecision = request.entitlementDecision,
                )
            },
            wallClockMs = { wall },
            elapsedRealtimeMs = { elapsed },
            bootCount = { boot },
            bootId = { "boot-$boot" },
        )

        fun arm(): SessionToken = armRequest().also { token = it }

        private fun armRequest(): SessionToken = (
            coordinator.arm(
                ArmRequest(
                    protocolVersion = EMERGENCY_PROTOCOL_VERSION,
                    randomId = "od1-parity",
                    kind = SessionKind.CHECK_IN,
                    mainDeadlineMs = wall + sessionMs / 2,
                    finalDeadlineMs = wall + sessionMs,
                    target = TARGET,
                    entitlementDecision = EntitlementDecision.AUTHORIZED,
                    pinConfigured = true,
                ),
            ) as ArmResult.Armed
            ).token

        /** Both clocks move together, as they do on a real device. */
        fun armAndAge(overdueBy: Long): SessionToken {
            val token = arm()
            elapsed += sessionMs + overdueBy
            wall += sessionMs + overdueBy
            return token
        }

        fun state(): LifecycleState? = store.current?.lifecycleState

        /**
         * CALLED and OFFERED are read from the DURABLE record plus the call
         * log, not from a return value, because the question OD-1 asks is what
         * the session ended up being -- a receiver that loses a race returns
         * notAttempted while the record is already terminal.
         */
        fun observed(): Expected = when {
            calls.targets.isNotEmpty() -> Expected.CALLED
            fallback.reasons.contains(FallbackReason.OVERDUE_NOT_DISPATCHED) -> Expected.OFFERED
            else -> Expected.NOT_DUE
        }
    }

    private class FakeStore : EmergencySessionStore {
        /** Writable: one test seeds a record that carries no monotonic stamp. */
        var current: EmergencySessionEnvelope? = null

        override fun read(slot: SessionSlot): SessionRead =
            current
                ?.takeIf { it.token.slot == slot }
                ?.let { SessionRead.Present(it) }
                ?: SessionRead.Absent

        override fun write(envelope: EmergencySessionEnvelope): Boolean {
            current = envelope
            return true
        }

        override fun clearAll(): Boolean {
            current = null
            return true
        }
    }

    private class FakeAlarms : EmergencySessionAlarmScheduler {
        val scheduled = mutableListOf<EmergencySessionEnvelope>()

        override fun schedule(envelope: EmergencySessionEnvelope): AlarmScheduleResult {
            scheduled += envelope
            return AlarmScheduleResult(exactAccepted = true, inexactAccepted = true)
        }

        override fun cancel(token: SessionToken) = Unit
    }

    private class FakeFallback : EmergencyFallbackPoster {
        val reasons = mutableListOf<FallbackReason>()

        override fun post(
            envelope: EmergencySessionEnvelope,
            reason: FallbackReason,
        ): FallbackOutcome {
            reasons += reason
            return FallbackOutcome.POSTED
        }

        override fun clear(envelope: EmergencySessionEnvelope) = Unit
    }

    private class FakeCalls : EmergencyCallRequester {
        val targets = mutableListOf<String>()

        override fun requestCall(target: String): CallRequestOutcome {
            targets += target
            return CallRequestOutcome.SUBMITTED_UNCONFIRMED
        }
    }

    private companion object {
        const val TARGET = "+905001234567"
        val readyCapabilities = CapabilitySnapshot(
            supportedOs = true,
            telephonyCalling = true,
            telecomAvailable = true,
            dialHandlerAvailable = true,
            exactAlarmGranted = true,
            notificationsEnabled = true,
            alertChannelHigh = true,
            callPermissionGranted = true,
            pinConfigured = true,
            callableTarget = true,
            entitlementDecision = EntitlementDecision.AUTHORIZED,
        )
    }
}
