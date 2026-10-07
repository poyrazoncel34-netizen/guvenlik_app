package com.poyrazoncel.korubeni.emergency

import java.util.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * Randomized interleavings against the PRODUCTION coordinator.
 *
 * EmergencySessionReferenceModelTest explores a toy model that never touches
 * EmergencySessionCoordinator, so its invariants can only fail if the toy is
 * wrong. Here every operation goes through the real arm / cancel /
 * claimAndDispatch / reconcile* / wipe code, with independent wall and
 * monotonic clocks, injected store-commit failures, reboots and process death,
 * and the safety invariants are checked after every single step.
 */
class EmergencySessionCoordinatorInterleavingTest {

    @Test
    fun `randomized interleavings never break the dispatch invariants`() {
        var traces = 0
        var stuckPathVisits = 0
        for (seed in 0 until SEEDS) {
            val random = Random(0x4B42_0000L + seed)
            repeat(TRACES_PER_SEED) { trace ->
                val harness = Harness(random, "seed=$seed trace=$trace")
                harness.run(STEPS_PER_TRACE)
                stuckPathVisits += harness.wallBehindDueReconciles
                traces += 1
            }
        }
        assertEquals(SEEDS * TRACES_PER_SEED, traces)
        // Non-vacuity: the "due by the monotonic clock, wall clock behind"
        // reconcile -- the path that used to leave a session stuck ARMED --
        // must actually be reached, or the liveness check proves nothing.
        assertTrue("stuck-path never reached ($stuckPathVisits)", stuckPathVisits > 50)
    }

    private class Harness(private val random: Random, private val label: String) {
        var wall = 1_700_000_000_000L
        var elapsed = 3_600_000L
        val store = Store()
        val calls = mutableListOf<String>()
        var coordinator = newCoordinator()

        private var counter = 0
        private val targetById = mutableMapOf<String, String>()
        private val callsAtCancel = mutableMapOf<String, Int>()
        private val maxGenerationById = mutableMapOf<String, Long>()
        private var processEpoch = 0
        private val callsInEpoch = mutableMapOf<Pair<String, Int>, Int>()
        private var pendingTimeSet = false
        var wallBehindDueReconciles = 0
        private var timeSetReconciled = false
        private val log = mutableListOf<String>()

        fun newCoordinator() = EmergencySessionCoordinator(
            store = store,
            alarmScheduler = Alarms(),
            fallbackPoster = object : EmergencyFallbackPoster {
                override fun post(
                    envelope: EmergencySessionEnvelope,
                    reason: FallbackReason,
                ) = FallbackOutcome.POSTED
            },
            callRequester = { target ->
                calls += target
                CallRequestOutcome.SUBMITTED_UNCONFIRMED
            },
            capabilityProvider = { request ->
                READY.copy(
                    pinConfigured = request.pinConfigured,
                    callableTarget = EmergencyTargetValidator.isCallable(request.target),
                    entitlementDecision = request.entitlementDecision,
                )
            },
            wallClockMs = { wall },
            elapsedRealtimeMs = { elapsed },
        )

        fun run(steps: Int) {
            repeat(steps) { step ->
                val before = snapshot()
                val callsBefore = calls.size
                val faultsBefore = store.injectedFaults
                val op = random.nextInt(14)
                timeSetReconciled = false
                try {
                    perform(op)
                } catch (e: RuntimeException) {
                    fail("$label step=$step op=$op threw ${e.javaClass.simpleName}\n${log.joinToString("\n")}")
                }
                log += "op=$op wall=$wall elapsed=$elapsed calls=${calls.size}"
                checkInvariants(step, op, before, callsBefore)
                if (timeSetReconciled && store.injectedFaults == faultsBefore) {
                    checkTimeSetLiveness(step, op)
                }
            }
        }

        private fun kind() = if (random.nextBoolean()) SessionKind.PANIC else SessionKind.CHECK_IN

        private fun current(kind: SessionKind) =
            (store.read(kind.slot) as? SessionRead.Present)?.envelope

        private fun perform(op: Int) {
            when (op) {
                0, 1 -> armNew(kind())
                2 -> revise(kind())
                3 -> current(kind())?.let { recordCancel(it.token, coordinator.cancel(it.token)) }
                4 -> current(kind())?.let { env ->
                    val stale = env.token.copy(generation = env.token.generation - 1)
                    coordinator.cancel(stale)
                }
                5, 6 -> current(kind())?.let { dispatch(it.token) }
                7 -> current(kind())?.let { env ->
                    dispatch(env.token.copy(generation = env.token.generation - 1))
                }
                8 -> {
                    val delta = random.nextInt(90_000).toLong()
                    wall += delta
                    elapsed += delta
                }
                9 -> {
                    // Wall clock set by the user or network; TIME_SET may lag.
                    wall += random.nextInt(4 * 3_600_000).toLong() - 2 * 3_600_000L
                    if (random.nextBoolean()) {
                        countWallBehindDue()
                        coordinator.reconcileAfterClockChange()
                        timeSetReconciled = true
                    } else {
                        pendingTimeSet = true
                    }
                }
                10 -> if (pendingTimeSet) {
                    pendingTimeSet = false
                    countWallBehindDue()
                    coordinator.reconcileAfterClockChange()
                    timeSetReconciled = true
                } else {
                    coordinator.reconcileCurrentBoot()
                }
                11 -> {
                    // Reboot: the monotonic clock restarts and the process is new.
                    processDeath()
                    elapsed = random.nextInt(60_000).toLong()
                    wall += random.nextInt(120_000).toLong()
                    coordinator.reconcileAfterBoot()
                }
                // Fail the 1st, 2nd or 3rd next commit: claimAndDispatch writes
                // CLAIMED, then the fallback state, then the terminal record.
                12 -> store.failWriteIn = 1 + random.nextInt(3)
                13 -> if (random.nextInt(4) == 0) coordinator.wipe() else processDeath()
            }
        }

        private fun countWallBehindDue() {
            for (slot in SessionSlot.entries) {
                val env = (store.read(slot) as? SessionRead.Present)?.envelope ?: continue
                if (env.lifecycleState == LifecycleState.ARMED &&
                    elapsed >= env.elapsedRealtimeDeadlineMs &&
                    wall < env.finalDeadlineMs
                ) {
                    wallBehindDueReconciles += 1
                }
            }
        }

        private fun armNew(kind: SessionKind) {
            counter += 1
            val id = "id-$counter-${kind.wireValue}"
            val target = "+90500" + (1_000_000 + counter).toString()
            val main = wall + 1_000L + random.nextInt(60_000)
            val final = main + random.nextInt(60_000)
            val result = coordinator.arm(
                ArmRequest(
                    protocolVersion = EMERGENCY_PROTOCOL_VERSION,
                    randomId = id,
                    kind = kind,
                    mainDeadlineMs = main,
                    finalDeadlineMs = final,
                    target = target,
                    entitlementDecision = EntitlementDecision.AUTHORIZED,
                    pinConfigured = true,
                    requestedGeneration = 1L,
                ),
            )
            if (result is ArmResult.Armed) targetById[id] = target
        }

        private fun revise(kind: SessionKind) {
            val env = current(kind) ?: return
            if (env.lifecycleState != LifecycleState.ARMED) return
            val main = wall + 1_000L + random.nextInt(60_000)
            coordinator.arm(
                ArmRequest(
                    protocolVersion = EMERGENCY_PROTOCOL_VERSION,
                    randomId = env.token.randomId,
                    kind = kind,
                    mainDeadlineMs = main,
                    finalDeadlineMs = main + random.nextInt(60_000),
                    target = env.target,
                    entitlementDecision = EntitlementDecision.AUTHORIZED,
                    pinConfigured = true,
                    requestedGeneration = env.token.generation + 1L,
                ),
            )
        }

        private fun recordCancel(token: SessionToken, result: CancelResult) {
            if (result is CancelResult.Cancelled) {
                callsAtCancel[token.randomId] = calls.count { it == targetById[token.randomId] }
            }
        }

        private fun dispatch(token: SessionToken) {
            coordinator.claimAndDispatch(token)
        }



        private fun processDeath() {
            processEpoch += 1
            listOf("submittedInProcess", "retryScheduledInProcess").forEach { name ->
                val field = EmergencySessionCoordinator::class.java.getDeclaredField(name)
                field.isAccessible = true
                (field.get(null) as MutableSet<*>).clear()
            }
            coordinator = newCoordinator()
        }

        /**
         * Liveness: once TIME_SET has been reconciled without an injected
         * commit failure, no session that is due by the monotonic clock may
         * still be ARMED. Before the fix a backward wall step left exactly that
         * state behind, with its ELAPSED alarm already spent.
         */
        private fun checkTimeSetLiveness(step: Int, op: Int) {
            for (slot in SessionSlot.entries) {
                val env = (store.read(slot) as? SessionRead.Present)?.envelope ?: continue
                if (env.lifecycleState == LifecycleState.ARMED &&
                    elapsed >= env.elapsedRealtimeDeadlineMs
                ) {
                    fail(
                        "$label step=$step op=$op: ${env.token.randomId} due by the " +
                            "monotonic clock but still ARMED after TIME_SET " +
                            "[gen=${env.token.generation} main=${env.mainDeadlineMs} " +
                            "final=${env.finalDeadlineMs} elapsedDeadline=" +
                            "${env.elapsedRealtimeDeadlineMs} wall=$wall elapsed=$elapsed " +
                            "pendingFault=${store.failWriteIn}]\n" +
                            log.takeLast(25).joinToString("\n"),
                    )
                }
            }
        }

        private data class Snap(val envs: Map<SessionSlot, EmergencySessionEnvelope?>, val wall: Long, val elapsed: Long)

        private fun snapshot() = Snap(
            SessionSlot.entries.associateWith { (store.read(it) as? SessionRead.Present)?.envelope },
            wall,
            elapsed,
        )

        private fun checkInvariants(step: Int, op: Int, before: Snap, callsBefore: Int) {
            fun violated(what: String): Nothing =
                fail("$label step=$step op=$op: $what\n${log.takeLast(25).joinToString("\n")}") as Nothing

            for ((id, target) in targetById) {
                val n = calls.count { it == target }
                callsAtCancel[id]?.let { if (n > it) violated("$id called after a confirmed cancel") }
            }
            calls.drop(callsBefore).forEach { target ->
                val id = targetById.entries.firstOrNull { it.value == target }?.key
                    ?: violated("call to a number that was never armed: $target")
                // At most one request per process lifetime. A request whose
                // terminal commit failed leaves the slot CLAIMED, and a NEW
                // process retrying it is the coordinator's documented
                // at-least-once window -- so the bound is per epoch.
                val key = id to processEpoch
                val inEpoch = (callsInEpoch[key] ?: 0) + 1
                callsInEpoch[key] = inEpoch
                if (inEpoch > 1) violated("$id requested $inEpoch calls in one process")
                // A durably terminal session is never dialled again.
                val prior = before.envs.values.firstOrNull { it?.token?.randomId == id }
                if (prior != null && prior.lifecycleState.isTerminal) {
                    violated("$id dialled again after a terminal commit (${prior.lifecycleState})")
                }
                // Never early by BOTH clocks, judged on what the store held
                // before this step (deadlines may legitimately be rebased).
                val env = before.envs.values.firstOrNull { it?.token?.randomId == id }
                if (env != null &&
                    env.lifecycleState == LifecycleState.ARMED &&
                    before.wall < env.finalDeadlineMs &&
                    before.elapsed < env.elapsedRealtimeDeadlineMs &&
                    op != 11 // after a reboot the old monotonic deadline is meaningless
                ) {
                    violated("$id dispatched before its deadline by both clocks")
                }
            }
            for (slot in SessionSlot.entries) {
                val env = (store.read(slot) as? SessionRead.Present)?.envelope ?: continue
                if (env.lifecycleState == LifecycleState.CANCELLED && env.target.isNotEmpty()) {
                    violated("cancelled envelope still holds a target")
                }
                val id = env.token.randomId
                val previous = maxGenerationById[id] ?: 0L
                if (env.token.generation < previous) violated("$id generation went backwards")
                maxGenerationById[id] = env.token.generation
                if (env.target.isNotEmpty() && targetById[id] != null && env.target != targetById[id]) {
                    violated("$id target changed under an armed session")
                }
            }
        }
    }

    private class Store : EmergencySessionStore {
        private val slots = mutableMapOf<SessionSlot, EmergencySessionEnvelope>()

        /** 0 = healthy; n > 0 = the n-th commit from now fails, once. */
        var failWriteIn = 0

        /** Commits that actually failed so far (for fault-free checks). */
        var injectedFaults = 0

        private fun commitFails(): Boolean {
            if (failWriteIn == 0) return false
            failWriteIn -= 1
            if (failWriteIn == 0) injectedFaults += 1
            return failWriteIn == 0
        }

        override fun read(slot: SessionSlot): SessionRead =
            slots[slot]?.let { SessionRead.Present(it) } ?: SessionRead.Absent

        override fun write(envelope: EmergencySessionEnvelope): Boolean {
            if (commitFails()) return false
            slots[envelope.token.slot] = envelope
            return true
        }

        override fun clearAll(): Boolean {
            if (commitFails()) return false
            slots.clear()
            return true
        }
    }

    private class Alarms : EmergencySessionAlarmScheduler {
        override fun schedule(envelope: EmergencySessionEnvelope) =
            AlarmScheduleResult(exactAccepted = true, inexactAccepted = true)

        override fun cancel(token: SessionToken) = Unit
    }

    private companion object {
        const val SEEDS = 10
        const val TRACES_PER_SEED = 400
        const val STEPS_PER_TRACE = 60

        val READY = CapabilitySnapshot(
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
