package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmergencySessionCoordinatorTest {
    private val now = 1_700_000_000_000L

    @Test
    fun `arm is not acknowledged when ARMED commit is uncertain`() {
        val fixture = Fixture(store = FakeStore(failWritesAt = setOf(2)))

        val result = fixture.coordinator.arm(validArmRequest())

        assertTrue(result is ArmResult.Unknown)
        assertEquals(1, fixture.alarms.cancelled.size)
        assertEquals(LifecycleState.PREPARING, fixture.store.current?.lifecycleState)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `PREPARING commit failure produces no alarm or external side effect`() {
        val fixture = Fixture(store = FakeStore(failWritesAt = setOf(1)))

        val result = fixture.coordinator.arm(validArmRequest(randomId = "preparing-commit-failure"))

        assertTrue(result is ArmResult.Unknown)
        assertEquals("preparingCommitFailed", (result as ArmResult.Unknown).reasonCode)
        assertEquals(null, fixture.store.current)
        assertEquals(0, fixture.alarms.scheduled.size)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `capability provider exception returns typed unknown without arming`() {
        val fixture = Fixture(
            capabilityFailure = SecurityException("injected capability failure"),
        )

        val result = fixture.coordinator.arm(
            validArmRequest(randomId = "capability-provider-failure"),
        )

        assertTrue(result is ArmResult.Unknown)
        assertEquals("capabilityReadFailed", (result as ArmResult.Unknown).reasonCode)
        assertEquals(null, fixture.store.current)
        assertEquals(0, fixture.alarms.scheduleAttempts)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `alarm schedule and rollback cancel exceptions return a typed rejection`() {
        val fixture = Fixture(
            alarms = FakeAlarms(
                throwOnSchedule = true,
                throwOnCancel = true,
            ),
        )

        val result = fixture.coordinator.arm(validArmRequest())

        assertTrue(result is ArmResult.Rejected)
        assertEquals("exactAlarmScheduleFailed", (result as ArmResult.Rejected).reasonCode)
        assertEquals(LifecycleState.CANCELLED, fixture.store.current?.lifecycleState)
        assertEquals("", fixture.store.current?.target)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `durable cancelled tombstone suppresses a late receiver`() {
        val fixture = Fixture()
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed

        assertTrue(fixture.coordinator.cancel(armed.token) is CancelResult.Cancelled)
        fixture.advanceToFinalDeadline()
        val dispatch = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, dispatch.callRequestOutcome)
        assertEquals(FallbackOutcome.NOT_ATTEMPTED, dispatch.fallbackOutcome)
        assertEquals(LifecycleState.CANCELLED, fixture.store.current?.lifecycleState)
        assertEquals("", fixture.store.current?.target)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `cancel commit failure is unknown and never a false cancellation acknowledgment`() {
        val fixture = Fixture(store = FakeStore(failWritesAt = setOf(3)))
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "cancel-commit-failure"),
        ) as ArmResult.Armed

        val cancel = fixture.coordinator.cancel(armed.token)

        assertTrue(cancel is CancelResult.Unknown)
        assertEquals("cancelCommitFailed", (cancel as CancelResult.Unknown).reasonCode)
        assertEquals(LifecycleState.ARMED, fixture.store.current?.lifecycleState)
        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(armed.token)
        assertEquals(1, fixture.calls.targets.size)
    }

    @Test
    fun `old generation cannot dispatch after a new arm`() {
        val fixture = Fixture()
        val first = fixture.coordinator.arm(validArmRequest(randomId = "first-id")) as ArmResult.Armed
        assertTrue(fixture.coordinator.cancel(first.token) is CancelResult.Cancelled)
        val second = fixture.coordinator.arm(validArmRequest(randomId = "second-id")) as ArmResult.Armed

        fixture.advanceToFinalDeadline()
        val stale = fixture.coordinator.claimAndDispatch(first.token)

        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, stale.callRequestOutcome)
        assertEquals(second.token, fixture.store.current?.token)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `duplicate normal delivery submits at most one call request`() {
        val fixture = Fixture()
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed

        fixture.advanceToFinalDeadline()
        val first = fixture.coordinator.claimAndDispatch(armed.token)
        val duplicate = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, first.callRequestOutcome)
        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, duplicate.callRequestOutcome)
        assertEquals(FallbackOutcome.POSTED, duplicate.fallbackOutcome)
        assertEquals(LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED, duplicate.terminalState)
        assertEquals(listOf("+905001234567"), fixture.calls.targets)
    }

    @Test
    fun `race loser reads durable terminal outcome without a second request`() {
        val fixture = Fixture()
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed

        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(armed.token)
        val loser = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, loser.callRequestOutcome)
        assertEquals(FallbackOutcome.POSTED, loser.fallbackOutcome)
        assertEquals(listOf("+905001234567"), fixture.calls.targets)
    }

    @Test
    fun `actionable fallback is attempted before Telecom request`() {
        val order = mutableListOf<String>()
        val fixture = Fixture(
            fallback = FakeFallback(order),
            calls = FakeCalls(order),
        )
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed

        fixture.advanceToFinalDeadline()
        val result = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(listOf("fallback", "call"), order)
        assertEquals(FallbackOutcome.POSTED, result.fallbackOutcome)
        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, result.callRequestOutcome)
        assertEquals(ConnectionState.UNKNOWN, result.connectionState)
    }

    @Test
    fun `terminal dispatch result survives alarm cancellation exception`() {
        val fixture = Fixture(alarms = FakeAlarms(throwOnCancel = true))
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val result = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, result.callRequestOutcome)
        assertEquals(LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED, result.terminalState)
        assertEquals(LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED, fixture.store.current?.lifecycleState)
        assertEquals(listOf("+905001234567"), fixture.calls.targets)
    }

    @Test
    fun `notification exception still attempts Telecom and records failed fallback`() {
        val fixture = Fixture(fallback = FakeFallback(throwOnPost = true))
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val result = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(FallbackOutcome.FAILED, result.fallbackOutcome)
        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, result.callRequestOutcome)
        assertEquals(LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED, result.terminalState)
        assertEquals(listOf("+905001234567"), fixture.calls.targets)
    }

    @Test
    fun `Telecom exception after permission revoke preserves actionable fallback`() {
        val fixture = Fixture(calls = FakeCalls(throwOnRequest = true))
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val result = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(FallbackOutcome.POSTED, result.fallbackOutcome)
        assertEquals(CallRequestOutcome.FAILED, result.callRequestOutcome)
        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, result.terminalState)
        assertEquals("+905001234567", fixture.store.current?.target)
    }

    @Test
    fun `notification and Telecom exceptions become durable request failed`() {
        val fixture = Fixture(
            fallback = FakeFallback(throwOnPost = true),
            calls = FakeCalls(throwOnRequest = true),
        )
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val result = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(FallbackOutcome.FAILED, result.fallbackOutcome)
        assertEquals(CallRequestOutcome.FAILED, result.callRequestOutcome)
        assertEquals(LifecycleState.REQUEST_FAILED, result.terminalState)
        assertEquals("", fixture.store.current?.target)
    }

    @Test
    fun `uncommitted fallback is never reported as actionable`() {
        val fixture = Fixture(
            // preparing=1, armed=2, claimed=3, fallback outcome=4
            store = FakeStore(failWritesAt = setOf(4)),
            fallback = FakeFallback(outcome = FallbackOutcome.POSTED),
            calls = FakeCalls(outcome = CallRequestOutcome.FAILED),
        )
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val result = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(FallbackOutcome.FAILED, result.fallbackOutcome)
        assertEquals(CallRequestOutcome.FAILED, result.callRequestOutcome)
        assertEquals(LifecycleState.REQUEST_FAILED, result.terminalState)
        assertEquals("", fixture.store.current?.target)
        assertEquals(listOf("+905001234567"), fixture.calls.targets)
    }

    @Test
    fun `CLAIMED commit failure performs neither fallback nor Telecom request`() {
        val fixture = Fixture(store = FakeStore(failWritesAt = setOf(3)))
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "claimed-commit-failure"),
        ) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val result = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(LifecycleState.ARMED, result.terminalState)
        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, result.callRequestOutcome)
        assertEquals(FallbackOutcome.NOT_ATTEMPTED, result.fallbackOutcome)
        assertEquals(LifecycleState.ARMED, fixture.store.current?.lifecycleState)
        assertEquals(0, fixture.fallback.postAttempts)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `failed side effects plus terminal commit failure receive one bounded retry`() {
        val fixture = Fixture(
            store = FakeStore(failWritesAt = setOf(5)),
            fallback = FakeFallback(outcome = FallbackOutcome.FAILED),
            calls = FakeCalls(outcome = CallRequestOutcome.FAILED),
        )
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val uncertain = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(LifecycleState.CLAIMED, uncertain.terminalState)
        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, uncertain.callRequestOutcome)
        assertEquals(2, fixture.alarms.scheduled.size)
        assertEquals(1, fixture.calls.targets.size)

        val retried = fixture.coordinator.claimAndDispatch(armed.token)
        assertEquals(LifecycleState.REQUEST_FAILED, retried.terminalState)
        assertEquals(2, fixture.calls.targets.size)
    }

    @Test
    fun `retry schedule exception preserves claimed state and allows caller retry`() {
        val fixture = Fixture(
            store = FakeStore(failWritesAt = setOf(5)),
            alarms = FakeAlarms(throwOnScheduleAt = setOf(2)),
            fallback = FakeFallback(outcome = FallbackOutcome.FAILED),
            calls = FakeCalls(outcome = CallRequestOutcome.FAILED),
        )
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "retry-schedule-failure"),
        ) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val uncertain = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(LifecycleState.CLAIMED, uncertain.terminalState)
        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, uncertain.callRequestOutcome)
        assertEquals(LifecycleState.CLAIMED, fixture.store.current?.lifecycleState)
        assertEquals(2, fixture.alarms.scheduleAttempts)
        assertEquals(1, fixture.alarms.scheduled.size)

        val retried = fixture.coordinator.claimAndDispatch(armed.token)
        assertEquals(LifecycleState.REQUEST_FAILED, retried.terminalState)
        assertEquals(2, fixture.calls.targets.size)
    }

    @Test
    fun `submitted request plus terminal commit failure is not duplicated in process`() {
        val fixture = Fixture(
            store = FakeStore(failWritesAt = setOf(5)),
            fallback = FakeFallback(outcome = FallbackOutcome.FAILED),
            calls = FakeCalls(outcome = CallRequestOutcome.SUBMITTED_UNCONFIRMED),
        )
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val uncertain = fixture.coordinator.claimAndDispatch(armed.token)
        val duplicate = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(LifecycleState.CLAIMED, uncertain.terminalState)
        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, uncertain.callRequestOutcome)
        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, duplicate.callRequestOutcome)
        assertEquals(1, fixture.calls.targets.size)
        assertEquals(1, fixture.alarms.scheduled.size)
    }

    @Test
    fun `process death after CLAIMED commit retries from durable state`() {
        val store = FakeStore(crashAfterWritesAt = setOf(3))
        val firstCalls = FakeCalls()
        val first = Fixture(store = store, calls = firstCalls)
        val armed = first.coordinator.arm(
            validArmRequest(randomId = "death-after-claim"),
        ) as ArmResult.Armed
        first.advanceToFinalDeadline()

        assertProcessDeath { first.coordinator.claimAndDispatch(armed.token) }
        assertEquals(LifecycleState.CLAIMED, store.current?.lifecycleState)
        assertEquals(0, first.fallback.postAttempts)
        assertEquals(0, firstCalls.targets.size)

        val recoveredCalls = FakeCalls()
        val recovered = Fixture(store = store, calls = recoveredCalls)
        val result = recovered.coordinator.claimAndDispatch(armed.token)

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, result.callRequestOutcome)
        assertEquals(1, recoveredCalls.targets.size)
    }

    @Test
    fun `process death before Telecom side effect retries one request`() {
        val store = FakeStore()
        val firstCalls = FakeCalls(crashBeforeRequest = true)
        val first = Fixture(store = store, calls = firstCalls)
        val armed = first.coordinator.arm(
            validArmRequest(randomId = "death-before-request"),
        ) as ArmResult.Armed
        first.advanceToFinalDeadline()

        assertProcessDeath { first.coordinator.claimAndDispatch(armed.token) }
        assertEquals(LifecycleState.CLAIMED, store.current?.lifecycleState)
        assertEquals(0, firstCalls.targets.size)

        val recoveredCalls = FakeCalls()
        val recovered = Fixture(store = store, calls = recoveredCalls)
        val result = recovered.coordinator.claimAndDispatch(armed.token)

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, result.callRequestOutcome)
        assertEquals(1, recoveredCalls.targets.size)
    }

    @Test
    fun `process death after Telecom side effect exposes documented duplicate window`() {
        val store = FakeStore()
        val firstCalls = FakeCalls(crashAfterRequest = true)
        val first = Fixture(store = store, calls = firstCalls)
        val armed = first.coordinator.arm(
            validArmRequest(randomId = "death-after-request"),
        ) as ArmResult.Armed
        first.advanceToFinalDeadline()

        assertProcessDeath { first.coordinator.claimAndDispatch(armed.token) }
        assertEquals(LifecycleState.CLAIMED, store.current?.lifecycleState)
        assertEquals(1, firstCalls.targets.size)

        val recoveredCalls = FakeCalls()
        val recovered = Fixture(store = store, calls = recoveredCalls)
        val result = recovered.coordinator.claimAndDispatch(armed.token)

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, result.callRequestOutcome)
        assertEquals(1, recoveredCalls.targets.size)
        assertEquals(
            2,
            firstCalls.targets.size + recoveredCalls.targets.size,
            // The disk/Telecom transaction is irreducibly non-atomic. The
            // safety contract prefers a duplicate over a silently missed
            // emergency request after a real process death.
        )
    }

    @Test
    fun `process death after terminal commit does not repeat Telecom request`() {
        val store = FakeStore(crashAfterWritesAt = setOf(5))
        val firstCalls = FakeCalls()
        val first = Fixture(store = store, calls = firstCalls)
        val armed = first.coordinator.arm(
            validArmRequest(randomId = "death-after-terminal"),
        ) as ArmResult.Armed
        first.advanceToFinalDeadline()

        assertProcessDeath { first.coordinator.claimAndDispatch(armed.token) }
        assertEquals(LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED, store.current?.lifecycleState)
        assertEquals(1, firstCalls.targets.size)

        val recoveredCalls = FakeCalls()
        val recovered = Fixture(store = store, calls = recoveredCalls)
        val result = recovered.coordinator.claimAndDispatch(armed.token)

        assertEquals(CallRequestOutcome.SUBMITTED_UNCONFIRMED, result.callRequestOutcome)
        assertEquals(LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED, result.terminalState)
        assertEquals(0, recoveredCalls.targets.size)
    }

    @Test
    fun `boot reconciliation schedule exception preserves durable armed session`() {
        val fixture = Fixture(alarms = FakeAlarms(throwOnScheduleAt = setOf(2)))
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "boot-reconcile-schedule-failure"),
        ) as ArmResult.Armed

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(armed.token, fixture.store.current?.token)
        assertEquals(LifecycleState.ARMED, fixture.store.current?.lifecycleState)
        assertEquals(2, fixture.alarms.scheduleAttempts)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `clock reconciliation schedule exception preserves durable armed session`() {
        val fixture = Fixture(alarms = FakeAlarms(throwOnScheduleAt = setOf(2)))
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "clock-reconcile-schedule-failure"),
        ) as ArmResult.Armed

        fixture.coordinator.reconcileAfterClockChange()

        assertEquals(armed.token, fixture.store.current?.token)
        assertEquals(LifecycleState.ARMED, fixture.store.current?.lifecycleState)
        assertEquals(2, fixture.alarms.scheduleAttempts)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `clock set back at the deadline still dispatches once elapsed time is up`() {
        // Independent wall and monotonic clocks: the shared Fixture pins the
        // monotonic one, which is exactly what hides this race.
        var wall = now
        var elapsed = 50_000L
        val store = FakeStore()
        val calls = FakeCalls()
        val coordinator = EmergencySessionCoordinator(
            store = store,
            alarmScheduler = FakeAlarms(),
            fallbackPoster = FakeFallback(),
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
        )
        val armed = coordinator.arm(
            validArmRequest(randomId = "clock-set-back-at-deadline"),
        ) as ArmResult.Armed

        // The full 120 s pass on the monotonic clock, but the wall clock was set
        // back one hour moments before the deadline...
        elapsed += 120_000L
        wall = now + 120_000L - 3_600_000L
        // ...and the ELAPSED_REALTIME alarm beats the TIME_SET broadcast. The
        // wall-clock gate refuses it, and that alarm is now spent.
        val early = coordinator.claimAndDispatch(armed.token)
        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, early.callRequestOutcome)

        // TIME_SET arrives. The duration is over by the monotonic clock, which is
        // the clock this reconciliation exists to honour.
        coordinator.reconcileAfterClockChange()

        assertEquals(listOf("+905001234567"), calls.targets)
        assertEquals(LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED, store.current?.lifecycleState)
    }

    @Test
    fun `clock change long after a missed deadline offers instead of dialling`() {
        var wall = now
        var elapsed = 50_000L
        val store = FakeStore()
        val calls = FakeCalls()
        val fallback = FakeFallback()
        val coordinator = EmergencySessionCoordinator(
            store = store,
            alarmScheduler = FakeAlarms(),
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
        )
        coordinator.arm(validArmRequest(randomId = "clock-change-long-overdue"))

        // Ten minutes past the monotonic deadline with no dispatch, then a
        // clock change: the same freshness policy as reboot reconciliation.
        elapsed += 120_000L + 10L * 60_000L
        wall = now - 3_600_000L
        coordinator.reconcileAfterClockChange()

        assertEquals(0, calls.targets.size)
        assertEquals(listOf(FallbackReason.OVERDUE_NOT_DISPATCHED), fallback.reasons)
        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, store.current?.lifecycleState)
    }

    // Audit A-02. The elapsed-realtime deadline is only meaningful in the boot
    // that wrote it, and nothing ordered TIME_SET after the boot reconcile:
    // ClockChangeReceiver is direct-boot aware and TIME_SET travels on the
    // foreground broadcast queue while LOCKED_BOOT_COMPLETED is delivered
    // serially to every direct-boot receiver. When TIME_SET won, the previous
    // boot's elapsed deadline (uptime + remaining) was read against an elapsed
    // clock that had restarted at zero, pushing the session out by the whole
    // previous uptime -- days, on a phone that rarely reboots.
    private inner class BootClocks(
        var wall: Long = now,
        var elapsed: Long = 3L * 24L * 3_600_000L,
        var boot: Int = 41,
        val store: FakeStore = FakeStore(),
    ) {
        var bootReadFails = false
        /** Kernel boot id (`/proc/sys/kernel/random/boot_id`); null = unreadable. */
        var bootId: String? = "boot-$boot"
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
            bootCount = {
                if (bootReadFails) throw IllegalStateException("settings unavailable")
                boot
            },
            bootId = { bootId },
        )

        /** Reboot: a new boot identity and an elapsed clock restarted near zero. */
        fun reboot(atWall: Long, elapsedSinceBoot: Long) {
            boot += 1
            bootId = bootId?.let { "boot-$boot" }
            wall = atWall
            elapsed = elapsedSinceBoot
        }
    }

    @Test
    fun `TIME_SET in a new boot before the boot reconcile does not inherit the old uptime`() {
        val clocks = BootClocks()
        clocks.coordinator.arm(validArmRequest(randomId = "time-set-before-boot"))

        // Rebooted a minute later; network time nudges the clock by +500 ms and
        // its TIME_SET reaches the app before LOCKED_BOOT_COMPLETED.
        clocks.reboot(atWall = now + 60_500L, elapsedSinceBoot = 30_000L)
        clocks.coordinator.reconcileAfterClockChange()

        val afterClockChange = clocks.store.current!!.finalDeadlineMs
        assertTrue(
            "final deadline moved by ${(afterClockChange - (now + 120_000L)) / 3_600_000L} h",
            afterClockChange <= now + 121_000L,
        )
        clocks.coordinator.reconcileAfterBoot()
        assertEquals(LifecycleState.ARMED, clocks.store.current?.lifecycleState)
        assertTrue(clocks.store.current!!.finalDeadlineMs <= now + 121_000L)
        assertEquals(0, clocks.calls.targets.size)
    }

    @Test
    fun `a deadline missed across a reboot still dispatches when TIME_SET arrives first`() {
        val clocks = BootClocks()
        clocks.coordinator.arm(validArmRequest(randomId = "missed-across-reboot"))

        // Off for the deadline; back 80 s after it -- inside the 5 minute
        // automatic window the boot path honours.
        clocks.reboot(atWall = now + 200_000L, elapsedSinceBoot = 20_000L)
        clocks.coordinator.reconcileAfterClockChange()
        clocks.coordinator.reconcileAfterBoot()

        assertEquals(listOf("+905001234567"), clocks.calls.targets)
        assertEquals(
            LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED,
            clocks.store.current?.lifecycleState,
        )
    }

    @Test
    fun `boot and TIME_SET order changes the deadline by at most the clock correction`() {
        fun finalDeadline(timeSetFirst: Boolean): Long {
            val clocks = BootClocks()
            clocks.coordinator.arm(validArmRequest(randomId = "order-$timeSetFirst"))
            clocks.reboot(atWall = now + 60_000L, elapsedSinceBoot = 30_000L)
            val correction = 500L
            if (timeSetFirst) {
                clocks.wall += correction
                clocks.coordinator.reconcileAfterClockChange()
                clocks.coordinator.reconcileAfterBoot()
            } else {
                clocks.coordinator.reconcileAfterBoot()
                clocks.wall += correction
                clocks.coordinator.reconcileAfterClockChange()
            }
            return clocks.store.current!!.finalDeadlineMs
        }

        val difference = kotlin.math.abs(finalDeadline(true) - finalDeadline(false))
        assertTrue("order changed the deadline by $difference ms", difference <= 500L)
    }

    @Test
    fun `after the boot reconcile a clock change in that boot keeps the monotonic remaining`() {
        val clocks = BootClocks()
        clocks.coordinator.arm(validArmRequest(randomId = "boot-then-clock-change"))
        clocks.reboot(atWall = now + 60_000L, elapsedSinceBoot = 30_000L)
        clocks.coordinator.reconcileAfterBoot()

        // Same (new) boot: 10 s later the user sets the clock back one hour.
        // The boot reconcile must have re-tied the elapsed deadline to THIS
        // boot, or the change is mistaken for another reboot and applied.
        clocks.elapsed += 10_000L
        clocks.wall = now + 70_000L - 3_600_000L
        clocks.coordinator.reconcileAfterClockChange()

        assertEquals(clocks.wall + 50_000L, clocks.store.current!!.finalDeadlineMs)
    }

    @Test
    fun `an unlock-time reconcile in a new boot schedules a rebuilt elapsed deadline`() {
        val clocks = BootClocks()
        clocks.coordinator.arm(validArmRequest(randomId = "unlock-before-boot"))
        clocks.reboot(atWall = now + 60_000L, elapsedSinceBoot = 30_000L)

        // USER_UNLOCKED / package replace / exact-alarm grant, before the boot
        // reconcile: it used to schedule the old boot's elapsed deadline.
        clocks.coordinator.reconcileCurrentBoot()

        val scheduled = clocks.alarms.scheduled.last()
        assertEquals(30_000L + 60_000L, scheduled.elapsedRealtimeDeadlineMs)
        assertEquals(clocks.boot, clocks.store.current!!.elapsedBootCount)
    }

    @Test
    fun `TIME_SET first after a reboot long past the deadline offers instead of dialling`() {
        val clocks = BootClocks()
        clocks.coordinator.arm(validArmRequest(randomId = "time-set-long-overdue"))
        clocks.reboot(atWall = now + 120_000L + 10L * 60_000L, elapsedSinceBoot = 25_000L)

        clocks.coordinator.reconcileAfterClockChange()

        assertEquals(0, clocks.calls.targets.size)
        assertEquals(listOf(FallbackReason.OVERDUE_NOT_DISPATCHED), clocks.fallback.reasons)
        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, clocks.store.current?.lifecycleState)
    }

    @Test
    fun `an unreadable boot identity never blocks a due dispatch`() {
        val clocks = BootClocks()
        clocks.coordinator.arm(validArmRequest(randomId = "boot-read-throws"))
        clocks.reboot(atWall = now + 150_000L, elapsedSinceBoot = 20_000L)
        clocks.bootReadFails = true

        clocks.coordinator.reconcileAfterClockChange()
        clocks.coordinator.reconcileAfterBoot()

        assertEquals(listOf("+905001234567"), clocks.calls.targets)
    }

    @Test
    fun `a rebase whose commit fails still schedules the rebuilt deadline`() {
        // Writes: 1 PREPARING, 2 ARMED, 3 the rebase -- which fails.
        val clocks = BootClocks(store = FakeStore(failWritesAt = setOf(3)))
        clocks.coordinator.arm(validArmRequest(randomId = "rebase-commit-fails"))
        clocks.reboot(atWall = now + 60_000L, elapsedSinceBoot = 30_000L)

        clocks.coordinator.reconcileAfterClockChange()

        assertEquals(30_000L + 60_000L, clocks.alarms.scheduled.last().elapsedRealtimeDeadlineMs)
        assertEquals(41, clocks.store.current!!.elapsedBootCount)
    }

    // Audit A-02r (chaos audit 2026-10-08): with BOOT_COUNT unreadable and the
    // new boot already past the old elapsed stamp, neither signal proved a
    // reboot, the previous boot's elapsed deadline was trusted, and TIME_SET-
    // before-boot still moved the deadline -- by up to the session length, or
    // turned a days-overdue session into a fresh call. The kernel boot id is
    // a second identity that does not depend on Settings.
    @Test
    fun `with BOOT_COUNT unreadable the kernel boot id still tells a new boot`() {
        val clocks = BootClocks(elapsed = 50_000L)
        clocks.coordinator.arm(validArmRequest(randomId = "boot-id-only"))
        clocks.bootReadFails = true
        // New boot, uptime already past the old stamp; TIME_SET arrives first.
        clocks.reboot(atWall = now + 60_500L, elapsedSinceBoot = 70_000L)
        clocks.coordinator.reconcileAfterClockChange()

        assertTrue(
            "deadline moved to ${clocks.store.current!!.finalDeadlineMs - now} ms",
            clocks.store.current!!.finalDeadlineMs <= now + 121_000L,
        )
    }

    @Test
    fun `with only the boot id known a same-boot clock change keeps the remaining`() {
        val clocks = BootClocks(elapsed = 50_000L)
        clocks.bootReadFails = true
        clocks.coordinator.arm(validArmRequest(randomId = "boot-id-same-boot"))

        clocks.elapsed += 30_000L
        clocks.wall = now + 30_000L + 3_600_000L
        clocks.coordinator.reconcileAfterClockChange()

        assertEquals(clocks.wall + 90_000L, clocks.store.current!!.finalDeadlineMs)
        assertEquals(0, clocks.calls.targets.size)
    }

    // Review of A-02r: with both BOOT_COUNTs known the kernel boot id was never
    // consulted. BOOT_COUNT depends on when Settings increments it relative to
    // the boot receivers and on its write reaching disk; the kernel id is
    // unique per boot by construction, so it decides whenever both sides have it.
    @Test
    fun `an equal BOOT_COUNT does not hide a new boot the kernel id can see`() {
        val clocks = BootClocks(elapsed = 50_000L)
        clocks.coordinator.arm(validArmRequest(randomId = "stale-count"))
        clocks.reboot(atWall = now + 60_500L, elapsedSinceBoot = 70_000L)
        clocks.boot -= 1 // not incremented yet when TIME_SET arrives
        clocks.coordinator.reconcileAfterClockChange()

        assertTrue(
            "deadline moved to ${clocks.store.current!!.finalDeadlineMs - now} ms",
            clocks.store.current!!.finalDeadlineMs <= now + 121_000L,
        )
    }

    @Test
    fun `a BOOT_COUNT incremented after the boot reconcile keeps a same-boot clock change`() {
        val clocks = BootClocks(elapsed = 50_000L)
        clocks.coordinator.arm(validArmRequest(randomId = "late-count"))
        clocks.reboot(atWall = now + 60_000L, elapsedSinceBoot = 10_000L)
        clocks.boot -= 1
        clocks.coordinator.reconcileAfterBoot() // stamps the stale count
        clocks.boot += 1

        clocks.elapsed += 30_000L
        clocks.wall += 30_000L + 3_600_000L
        clocks.coordinator.reconcileAfterClockChange()

        val session = clocks.store.current!!
        assertEquals(LifecycleState.ARMED, session.lifecycleState)
        assertEquals(clocks.wall + 30_000L, session.finalDeadlineMs)
        assertEquals(0, clocks.calls.targets.size)
    }

    @Test
    fun `a record from before boot identities is stamped at the next current-boot reconcile`() {
        val clocks = BootClocks(elapsed = 50_000L)
        clocks.coordinator.arm(validArmRequest(randomId = "legacy-record"))
        val armed = clocks.store.current!!
        clocks.store.current = armed.copy(
            elapsedBootCount = UNKNOWN_BOOT_COUNT,
            elapsedBootId = "",
            elapsedStampMs = -1L,
        )

        clocks.elapsed += 10_000L
        clocks.wall += 10_000L
        clocks.coordinator.reconcileCurrentBoot()

        val upgraded = clocks.store.current!!
        assertEquals(clocks.boot, upgraded.elapsedBootCount)
        assertEquals(clocks.bootId, upgraded.elapsedBootId)
        assertEquals(clocks.elapsed, upgraded.elapsedStampMs)
        assertEquals(armed.finalDeadlineMs, upgraded.finalDeadlineMs)
        assertEquals(clocks.elapsed + 110_000L, upgraded.elapsedRealtimeDeadlineMs)

        // ...so the next reboot is recognised even if TIME_SET wins the race.
        clocks.reboot(atWall = now + 60_500L, elapsedSinceBoot = 90_000L)
        clocks.coordinator.reconcileAfterClockChange()
        assertTrue(clocks.store.current!!.finalDeadlineMs <= now + 121_000L)
    }

    @Test
    fun `whichever broadcast arrives first, a known boot identity gives the same deadline`() {
        val random = java.util.Random(20261008L)
        repeat(400) { case ->
            val armElapsed = 1_000L + random.nextInt(600_000)
            // Not within the correction of the 120 s deadline: there "due now"
            // in one order and "due in under a second" in the other is the
            // correction itself, not an ordering defect.
            var downtime = 5_000L + random.nextInt(200_000)
            if (kotlin.math.abs(downtime - 120_000L) < 2_000L) downtime += 4_000L
            val newUptime = 1_000L + random.nextInt(900_000)
            val correction = random.nextInt(2_001) - 1_000L
            // At least one identity readable in both boots.
            val countReadable = random.nextBoolean()
            val idReadable = !countReadable || random.nextBoolean()
            // Inconsistent identities too: a BOOT_COUNT not yet incremented
            // when the first broadcast of the new boot arrives.
            val countStale = countReadable && idReadable && random.nextInt(4) == 0

            fun finalDeadline(timeSetFirst: Boolean): Long {
                val clocks = BootClocks(elapsed = armElapsed)
                clocks.bootReadFails = !countReadable
                if (!idReadable) clocks.bootId = null
                clocks.coordinator.arm(validArmRequest(randomId = "order-$case-$timeSetFirst"))
                clocks.reboot(atWall = now + downtime, elapsedSinceBoot = newUptime)
                if (countStale) clocks.boot -= 1
                if (timeSetFirst) {
                    clocks.wall += correction
                    clocks.coordinator.reconcileAfterClockChange()
                    clocks.coordinator.reconcileAfterBoot()
                } else {
                    clocks.coordinator.reconcileAfterBoot()
                    clocks.wall += correction
                    clocks.coordinator.reconcileAfterClockChange()
                }
                val session = clocks.store.current!!
                return if (session.lifecycleState == LifecycleState.ARMED) {
                    session.finalDeadlineMs
                } else {
                    -session.lifecycleState.ordinal.toLong()
                }
            }

            val first = finalDeadline(true)
            val second = finalDeadline(false)
            if (first < 0 || second < 0) {
                assertEquals("case $case: terminal state differs by order", first, second)
            } else {
                assertTrue(
                    "case $case: order moved the deadline by ${first - second} ms",
                    kotlin.math.abs(first - second) <= kotlin.math.abs(correction),
                )
            }
        }
    }

    @Test
    fun `TIME_SET in the arming boot still keeps the monotonic remaining duration`() {
        val clocks = BootClocks(elapsed = 50_000L)
        clocks.coordinator.arm(validArmRequest(randomId = "same-boot-clock-change"))

        // Same boot: 30 s later the user sets the clock back one hour.
        clocks.elapsed += 30_000L
        clocks.wall = now + 30_000L - 3_600_000L
        clocks.coordinator.reconcileAfterClockChange()

        assertEquals(clocks.wall + 90_000L, clocks.store.current!!.finalDeadlineMs)
        assertEquals(0, clocks.calls.targets.size)
    }

    @Test
    fun `unattended arm is rejected when exact alarms are unavailable`() {
        val fixture = Fixture(
            capabilities = readyCapabilities.copy(exactAlarmGranted = false),
        )

        val result = fixture.coordinator.arm(validArmRequest())

        assertTrue(result is ArmResult.Rejected)
        assertEquals("exactAlarmDenied", (result as ArmResult.Rejected).reasonCode)
        assertEquals(0, fixture.alarms.scheduled.size)
        assertEquals(null, fixture.store.current)
    }

    // Y-11 review: CALL_PHONE was checked first, so with both refused the
    // panic got callPermissionDenied -- a dialer-only countdown -- instead of
    // the exact-alarm refusal that offers background protection.
    @Test
    fun `missing exact alarm outranks a refused call permission`() {
        val fixture = Fixture(
            capabilities = readyCapabilities.copy(
                exactAlarmGranted = false,
                callPermissionGranted = false,
            ),
        )

        val result = fixture.coordinator.arm(validArmRequest())

        assertEquals("exactAlarmDenied", (result as ArmResult.Rejected).reasonCode)
    }

    @Test
    fun `target is an immutable normalized snapshot for an armed generation`() {
        val fixture = Fixture()
        val request = validArmRequest(target = "+90 (500) 123-45-67")

        val armed = fixture.coordinator.arm(request) as ArmResult.Armed
        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(listOf("+905001234567"), fixture.calls.targets)
        assertFalse(fixture.calls.targets.contains(request.target))
    }

    @Test
    fun `arm rejects short long unicode and URI targets before scheduling`() {
        val invalidTargets = listOf(
            "112",
            "+1234567890123456",
            "１２３４５６７８９０",
            "+",
            "tel:+905001234567",
            "+905001234567;ext=123",
            "+905001234567\r\n999",
        )

        invalidTargets.forEach { target ->
            val fixture = Fixture()
            val result = fixture.coordinator.arm(validArmRequest(target = target))

            assertTrue(result is ArmResult.Rejected)
            assertEquals("invalidTarget", (result as ArmResult.Rejected).reasonCode)
            assertEquals(0, fixture.alarms.scheduled.size)
            assertEquals(null, fixture.store.current)
        }
    }

    @Test
    fun `deadline revision keeps old arm until the next generation is durable`() {
        val store = FakeStore(failWritesAt = setOf(3))
        val fixture = Fixture(store = store)
        val first = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        val oldEnvelope = store.current

        val revision = fixture.coordinator.arm(
            validArmRequest().copy(
                mainDeadlineMs = now + 180_000L,
                finalDeadlineMs = now + 240_000L,
                requestedGeneration = 2L,
            ),
        )

        assertTrue(revision is ArmResult.Unknown)
        assertEquals(first.token, store.current?.token)
        assertEquals(oldEnvelope, store.current)
    }

    @Test
    fun `deadline revision advances generation and stale old alarm is suppressed`() {
        val fixture = Fixture()
        val first = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        val revised = fixture.coordinator.arm(
            validArmRequest().copy(
                mainDeadlineMs = now + 180_000L,
                finalDeadlineMs = now + 240_000L,
                requestedGeneration = 2L,
            ),
        ) as ArmResult.Armed

        assertEquals(first.token.generation + 1L, revised.token.generation)
        fixture.advanceTo(now + 240_000L)
        val stale = fixture.coordinator.claimAndDispatch(first.token)

        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, stale.callRequestOutcome)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `deadline revision rejects a caller that did not bind the next generation`() {
        val fixture = Fixture()
        fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed

        val result = fixture.coordinator.arm(
            validArmRequest().copy(
                mainDeadlineMs = now + 180_000L,
                finalDeadlineMs = now + 240_000L,
                requestedGeneration = 1L,
            ),
        )

        assertTrue(result is ArmResult.Rejected)
        assertEquals("generationMismatch", (result as ArmResult.Rejected).reasonCode)
    }

    @Test
    fun `fallback action is fail closed after 24 hour retention even if cleanup alarm is late`() {
        val fixture = Fixture()
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(armed.token)
        val expiresAtMs = requireNotNull(fixture.store.current).fallbackExpiresAtMs

        fixture.advanceTo(now + 120_000L + FALLBACK_TARGET_RETENTION_MS + 1L)

        assertEquals(null, fixture.coordinator.consumeFallbackTarget(armed.token, expiresAtMs))
        assertEquals(FallbackOutcome.EXPIRED, fixture.store.current?.fallbackOutcome)
        assertEquals("", fixture.store.current?.target)
    }

    @Test
    fun `valid fallback action is consumed exactly once`() {
        val fixture = Fixture()
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(armed.token)
        val expiresAtMs = requireNotNull(fixture.store.current).fallbackExpiresAtMs

        assertEquals(
            "+905001234567",
            fixture.coordinator.consumeFallbackTarget(armed.token, expiresAtMs),
        )
        assertEquals(null, fixture.coordinator.consumeFallbackTarget(armed.token, expiresAtMs))
    }

    @Test
    fun `terminal session can be wiped and retained fallback actions are cleared`() {
        val fixture = Fixture()
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed
        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(armed.token)

        val result = fixture.coordinator.wipe()

        assertEquals(WipeStatus.COMPLETED, result.status)
        assertEquals(null, fixture.store.current)
        assertEquals(listOf(armed.token), fixture.fallback.cleared)
    }

    @Test
    fun `wipe completes after durable clear when alarm cancellation throws`() {
        val fixture = Fixture(alarms = FakeAlarms(throwOnCancel = true))
        val armed = fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed

        val result = fixture.coordinator.wipe()

        assertEquals(WipeStatus.COMPLETED, result.status)
        assertEquals(null, fixture.store.current)
        assertEquals(0, fixture.calls.targets.size)
        assertEquals(armed.token, fixture.alarms.cancelAttempts.single())
    }

    @Test
    fun `wipe clear failure remains unknown with a durable targetless tombstone`() {
        val fixture = Fixture(store = FakeStore(failClear = true))
        fixture.coordinator.arm(
            validArmRequest(randomId = "wipe-clear-failure"),
        ) as ArmResult.Armed

        val result = fixture.coordinator.wipe()

        assertEquals(WipeStatus.UNKNOWN, result.status)
        assertEquals("wipeCommitFailed", result.reasonCode)
        assertEquals(LifecycleState.CANCELLED, fixture.store.current?.lifecycleState)
        assertEquals("", fixture.store.current?.target)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `one thousand cancel versus receiver interleavings preserve acknowledged cancel`() {
        var violations = 0
        repeat(1_000) { iteration ->
            val fixture = Fixture()
            val armed = fixture.coordinator.arm(
                validArmRequest(randomId = "cancel-receiver-$iteration"),
            ) as ArmResult.Armed
            fixture.advanceToFinalDeadline()

            if (iteration % 2 == 0) {
                val cancel = fixture.coordinator.cancel(armed.token)
                fixture.coordinator.claimAndDispatch(armed.token)
                if (cancel !is CancelResult.Cancelled || fixture.calls.targets.isNotEmpty()) {
                    violations += 1
                }
            } else {
                fixture.coordinator.claimAndDispatch(armed.token)
                val cancel = fixture.coordinator.cancel(armed.token)
                if (cancel !is CancelResult.TooLate || fixture.calls.targets.size != 1) {
                    violations += 1
                }
            }
        }
        assertEquals(0, violations)
    }

    @Test
    fun `one thousand Dart receiver and exact inexact races submit once per generation`() {
        var violations = 0
        repeat(1_000) { iteration ->
            val dartReceiver = Fixture()
            val dartToken = (dartReceiver.coordinator.arm(
                validArmRequest(randomId = "dart-receiver-$iteration"),
            ) as ArmResult.Armed).token
            dartReceiver.advanceToFinalDeadline()
            dartReceiver.coordinator.claimAndDispatch(dartToken)
            dartReceiver.coordinator.claimAndDispatch(dartToken)

            val exactInexact = Fixture()
            val alarmToken = (exactInexact.coordinator.arm(
                validArmRequest(randomId = "exact-inexact-$iteration"),
            ) as ArmResult.Armed).token
            exactInexact.advanceToFinalDeadline()
            exactInexact.coordinator.claimAndDispatch(alarmToken)
            exactInexact.coordinator.claimAndDispatch(alarmToken)

            if (
                dartReceiver.calls.targets.size != 1 ||
                exactInexact.calls.targets.size != 1
            ) {
                violations += 1
            }
        }
        assertEquals(0, violations)
    }

    @Test
    fun `one thousand reset expiry and old new generation races stay fail closed`() {
        var violations = 0
        repeat(1_000) { iteration ->
            val resetExpiry = Fixture()
            val resetToken = (resetExpiry.coordinator.arm(
                validArmRequest(randomId = "reset-expiry-$iteration"),
            ) as ArmResult.Armed).token
            resetExpiry.advanceToFinalDeadline()
            if (iteration % 2 == 0) {
                resetExpiry.coordinator.wipe()
                resetExpiry.coordinator.claimAndDispatch(resetToken)
                if (resetExpiry.calls.targets.isNotEmpty()) violations += 1
            } else {
                resetExpiry.coordinator.claimAndDispatch(resetToken)
                resetExpiry.coordinator.wipe()
                if (resetExpiry.calls.targets.size != 1) violations += 1
            }

            val generationRace = Fixture()
            val first = generationRace.coordinator.arm(
                validArmRequest(randomId = "generation-$iteration"),
            ) as ArmResult.Armed
            val second = generationRace.coordinator.arm(
                validArmRequest(randomId = "generation-$iteration").copy(
                    mainDeadlineMs = now + 180_000L,
                    finalDeadlineMs = now + 240_000L,
                    requestedGeneration = 2L,
                ),
            ) as ArmResult.Armed
            generationRace.advanceTo(now + 240_000L)
            generationRace.coordinator.claimAndDispatch(first.token)
            generationRace.coordinator.claimAndDispatch(second.token)
            if (
                generationRace.calls.targets.size != 1 ||
                generationRace.store.current?.token != second.token
            ) {
                violations += 1
            }
        }
        assertEquals(0, violations)
    }

    @Test
    fun `native warnings survive controller recreation and duplicate alarms never call`() {
        for (kind in listOf(SessionKind.CHECK_IN, SessionKind.SAFE_WALK)) {
            val store = FakeStore()
            var posts = 0
            val poster = EmergencyWarningPoster { _, _ -> posts++; true }
            val first = Fixture(store = store, warningPoster = poster)
            val token = (first.coordinator.arm(validArmRequest(randomId = "warning-${kind}").copy(kind = kind)) as ArmResult.Armed).token
            val restored = Fixture(store = store, warningPoster = poster)
            if (kind == SessionKind.SAFE_WALK) {
                restored.advanceTo(now + 54_000L)
                assertEquals("posted", restored.coordinator.warn(token, true))
                assertEquals("posted", restored.coordinator.warn(token, true))
            }
            restored.advanceTo(now + 60_000L)
            assertEquals("posted", restored.coordinator.warn(token, false))
            assertEquals("posted", restored.coordinator.warn(token, false))
            assertEquals(if (kind == SessionKind.SAFE_WALK) 2 else 1, posts)
            assertEquals(0, restored.calls.targets.size)
            restored.advanceToFinalDeadline()
            restored.coordinator.claimAndDispatch(token)
            restored.coordinator.claimAndDispatch(token)
            assertEquals(1, restored.calls.targets.size)
        }
    }

    @Test
    fun `cancel revision stale warning and denied notification never claim delivery`() {
        var posts = 0
        val fixture = Fixture(warningPoster = EmergencyWarningPoster { _, _ -> posts++; false })
        val first = (fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed).token
        val next = (fixture.coordinator.arm(validArmRequest().copy(requestedGeneration = 2,
            mainDeadlineMs = now + 180_000L, finalDeadlineMs = now + 240_000L)) as ArmResult.Armed).token
        fixture.advanceTo(now + 180_000L)
        assertEquals("stale", fixture.coordinator.warn(first, false))
        assertEquals("failed", fixture.coordinator.warn(next, false))
        assertEquals("failed", fixture.coordinator.warn(next, false))
        assertEquals(1, posts)
        fixture.coordinator.cancel(next)
        assertEquals("stale", fixture.coordinator.warn(next, false))
        assertEquals(0, fixture.calls.targets.size)
    }

    // A-03 (owner decision 2026-10-09): the final warning is BEST EFFORT and
    // never moves or cancels the final deadline. A warning that was never
    // shown stays "notAttempted" in the record the terminal journal carries,
    // which is what the safety timeline reads to say so.
    @Test
    fun `a final warning that arrives too late is never shown and the call still goes once`() {
        var posts = 0
        val fixture = Fixture(warningPoster = EmergencyWarningPoster { _, _ -> posts++; true })
        val token = (fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed).token
        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(token)
        fixture.coordinator.claimAndDispatch(token)
        // The late grace alarm, after the dispatch already ran:
        assertEquals("stale", fixture.coordinator.warn(token, false))

        assertEquals(0, posts)
        assertEquals(1, fixture.calls.targets.size)
        assertEquals("notAttempted", fixture.store.current!!.graceWarningOutcome)
    }

    @Test
    fun `a late warning on a still-armed overdue session never cancels it`() {
        val fixture = Fixture(warningPoster = EmergencyWarningPoster { _, _ -> true })
        val token = (fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed).token
        fixture.advanceToFinalDeadline()
        assertEquals("stale", fixture.coordinator.warn(token, false))

        assertEquals(LifecycleState.ARMED, fixture.store.current!!.lifecycleState)
        fixture.coordinator.claimAndDispatch(token)
        assertEquals(1, fixture.calls.targets.size)
        assertEquals("notAttempted", fixture.store.current!!.graceWarningOutcome)
    }

    @Test
    fun `a warning the system refused to post is recorded as failed and the call still goes`() {
        val fixture = Fixture(warningPoster = EmergencyWarningPoster { _, _ -> false })
        val token = (fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed).token
        fixture.advanceTo(now + 60_000L)
        assertEquals("failed", fixture.coordinator.warn(token, false))
        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(token)

        assertEquals(1, fixture.calls.targets.size)
        assertEquals("failed", fixture.store.current!!.graceWarningOutcome)
    }

    @Test
    fun `warning durable claim failure posts nothing and retry preserves same generation`() {
        var posts = 0
        val fixture = Fixture(store = FakeStore(failWritesAt = setOf(3)),
            warningPoster = EmergencyWarningPoster { _, _ -> posts++; true })
        val token = (fixture.coordinator.arm(validArmRequest()) as ArmResult.Armed).token
        fixture.advanceTo(now + 60_000L)
        assertEquals("unknown", fixture.coordinator.warn(token, false))
        assertEquals(0, posts)
        assertEquals("posted", fixture.coordinator.warn(token, false))
        assertEquals(token, fixture.store.current?.token)
        assertEquals(1, posts)
    }

    @Test
    fun `warning claim committed then process death still warns on redelivery`() {
        // The claim write SUCCEEDS and the process dies before the post. The
        // durable outcome is left at "unknown", which is a CLAIM, not a result.
        // Treating it as terminal (the way a dispatch claim is) would swallow
        // the warning for this generation forever: the re-scheduled alarm fires
        // warn() again and the idempotency check would short-circuit. A missed
        // warning is the exact defect the native warning exists to prevent.
        val store = FakeStore(crashAfterWritesAt = setOf(3))
        var posts = 0
        val poster = EmergencyWarningPoster { _, _ -> posts++; true }
        val first = Fixture(store = store, warningPoster = poster)
        val token = (first.coordinator.arm(validArmRequest(randomId = "warn-crash")) as ArmResult.Armed).token
        first.advanceTo(now + 60_000L)
        assertThrows(SimulatedProcessDeath::class.java) {
            first.coordinator.warn(token, false)
        }
        assertEquals(0, posts)
        assertEquals("unknown", store.current?.graceWarningOutcome)

        // A fresh process picks up the same durable session and the alarm is
        // redelivered. The user must still get the warning.
        val restored = Fixture(store = store, warningPoster = poster)
        restored.advanceTo(now + 60_000L)
        assertEquals("posted", restored.coordinator.warn(token, false))
        assertEquals(1, posts)
        assertEquals(token, store.current?.token)
        // Still no call: a warning must never reach the final dispatch.
        assertEquals(0, restored.calls.targets.size)
        // And once it is a real result, it stays terminal -- no repeat storm.
        assertEquals("posted", restored.coordinator.warn(token, false))
        assertEquals(1, posts)
    }

    @Test
    fun `completion timestamp records delayed dispatch rather than planned deadline`() {
        val fixture = Fixture()
        val token = (fixture.coordinator.arm(validArmRequest(randomId = "delayed-completion")) as ArmResult.Armed).token
        fixture.advanceTo(now + 180_000L)
        fixture.coordinator.claimAndDispatch(token)
        assertEquals(now + 180_000L, fixture.store.current?.completedAtMs)
        fixture.advanceTo(now + 240_000L)
        fixture.coordinator.claimAndDispatch(token)
        assertEquals(now + 180_000L, fixture.store.current?.completedAtMs)
        assertEquals(1, fixture.calls.targets.size)
    }

    // ---- A-001: overdue sessions are offered, not dialled -------------------
    //
    // reconcile()'s ARMED branch had NO age limit: on app open (or boot,
    // package replace, user unlock) it dialled the emergency contact for a
    // countdown that had been interrupted days earlier. The owner set the
    // limit at 5 minutes on 2026-09-20.

    @Test
    fun `a session overdue beyond the limit is not dialled`() {
        val fixture = Fixture()
        fixture.coordinator.arm(validArmRequest(randomId = "overdue-not-dialled"))
        // One millisecond past the limit: the boundary itself is asserted
        // separately, so this cannot pass by being wildly over.
        fixture.advanceTo(now + 120_000L + EmergencySessionCoordinator.MAX_OVERDUE_DISPATCH_MS + 1L)

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(
            "no Telecom request may be made for a stale session",
            0,
            fixture.calls.targets.size,
        )
        assertEquals(
            LifecycleState.MANUAL_ACTION_REQUIRED,
            fixture.store.current?.lifecycleState,
        )
        assertEquals(FallbackOutcome.POSTED, fixture.store.current?.fallbackOutcome)
        assertEquals(
            CallRequestOutcome.NOT_ATTEMPTED,
            fixture.store.current?.callRequestOutcome,
        )
    }

    @Test
    fun `the overdue offer uses copy that does not promise an automatic call`() {
        val fixture = Fixture()
        fixture.coordinator.arm(validArmRequest(randomId = "overdue-copy"))
        fixture.advanceTo(now + 120_000L + EmergencySessionCoordinator.MAX_OVERDUE_DISPATCH_MS + 1L)

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(
            listOf(FallbackReason.OVERDUE_NOT_DISPATCHED),
            fixture.fallback.reasons,
        )
    }

    @Test
    fun `the target is retained so one tap can still place the call`() {
        val fixture = Fixture()
        fixture.coordinator.arm(validArmRequest(randomId = "overdue-target-kept"))
        fixture.advanceTo(now + 120_000L + EmergencySessionCoordinator.MAX_OVERDUE_DISPATCH_MS + 1L)

        fixture.coordinator.reconcileAfterBoot()

        // Refusing to dial automatically must not take the call AWAY from a
        // user who still wants it; that would trade one failure for another.
        assertEquals("+905001234567", fixture.store.current?.target)
    }

    @Test
    fun `a session inside the limit is still dialled automatically`() {
        val fixture = Fixture()
        fixture.coordinator.arm(validArmRequest(randomId = "overdue-within-limit"))
        // The control. A brief interruption -- a reboot -- must NOT be turned
        // into a notification the user has to notice.
        fixture.advanceTo(now + 120_000L + EmergencySessionCoordinator.MAX_OVERDUE_DISPATCH_MS - 1L)

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(1, fixture.calls.targets.size)
        assertEquals(
            LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED,
            fixture.store.current?.lifecycleState,
        )
    }

    @Test
    fun `exactly at the limit still dials`() {
        val fixture = Fixture()
        fixture.coordinator.arm(validArmRequest(randomId = "overdue-boundary"))
        // The comparison is strictly greater-than, so the limit itself is on
        // the dialling side. Pinned because an off-by-one here silently moves
        // the product decision.
        fixture.advanceTo(now + 120_000L + EmergencySessionCoordinator.MAX_OVERDUE_DISPATCH_MS)

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(1, fixture.calls.targets.size)
    }

    @Test
    fun `an unpostable overdue offer ends the session instead of dialling`() {
        val fixture = Fixture(fallback = FakeFallback(outcome = FallbackOutcome.FAILED))
        fixture.coordinator.arm(validArmRequest(randomId = "overdue-post-failed"))
        fixture.advanceTo(now + 120_000L + EmergencySessionCoordinator.MAX_OVERDUE_DISPATCH_MS + 1L)

        fixture.coordinator.reconcileAfterBoot()

        // Failing to REACH the user is not permission to call on their behalf.
        assertEquals(0, fixture.calls.targets.size)
        assertEquals(LifecycleState.REQUEST_FAILED, fixture.store.current?.lifecycleState)
        assertEquals("", fixture.store.current?.target)
    }

    @Test
    fun `a throwing notifier cannot make an overdue session dial`() {
        val fixture = Fixture(fallback = FakeFallback(throwOnPost = true))
        fixture.coordinator.arm(validArmRequest(randomId = "overdue-post-throws"))
        fixture.advanceTo(now + 120_000L + EmergencySessionCoordinator.MAX_OVERDUE_DISPATCH_MS + 1L)

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(0, fixture.calls.targets.size)
        assertEquals(LifecycleState.REQUEST_FAILED, fixture.store.current?.lifecycleState)
    }

    @Test
    fun `a stale CLAIMED session recovered after process death is offered not dialled`() {
        val store = FakeStore(crashAfterWritesAt = setOf(3))
        val interrupted = Fixture(store = store)
        val token = (
            interrupted.coordinator.arm(
                validArmRequest(randomId = "stale-claimed-process-death"),
            ) as ArmResult.Armed
        ).token
        interrupted.advanceToFinalDeadline()

        assertProcessDeath { interrupted.coordinator.claimAndDispatch(token) }
        assertEquals(LifecycleState.CLAIMED, store.current?.lifecycleState)
        assertEquals(0, interrupted.calls.targets.size)

        val recoveredCalls = FakeCalls()
        val recovered = Fixture(store = store, calls = recoveredCalls)
        recovered.advanceTo(
            now + 120_000L + EmergencySessionCoordinator.MAX_OVERDUE_DISPATCH_MS + 1L,
        )
        recovered.coordinator.reconcileAfterBoot()

        assertEquals(
            "a stale durable claim must never cause an automatic call on reopen or boot",
            0,
            recoveredCalls.targets.size,
        )
        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, store.current?.lifecycleState)
        assertEquals(FallbackOutcome.POSTED, store.current?.fallbackOutcome)
        assertEquals(CallRequestOutcome.NOT_ATTEMPTED, store.current?.callRequestOutcome)
    }

    @Test
    fun `a fresh CLAIMED session recovered after process death still dispatches`() {
        val store = FakeStore(crashAfterWritesAt = setOf(3))
        val interrupted = Fixture(store = store)
        val token = (
            interrupted.coordinator.arm(
                validArmRequest(randomId = "fresh-claimed-process-death"),
            ) as ArmResult.Armed
        ).token
        interrupted.advanceToFinalDeadline()

        assertProcessDeath { interrupted.coordinator.claimAndDispatch(token) }

        val recoveredCalls = FakeCalls()
        val recovered = Fixture(store = store, calls = recoveredCalls)
        recovered.advanceTo(now + 120_001L)
        recovered.coordinator.reconcileAfterBoot()

        assertEquals(1, recoveredCalls.targets.size)
        assertEquals(
            LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED,
            store.current?.lifecycleState,
        )
    }

    private fun validArmRequest(
        randomId: String = "session-random-id",
        target: String = "+905001234567",
    ) = ArmRequest(
        protocolVersion = EMERGENCY_PROTOCOL_VERSION,
        randomId = randomId,
        kind = SessionKind.CHECK_IN,
        mainDeadlineMs = now + 60_000,
        finalDeadlineMs = now + 120_000,
        target = target,
        entitlementDecision = EntitlementDecision.AUTHORIZED,
        pinConfigured = true,
    )

    private fun assertProcessDeath(block: () -> Unit) {
        var observed = false
        try {
            block()
        } catch (_: SimulatedProcessDeath) {
            observed = true
        }
        assertTrue("fault injector did not reach the declared process-death boundary", observed)
    }

    private inner class Fixture(
        val store: FakeStore = FakeStore(),
        val alarms: FakeAlarms = FakeAlarms(),
        val fallback: FakeFallback = FakeFallback(),
        val calls: FakeCalls = FakeCalls(),
        capabilities: CapabilitySnapshot = readyCapabilities,
        capabilityFailure: RuntimeException? = null,
        warningPoster: EmergencyWarningPoster = EmergencyWarningPoster { _, _ -> false },
    ) {
        private var currentNow = now
        val coordinator = EmergencySessionCoordinator(
            store = store,
            alarmScheduler = alarms,
            fallbackPoster = fallback,
            callRequester = calls,
            capabilityProvider = { request ->
                capabilityFailure?.let { throw it }
                capabilities.copy(
                    pinConfigured = request.pinConfigured,
                    callableTarget = EmergencyTargetValidator.isCallable(request.target),
                    entitlementDecision = request.entitlementDecision,
                )
            },
            warningPoster = warningPoster,
            wallClockMs = { currentNow },
            elapsedRealtimeMs = { 50_000L },
        )

        fun advanceToFinalDeadline() {
            currentNow = now + 120_000L
        }

        fun advanceTo(value: Long) {
            currentNow = value
        }
    }

    private class FakeStore(
        private val failWritesAt: Set<Int> = emptySet(),
        private val crashAfterWritesAt: Set<Int> = emptySet(),
        private val failClear: Boolean = false,
    ) : EmergencySessionStore {
        var current: EmergencySessionEnvelope? = null
        private var writes = 0

        override fun read(slot: SessionSlot): SessionRead =
            current
                ?.takeIf { it.token.slot == slot }
                ?.let { SessionRead.Present(it) }
                ?: SessionRead.Absent

        override fun write(envelope: EmergencySessionEnvelope): Boolean {
            writes += 1
            if (writes in failWritesAt) return false
            current = envelope
            if (writes in crashAfterWritesAt) throw SimulatedProcessDeath()
            return true
        }

        override fun clearAll(): Boolean {
            if (failClear) return false
            current = null
            return true
        }
    }

    private class FakeAlarms(
        private val throwOnSchedule: Boolean = false,
        private val throwOnCancel: Boolean = false,
        private val throwOnScheduleAt: Set<Int> = emptySet(),
    ) : EmergencySessionAlarmScheduler {
        val scheduled = mutableListOf<EmergencySessionEnvelope>()
        val cancelled = mutableListOf<SessionToken>()
        val cancelAttempts = mutableListOf<SessionToken>()
        var scheduleAttempts = 0

        override fun schedule(envelope: EmergencySessionEnvelope): AlarmScheduleResult {
            scheduleAttempts += 1
            if (throwOnSchedule || scheduleAttempts in throwOnScheduleAt) {
                throw IllegalStateException("injected schedule failure")
            }
            scheduled += envelope
            return AlarmScheduleResult(exactAccepted = true, inexactAccepted = true)
        }

        override fun cancel(token: SessionToken) {
            cancelAttempts += token
            if (throwOnCancel) throw IllegalStateException("injected cancel failure")
            cancelled += token
        }
    }

    private class FakeFallback(
        private val order: MutableList<String>? = null,
        private val outcome: FallbackOutcome = FallbackOutcome.POSTED,
        private val throwOnPost: Boolean = false,
    ) : EmergencyFallbackPoster {
        val cleared = mutableListOf<SessionToken>()
        var postAttempts = 0

        val reasons = mutableListOf<FallbackReason>()

        override fun post(
            envelope: EmergencySessionEnvelope,
            reason: FallbackReason,
        ): FallbackOutcome {
            postAttempts += 1
            reasons += reason
            order?.add("fallback")
            if (throwOnPost) throw IllegalStateException("injected notification failure")
            return outcome
        }

        override fun clear(envelope: EmergencySessionEnvelope) {
            cleared += envelope.token
        }
    }

    private class FakeCalls(
        private val order: MutableList<String>? = null,
        private val outcome: CallRequestOutcome = CallRequestOutcome.SUBMITTED_UNCONFIRMED,
        private val throwOnRequest: Boolean = false,
        private val crashBeforeRequest: Boolean = false,
        private val crashAfterRequest: Boolean = false,
    ) : EmergencyCallRequester {
        val targets = mutableListOf<String>()

        override fun requestCall(target: String): CallRequestOutcome {
            if (crashBeforeRequest) throw SimulatedProcessDeath()
            order?.add("call")
            targets += target
            if (crashAfterRequest) throw SimulatedProcessDeath()
            if (throwOnRequest) throw SecurityException("injected Telecom failure")
            return outcome
        }
    }

    private class SimulatedProcessDeath : Error()

    companion object {
        private val readyCapabilities = CapabilitySnapshot(
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
