package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
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
    fun `elapsed deadline still dispatches after wall clock rollback`() {
        val fixture = Fixture()
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "clock-rollback-deadline"),
        ) as ArmResult.Armed

        fixture.reachElapsedDeadlineWithWallClockRolledBack()
        val result = fixture.coordinator.claimAndDispatch(armed.token)

        assertEquals(
            CallRequestOutcome.SUBMITTED_UNCONFIRMED,
            result.callRequestOutcome,
        )
        assertEquals(1, fixture.calls.targets.size)
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
    fun `posted fallback remains actionable when terminal commit is uncertain`() {
        val fixture = Fixture(
            // preparing=1, armed=2, claimed=3, fallback outcome=4, terminal=5
            store = FakeStore(failWritesAt = setOf(5)),
            fallback = FakeFallback(outcome = FallbackOutcome.POSTED),
            calls = FakeCalls(outcome = CallRequestOutcome.SUBMITTED_UNCONFIRMED),
        )
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "fallback-terminal-commit-failure"),
        ) as ArmResult.Armed
        fixture.advanceToFinalDeadline()

        val uncertain = fixture.coordinator.claimAndDispatch(armed.token)
        val retained = requireNotNull(fixture.store.current)

        assertEquals(LifecycleState.CLAIMED, uncertain.terminalState)
        assertEquals(LifecycleState.CLAIMED, retained.lifecycleState)
        assertEquals(FallbackOutcome.POSTED, retained.fallbackOutcome)
        assertEquals(
            "+905001234567",
            fixture.coordinator.consumeFallbackTarget(
                armed.token,
                retained.fallbackExpiresAtMs,
            ),
        )
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
    fun `boot reconciliation schedule exception publishes manual recovery`() {
        val fixture = Fixture(alarms = FakeAlarms(throwOnScheduleAt = setOf(2)))
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "boot-reconcile-schedule-failure"),
        ) as ArmResult.Armed

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(armed.token, fixture.store.current?.token)
        assertEquals(
            LifecycleState.MANUAL_ACTION_REQUIRED,
            fixture.store.current?.lifecycleState,
        )
        assertEquals(SchedulingMode.NONE, fixture.store.current?.schedulingMode)
        assertEquals(FallbackOutcome.POSTED, fixture.store.current?.fallbackOutcome)
        assertEquals(2, fixture.alarms.scheduleAttempts)
        assertEquals(1, fixture.fallback.postAttempts)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `boot reconciliation records inexact only recovery after exact access is revoked`() {
        val fixture = Fixture(
            alarms = FakeAlarms(
                scheduleResults = listOf(
                    AlarmScheduleResult(exactAccepted = true, inexactAccepted = true),
                    AlarmScheduleResult(exactAccepted = false, inexactAccepted = true),
                ),
            ),
        )
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "boot-reconcile-exact-revoked"),
        ) as ArmResult.Armed

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(armed.token, fixture.store.current?.token)
        assertEquals(LifecycleState.ARMED, fixture.store.current?.lifecycleState)
        assertEquals(SchedulingMode.INEXACT_ONLY, fixture.store.current?.schedulingMode)
        assertEquals(2, fixture.alarms.scheduleAttempts)
        assertEquals(0, fixture.fallback.postAttempts)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `boot rebase commit failure never schedules the stale elapsed deadline`() {
        val fixture = Fixture(store = FakeStore(failWritesAt = setOf(3)))
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "boot-rebase-commit-failure"),
        ) as ArmResult.Armed

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(armed.token, fixture.store.current?.token)
        assertEquals(
            LifecycleState.MANUAL_ACTION_REQUIRED,
            fixture.store.current?.lifecycleState,
        )
        assertEquals(SchedulingMode.NONE, fixture.store.current?.schedulingMode)
        assertEquals(1, fixture.alarms.scheduleAttempts)
        assertEquals(1, fixture.fallback.postAttempts)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `clock reconciliation schedule exception publishes manual recovery`() {
        val fixture = Fixture(alarms = FakeAlarms(throwOnScheduleAt = setOf(2)))
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "clock-reconcile-schedule-failure"),
        ) as ArmResult.Armed

        fixture.coordinator.reconcileAfterClockChange()

        assertEquals(armed.token, fixture.store.current?.token)
        assertEquals(
            LifecycleState.MANUAL_ACTION_REQUIRED,
            fixture.store.current?.lifecycleState,
        )
        assertEquals(SchedulingMode.NONE, fixture.store.current?.schedulingMode)
        assertEquals(FallbackOutcome.POSTED, fixture.store.current?.fallbackOutcome)
        assertEquals(2, fixture.alarms.scheduleAttempts)
        assertEquals(1, fixture.fallback.postAttempts)
        assertEquals(0, fixture.calls.targets.size)
    }

    @Test
    fun `boot recovery notification remains actionable across terminal commit failure`() {
        val store = FakeStore(failWritesAt = setOf(5))
        val fixture = Fixture(
            store = store,
            alarms = FakeAlarms(throwOnScheduleAt = setOf(2)),
        )
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "boot-recovery-crash-window"),
        ) as ArmResult.Armed

        fixture.coordinator.reconcileAfterBoot()
        val target = fixture.coordinator.consumeFallbackTarget(
            armed.token,
            now + FALLBACK_TARGET_RETENTION_MS,
        )

        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, store.current?.lifecycleState)
        assertEquals("+905001234567", target)
        assertEquals("", store.current?.target)
    }

    @Test
    fun `failed dial launch can restore the same consumed fallback`() {
        val fixture = Fixture()
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "dial-launch-failed"),
        ) as ArmResult.Armed
        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(armed.token)
        val expiresAtMs = requireNotNull(fixture.store.current).fallbackExpiresAtMs
        val target = requireNotNull(
            fixture.coordinator.consumeFallbackTarget(armed.token, expiresAtMs),
        )

        assertTrue(
            fixture.coordinator.restoreConsumedFallbackTarget(
                armed.token,
                expiresAtMs,
                target,
            ),
        )
        assertEquals(
            target,
            fixture.coordinator.consumeFallbackTarget(armed.token, expiresAtMs),
        )
    }

    @Test
    fun `boot reconciliation restores fallback cleanup for a terminal session`() {
        val fixture = Fixture()
        val armed = fixture.coordinator.arm(
            validArmRequest(randomId = "terminal-fallback-reboot"),
        ) as ArmResult.Armed
        fixture.advanceToFinalDeadline()
        fixture.coordinator.claimAndDispatch(armed.token)

        fixture.coordinator.reconcileAfterBoot()

        assertEquals(2, fixture.fallback.postAttempts)
        assertEquals(FallbackOutcome.POSTED, fixture.store.current?.fallbackOutcome)
        assertEquals("+905001234567", fixture.store.current?.target)
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
    ) {
        private var currentNow = now
        private var currentElapsed = 50_000L
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
            wallClockMs = { currentNow },
            elapsedRealtimeMs = { currentElapsed },
        )

        fun advanceToFinalDeadline() {
            currentNow = now + 120_000L
            currentElapsed = requireNotNull(store.current).elapsedRealtimeDeadlineMs
        }

        fun advanceTo(value: Long) {
            currentNow = value
            val envelope = store.current ?: return
            val wallDelta = (value - now).coerceAtLeast(0L)
            currentElapsed = 50_000L + wallDelta.coerceAtMost(
                envelope.elapsedRealtimeDeadlineMs - 50_000L,
            )
        }

        fun reachElapsedDeadlineWithWallClockRolledBack() {
            currentElapsed = requireNotNull(store.current).elapsedRealtimeDeadlineMs
            currentNow = now - 60_000L
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
        private val scheduleResults: List<AlarmScheduleResult> = emptyList(),
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
            return scheduleResults.getOrNull(scheduleAttempts - 1)
                ?: AlarmScheduleResult(exactAccepted = true, inexactAccepted = true)
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

        override fun post(envelope: EmergencySessionEnvelope): FallbackOutcome {
            postAttempts += 1
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
