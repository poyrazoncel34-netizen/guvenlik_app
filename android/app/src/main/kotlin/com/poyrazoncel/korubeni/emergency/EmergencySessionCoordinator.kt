package com.poyrazoncel.korubeni.emergency

/**
 * Single process authority for every safety-session transition.
 *
 * SharedPreferences and Telecom cannot participate in one atomic transaction.
 * The durable CLAIMED state therefore deliberately prefers an at-least-once
 * retry after process death. Inside one process, [submittedInProcess] prevents
 * a second Telecom request for the same generation. A crash after Telecom
 * accepted the request but before the terminal commit remains an explicit,
 * irreducible duplicate-request window; no code may describe this as exactly
 * once delivery or as a connected call.
 */
class EmergencySessionCoordinator(
    private val store: EmergencySessionStore,
    private val alarmScheduler: EmergencySessionAlarmScheduler,
    private val fallbackPoster: EmergencyFallbackPoster,
    private val callRequester: EmergencyCallRequester,
    private val capabilityProvider: EmergencyCapabilityProvider,
    private val wallClockMs: () -> Long = { System.currentTimeMillis() },
    private val elapsedRealtimeMs: () -> Long = { android.os.SystemClock.elapsedRealtime() },
) {
    fun arm(request: ArmRequest): ArmResult = synchronized(PROCESS_LOCK) {
        if (request.protocolVersion != EMERGENCY_PROTOCOL_VERSION) {
            return@synchronized ArmResult.Rejected("unsupportedProtocol")
        }
        if (!isValidRandomId(request.randomId)) {
            return@synchronized ArmResult.Rejected("invalidRandomId")
        }
        if (request.requestedGeneration <= 0L) {
            return@synchronized ArmResult.Rejected("invalidGeneration")
        }
        val now = wallClockMs()
        if (
            request.mainDeadlineMs <= now ||
            request.finalDeadlineMs < request.mainDeadlineMs
        ) {
            return@synchronized ArmResult.Rejected("invalidDeadline")
        }

        val normalizedTarget = EmergencyTargetValidator.normalizedCallableOrNull(request.target)
            ?: return@synchronized ArmResult.Rejected("invalidTarget")
        val normalizedRequest = request.copy(target = normalizedTarget)
        val capabilities = try {
            capabilityProvider.snapshot(normalizedRequest)
        } catch (_: RuntimeException) {
            // Capability discovery crosses several Android system-service
            // boundaries. A revoked permission, unavailable service, or OEM
            // implementation failure is uncertainty, never permission to arm
            // and never a reason to crash the safety flow.
            return@synchronized ArmResult.Unknown("capabilityReadFailed")
        }
        capabilities.rejectionReason()?.let {
            return@synchronized ArmResult.Rejected(it)
        }

        val existing = when (val read = store.read(request.kind.slot)) {
            SessionRead.Absent -> null
            is SessionRead.Corrupted -> return@synchronized ArmResult.Unknown(read.reasonCode)
            is SessionRead.Present -> read.envelope
        }

        var revisionFrom: EmergencySessionEnvelope? = null
        if (existing != null && existing.token.randomId == request.randomId) {
            if (
                existing.lifecycleState == LifecycleState.ARMED &&
                existing.token.kind == request.kind &&
                existing.mainDeadlineMs == request.mainDeadlineMs &&
                existing.finalDeadlineMs == request.finalDeadlineMs &&
                existing.target == normalizedTarget
            ) {
                if (request.requestedGeneration != existing.token.generation) {
                    return@synchronized ArmResult.Rejected("generationMismatch")
                }
                return@synchronized ArmResult.Armed(
                    existing.token,
                    existing.mainDeadlineMs,
                    existing.finalDeadlineMs,
                )
            }
            if (existing.lifecycleState == LifecycleState.ARMED) {
                if (existing.token.kind != request.kind || existing.target != normalizedTarget) {
                    return@synchronized ArmResult.Rejected("immutableTargetMismatch")
                }
                if (request.requestedGeneration != existing.token.generation + 1L) {
                    return@synchronized ArmResult.Rejected("generationMismatch")
                }
                revisionFrom = existing
            } else {
                return@synchronized ArmResult.Unknown("armReconciliationRequired")
            }
        }

        if (revisionFrom == null && existing?.lifecycleState in setOf(
                LifecycleState.PREPARING,
                LifecycleState.ARMED,
                LifecycleState.CLAIMED,
            )
        ) {
            return@synchronized ArmResult.Rejected("activeSessionExists")
        }

        val generation = revisionFrom?.token?.generation?.plus(1L) ?: 1L
        if (request.requestedGeneration != generation) {
            return@synchronized ArmResult.Rejected("generationMismatch")
        }
        val token = SessionToken(
            protocolVersion = EMERGENCY_PROTOCOL_VERSION,
            randomId = request.randomId,
            generation = generation,
            kind = request.kind,
        )
        val elapsedDeadline = elapsedRealtimeMs() +
            (request.finalDeadlineMs - now).coerceAtLeast(0L)
        val preparing = EmergencySessionEnvelope(
            token = token,
            lifecycleState = LifecycleState.PREPARING,
            target = normalizedTarget,
            mainDeadlineMs = request.mainDeadlineMs,
            finalDeadlineMs = request.finalDeadlineMs,
            elapsedRealtimeDeadlineMs = elapsedDeadline,
            schedulingMode = SchedulingMode.NONE,
        )
        if (revisionFrom == null && !store.write(preparing)) {
            return@synchronized ArmResult.Unknown("preparingCommitFailed")
        }

        val schedule = scheduleBestEffort(preparing)
        if (!schedule.exactAccepted) {
            cancelAlarmBestEffort(token)
            if (revisionFrom != null) {
                return@synchronized ArmResult.Rejected("exactAlarmScheduleFailed")
            }
            val tombstoneWritten = store.write(
                preparing.copy(
                    lifecycleState = LifecycleState.CANCELLED,
                    target = "",
                    schedulingMode = SchedulingMode.NONE,
                ),
            )
            return@synchronized if (tombstoneWritten) {
                ArmResult.Rejected("exactAlarmScheduleFailed")
            } else {
                ArmResult.Unknown("alarmRollbackCommitFailed")
            }
        }

        val armed = preparing.copy(
            lifecycleState = LifecycleState.ARMED,
            schedulingMode = if (schedule.inexactAccepted) {
                SchedulingMode.EXACT_AND_INEXACT
            } else {
                SchedulingMode.EXACT_ONLY
            },
        )
        if (!store.write(armed)) {
            // PREPARING is intentionally not dispatchable. Even if AlarmManager
            // delivers after cancel(), the generation/state guard suppresses it.
            cancelAlarmBestEffort(token)
            return@synchronized ArmResult.Unknown("armedCommitFailed")
        }
        revisionFrom?.let { cancelAlarmBestEffort(it.token) }
        // A newly durable generation has not dispatched in this process. This
        // also keeps deterministic test/runtime re-instantiation from treating
        // a genuinely fresh arm as a duplicate solely because its caller chose
        // the same external random id after the previous store was wiped.
        submittedInProcess.remove(token.processKey())
        retryScheduledInProcess.remove(token.processKey())
        ArmResult.Armed(token, request.mainDeadlineMs, request.finalDeadlineMs)
    }

    fun cancel(token: SessionToken): CancelResult = synchronized(PROCESS_LOCK) {
        if (token.protocolVersion != EMERGENCY_PROTOCOL_VERSION) {
            return@synchronized CancelResult.Unknown(token, "unsupportedProtocol")
        }
        val current = when (val read = store.read(token.slot)) {
            SessionRead.Absent -> return@synchronized CancelResult.Stale(token)
            is SessionRead.Corrupted -> return@synchronized CancelResult.Unknown(token, read.reasonCode)
            is SessionRead.Present -> read.envelope
        }
        if (current.token != token) {
            return@synchronized CancelResult.Stale(token)
        }
        when (current.lifecycleState) {
            LifecycleState.CANCELLED -> return@synchronized CancelResult.AlreadyCancelled(token)
            LifecycleState.CLAIMED,
            LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED,
            LifecycleState.MANUAL_ACTION_REQUIRED,
            LifecycleState.REQUEST_FAILED,
            -> return@synchronized CancelResult.TooLate(token, current.lifecycleState)
            LifecycleState.CORRUPTED ->
                return@synchronized CancelResult.Unknown(token, "corruptedSession")
            LifecycleState.PREPARING,
            LifecycleState.ARMED,
            -> Unit
        }

        val tombstone = current.copy(
            lifecycleState = LifecycleState.CANCELLED,
            target = "",
            callRequestOutcome = CallRequestOutcome.NOT_ATTEMPTED,
            fallbackOutcome = FallbackOutcome.NOT_ATTEMPTED,
            fallbackExpiresAtMs = 0L,
        )
        if (!store.write(tombstone)) {
            return@synchronized CancelResult.Unknown(token, "cancelCommitFailed")
        }
        // AlarmManager.cancel() is best effort. Correctness comes from the
        // already durable tombstone, not from this void-returning API.
        cancelAlarmBestEffort(token)
        CancelResult.Cancelled(token)
    }

    fun claimAndDispatch(token: SessionToken): DispatchResult = synchronized(PROCESS_LOCK) {
        if (token.protocolVersion != EMERGENCY_PROTOCOL_VERSION) {
            return@synchronized DispatchResult.notAttempted(token)
        }
        val current = when (val read = store.read(token.slot)) {
            SessionRead.Absent -> return@synchronized DispatchResult.notAttempted(token)
            is SessionRead.Corrupted -> return@synchronized DispatchResult.notAttempted(
                token,
                LifecycleState.CORRUPTED,
            )
            is SessionRead.Present -> read.envelope
        }
        if (current.token != token) {
            return@synchronized DispatchResult.notAttempted(token)
        }
        if (current.lifecycleState.isTerminal) {
            // A second caller may lose a Dart-vs-receiver or exact-vs-inexact
            // race after the first caller has already committed the outcome.
            // Return that durable truth so the loser does not open a second
            // dial path merely because it did not perform the side effect.
            return@synchronized DispatchResult(
                token = token,
                callRequestOutcome = current.callRequestOutcome,
                fallbackOutcome = current.fallbackOutcome,
                terminalState = current.lifecycleState,
            )
        }
        if (current.lifecycleState !in setOf(LifecycleState.ARMED, LifecycleState.CLAIMED)) {
            return@synchronized DispatchResult.notAttempted(token, current.lifecycleState)
        }
        // Alarms are scheduled against elapsed realtime.  Using wall time here
        // re-opened the session after a user/NTP clock rollback: the elapsed
        // alarm fired, but the claim was rejected forever because no second
        // delivery was scheduled.  The envelope's elapsed deadline is the
        // authoritative same-boot claim boundary; boot reconciliation derives
        // a fresh elapsed deadline from wall time after a reboot.
        if (
            current.lifecycleState == LifecycleState.ARMED &&
            elapsedRealtimeMs() < current.elapsedRealtimeDeadlineMs
        ) {
            return@synchronized DispatchResult.notAttempted(token, LifecycleState.ARMED)
        }

        val claimed = if (current.lifecycleState == LifecycleState.ARMED) {
            val next = current.copy(lifecycleState = LifecycleState.CLAIMED)
            if (!store.write(next)) {
                return@synchronized DispatchResult.notAttempted(token, LifecycleState.ARMED)
            }
            next
        } else {
            current
        }

        val processKey = token.processKey()
        if (processKey in submittedInProcess) {
            return@synchronized DispatchResult.notAttempted(token, LifecycleState.CLAIMED)
        }

        // The fallback is deliberately first. Any Telecom ambiguity still
        // leaves a user-action path rather than a silent "success".
        val intendedFallbackExpiry = wallClockMs() + FALLBACK_TARGET_RETENTION_MS
        val fallbackCandidate = claimed.copy(
            fallbackExpiresAtMs = intendedFallbackExpiry,
        )
        val fallbackOutcome = try {
            fallbackPoster.post(fallbackCandidate)
        } catch (_: RuntimeException) {
            FallbackOutcome.FAILED
        }
        val fallbackExpiry = if (fallbackOutcome == FallbackOutcome.POSTED) {
            intendedFallbackExpiry
        } else {
            0L
        }
        val claimedWithFallback = fallbackCandidate.copy(
            fallbackOutcome = fallbackOutcome,
            fallbackExpiresAtMs = fallbackExpiry,
        )
        // Persisting the fallback outcome narrows, but cannot remove, the
        // side-effect/commit crash window. Dispatch continues on failure to
        // prefer a possible emergency request over a false negative.
        val fallbackStateCommitted = store.write(claimedWithFallback)
        val effectiveFallbackOutcome = if (
            fallbackOutcome == FallbackOutcome.POSTED && !fallbackStateCommitted
        ) {
            // The immutable action cannot be authorized without its durable
            // state. A visible but dead notification is not an actionable
            // fallback and must not be reported as one.
            FallbackOutcome.FAILED
        } else {
            fallbackOutcome
        }

        val callOutcome = try {
            callRequester.requestCall(claimed.target)
        } catch (_: RuntimeException) {
            CallRequestOutcome.FAILED
        }
        val terminalState = when {
            callOutcome == CallRequestOutcome.SUBMITTED_UNCONFIRMED ->
                LifecycleState.REQUEST_SUBMITTED_UNCONFIRMED
            effectiveFallbackOutcome == FallbackOutcome.POSTED ->
                LifecycleState.MANUAL_ACTION_REQUIRED
            else -> LifecycleState.REQUEST_FAILED
        }
        val terminal = claimedWithFallback.copy(
            lifecycleState = terminalState,
            // The phone target remains only in the app-private Direct Boot
            // record while the user-action fallback is live. PendingIntents
            // carry token/TTL only and cannot disclose or replace the target.
            target = if (effectiveFallbackOutcome == FallbackOutcome.POSTED) {
                claimed.target
            } else {
                ""
            },
            callRequestOutcome = callOutcome,
            fallbackOutcome = effectiveFallbackOutcome,
            fallbackExpiresAtMs = if (
                effectiveFallbackOutcome == FallbackOutcome.POSTED
            ) {
                fallbackExpiry
            } else {
                0L
            },
        )
        val terminalCommitted = store.write(terminal)
        if (!terminalCommitted) {
            // Never return a terminal result that is absent from durable state.
            // If Telecom may have accepted the request, suppress an in-process
            // duplicate. If no call side effect occurred, keep the path live
            // and schedule one bounded retry instead of deadlocking CLAIMED.
            if (callOutcome == CallRequestOutcome.SUBMITTED_UNCONFIRMED) {
                submittedInProcess += processKey
                cancelAlarmBestEffort(token)
            } else {
                submittedInProcess.remove(processKey)
                if (retryScheduledInProcess.add(processKey)) {
                    val retryAtWall = wallClockMs() + DISPATCH_RETRY_DELAY_MS
                    val retryEnvelope = claimedWithFallback.copy(
                        mainDeadlineMs = retryAtWall,
                        finalDeadlineMs = retryAtWall,
                        elapsedRealtimeDeadlineMs =
                            elapsedRealtimeMs() + DISPATCH_RETRY_DELAY_MS,
                    )
                    val retrySchedule = scheduleBestEffort(retryEnvelope)
                    if (!retrySchedule.exactAccepted && !retrySchedule.inexactAccepted) {
                        // Do not let a failed attempt consume the one bounded
                        // retry. A later receiver/reconciler invocation may try
                        // dispatch again from the durable CLAIMED state.
                        retryScheduledInProcess.remove(processKey)
                    }
                }
            }
            return@synchronized DispatchResult.notAttempted(
                token,
                LifecycleState.CLAIMED,
            )
        }
        retryScheduledInProcess.remove(processKey)
        cancelAlarmBestEffort(token)

        DispatchResult(
            token = token,
            callRequestOutcome = callOutcome,
            fallbackOutcome = effectiveFallbackOutcome,
            terminalState = terminalState,
        )
    }

    fun read(kind: SessionKind): ReadSessionResult = synchronized(PROCESS_LOCK) {
        when (val read = store.read(kind.slot)) {
            SessionRead.Absent -> ReadSessionResult.Absent
            is SessionRead.Corrupted -> ReadSessionResult.Corrupted(read.reasonCode)
            is SessionRead.Present -> {
                var envelope = read.envelope
                if (
                    envelope.fallbackOutcome == FallbackOutcome.POSTED &&
                    envelope.fallbackExpiresAtMs > 0L &&
                    wallClockMs() >= envelope.fallbackExpiresAtMs
                ) {
                    val expired = envelope.copy(
                        target = "",
                        fallbackOutcome = FallbackOutcome.EXPIRED,
                        fallbackExpiresAtMs = 0L,
                    )
                    if (store.write(expired)) envelope = expired
                }
                ReadSessionResult.Present(envelope)
            }
        }
    }

    fun expireFallback(token: SessionToken): Boolean = synchronized(PROCESS_LOCK) {
        val current = (store.read(token.slot) as? SessionRead.Present)?.envelope
            ?: return@synchronized false
        val publishedCrashWindow = current.lifecycleState == LifecycleState.CLAIMED &&
            EmergencyTargetValidator.isCallable(current.target)
        val recoveryPublishedCrashWindow =
            current.lifecycleState == LifecycleState.ARMED &&
                current.schedulingMode == SchedulingMode.NONE &&
                EmergencyTargetValidator.isCallable(current.target)
        if (
            current.token != token ||
            (
                current.fallbackOutcome !in
                    setOf(FallbackOutcome.POSTED, FallbackOutcome.EXPIRED) &&
                    !publishedCrashWindow &&
                    !recoveryPublishedCrashWindow
                )
        ) {
            return@synchronized false
        }
        if (current.fallbackOutcome == FallbackOutcome.EXPIRED && current.target.isBlank()) {
            return@synchronized true
        }
        store.write(
            current.copy(
                lifecycleState = if (recoveryPublishedCrashWindow) {
                    LifecycleState.REQUEST_FAILED
                } else {
                    current.lifecycleState
                },
                target = "",
                fallbackOutcome = FallbackOutcome.EXPIRED,
                fallbackExpiresAtMs = 0L,
            ),
        )
    }

    /** Atomically validates and consumes a user-tapped fallback target. */
    fun consumeFallbackTarget(
        token: SessionToken,
        intendedExpiryMs: Long,
    ): String? = synchronized(PROCESS_LOCK) {
        val current = (store.read(token.slot) as? SessionRead.Present)?.envelope
            ?: return@synchronized null
        val now = wallClockMs()
        val terminalPosted = current.lifecycleState.isTerminal &&
            current.fallbackOutcome == FallbackOutcome.POSTED &&
            current.fallbackExpiresAtMs == intendedExpiryMs
        // The fallback outcome is committed before Telecom. If the process or
        // terminal write fails afterwards, CLAIMED + POSTED is still durable
        // authorization for the exact immutable token/expiry action. Rejecting
        // it would turn an already visible safety notification into a dead tap.
        val claimedPosted = current.lifecycleState == LifecycleState.CLAIMED &&
            current.fallbackOutcome == FallbackOutcome.POSTED &&
            current.fallbackExpiresAtMs == intendedExpiryMs
        // If the process died after publishing the immutable notification but
        // before recording POSTED, CLAIMED is the only admissible recovery
        // state. The PendingIntent's embedded expiry remains authoritative.
        val publishedCrashWindow = current.lifecycleState == LifecycleState.CLAIMED &&
            current.fallbackOutcome == FallbackOutcome.NOT_ATTEMPTED
        // Boot/clock reconciliation first commits ARMED+NONE before posting an
        // immediate recovery action. If the process dies after Notification
        // Manager accepts it but before the terminal commit, that durable NONE
        // marker authorizes only the exact token/expiry embedded in the action.
        val recoveryPublishedCrashWindow =
            current.lifecycleState == LifecycleState.ARMED &&
                current.schedulingMode == SchedulingMode.NONE &&
                current.fallbackOutcome == FallbackOutcome.NOT_ATTEMPTED
        if (
            current.token != token || intendedExpiryMs <= now ||
            intendedExpiryMs > now + FALLBACK_TARGET_RETENTION_MS ||
            (
                !terminalPosted && !claimedPosted && !publishedCrashWindow &&
                    !recoveryPublishedCrashWindow
                ) ||
            !EmergencyTargetValidator.isCallable(current.target)
        ) {
            if (
                current.token == token &&
                current.fallbackOutcome == FallbackOutcome.POSTED &&
                current.fallbackExpiresAtMs <= now
            ) {
                store.write(
                    current.copy(
                        target = "",
                        fallbackOutcome = FallbackOutcome.EXPIRED,
                        fallbackExpiresAtMs = 0L,
                    ),
                )
            }
            return@synchronized null
        }
        val target = current.target
        val consumed = store.write(
            current.copy(
                lifecycleState = if (publishedCrashWindow || recoveryPublishedCrashWindow) {
                    LifecycleState.MANUAL_ACTION_REQUIRED
                } else {
                    current.lifecycleState
                },
                target = "",
                fallbackOutcome = FallbackOutcome.EXPIRED,
                fallbackExpiresAtMs = 0L,
            ),
        )
        if (consumed) target else null
    }

    /** Restores the same immutable fallback when ACTION_DIAL could not open. */
    fun restoreConsumedFallbackTarget(
        token: SessionToken,
        intendedExpiryMs: Long,
        target: String,
    ): Boolean = synchronized(PROCESS_LOCK) {
        val normalized = EmergencyTargetValidator.normalizedCallableOrNull(target)
            ?: return@synchronized false
        val current = (store.read(token.slot) as? SessionRead.Present)?.envelope
            ?: return@synchronized false
        val now = wallClockMs()
        if (
            current.token != token ||
            !current.lifecycleState.isTerminal ||
            current.lifecycleState in setOf(
                LifecycleState.CANCELLED,
                LifecycleState.CORRUPTED,
            ) ||
            current.target.isNotBlank() ||
            current.fallbackOutcome != FallbackOutcome.EXPIRED ||
            intendedExpiryMs <= now ||
            intendedExpiryMs > now + FALLBACK_TARGET_RETENTION_MS
        ) {
            return@synchronized false
        }
        store.write(
            current.copy(
                target = normalized,
                fallbackOutcome = FallbackOutcome.POSTED,
                fallbackExpiresAtMs = intendedExpiryMs,
            ),
        )
    }

    /** Re-arms future alarms or dispatches elapsed ARMED/CLAIMED sessions. */
    fun reconcileAfterBoot() = reconcile(rebaseElapsedFromWall = true)

    /** Used for package replacement, unlock, and exact-permission grant. */
    fun reconcileCurrentBoot() = reconcile(rebaseElapsedFromWall = false)

    private fun reconcile(rebaseElapsedFromWall: Boolean) = synchronized(PROCESS_LOCK) {
        SessionSlot.entries.forEach { slot ->
            var envelope = (store.read(slot) as? SessionRead.Present)?.envelope ?: return@forEach
            when (envelope.lifecycleState) {
                LifecycleState.ARMED -> {
                    if (wallClockMs() >= envelope.finalDeadlineMs) {
                        claimAndDispatch(envelope.token)
                    } else {
                        if (rebaseElapsedFromWall) {
                            val rebased = envelope.copy(
                                elapsedRealtimeDeadlineMs = elapsedRealtimeMs() +
                                    (envelope.finalDeadlineMs - wallClockMs()).coerceAtLeast(0L),
                            )
                            if (!store.write(rebased)) {
                                publishSchedulingRecovery(rebased)
                                return@forEach
                            }
                            envelope = rebased
                        }
                        val schedule = scheduleBestEffort(envelope)
                        if (!schedule.exactAccepted && !schedule.inexactAccepted) {
                            publishSchedulingRecovery(envelope)
                        } else {
                            persistSchedulingMode(envelope, schedule)
                        }
                    }
                }
                LifecycleState.CLAIMED -> claimAndDispatch(envelope.token)
                LifecycleState.PREPARING -> {
                    // An interrupted arm is never promoted after reboot because
                    // AlarmManager acceptance was not durably acknowledged.
                    store.write(
                        envelope.copy(
                            lifecycleState = LifecycleState.CORRUPTED,
                            target = "",
                            schedulingMode = SchedulingMode.NONE,
                        ),
                    )
                    cancelAlarmBestEffort(envelope.token)
                }
                else -> reconcilePostedFallback(envelope)
            }
        }
    }

    private fun reconcilePostedFallback(envelope: EmergencySessionEnvelope) {
        if (
            envelope.fallbackOutcome != FallbackOutcome.POSTED ||
            !EmergencyTargetValidator.isCallable(envelope.target)
        ) {
            return
        }
        if (envelope.fallbackExpiresAtMs <= wallClockMs()) {
            expireFallback(envelope.token)
            return
        }
        val reposted = try {
            fallbackPoster.post(envelope)
        } catch (_: RuntimeException) {
            FallbackOutcome.FAILED
        }
        if (reposted != FallbackOutcome.POSTED) {
            store.write(
                envelope.copy(
                    target = "",
                    fallbackOutcome = FallbackOutcome.FAILED,
                    fallbackExpiresAtMs = 0L,
                ),
            )
        }
    }

    /** Preserve elapsed duration when the user/network changes wall time. */
    fun reconcileAfterClockChange() = synchronized(PROCESS_LOCK) {
        SessionSlot.entries.forEach { slot ->
            val envelope = (store.read(slot) as? SessionRead.Present)?.envelope ?: return@forEach
            if (envelope.lifecycleState != LifecycleState.ARMED) return@forEach
            val remaining = (
                envelope.elapsedRealtimeDeadlineMs - elapsedRealtimeMs()
            ).coerceAtLeast(0L)
            if (remaining == 0L) {
                claimAndDispatch(envelope.token)
                return@forEach
            }
            val phaseLength = (envelope.finalDeadlineMs - envelope.mainDeadlineMs)
                .coerceAtLeast(0L)
            val finalDeadline = wallClockMs() + remaining
            val rebased = envelope.copy(
                mainDeadlineMs = (finalDeadline - phaseLength).coerceAtLeast(wallClockMs()),
                finalDeadlineMs = finalDeadline,
            )
            if (store.write(rebased)) {
                val schedule = scheduleBestEffort(rebased)
                if (!schedule.exactAccepted && !schedule.inexactAccepted) {
                    publishSchedulingRecovery(rebased)
                } else {
                    persistSchedulingMode(rebased, schedule)
                }
            }
        }
    }

    private fun persistSchedulingMode(
        envelope: EmergencySessionEnvelope,
        schedule: AlarmScheduleResult,
    ) {
        val mode = when {
            schedule.exactAccepted && schedule.inexactAccepted ->
                SchedulingMode.EXACT_AND_INEXACT
            schedule.exactAccepted -> SchedulingMode.EXACT_ONLY
            schedule.inexactAccepted -> SchedulingMode.INEXACT_ONLY
            else -> SchedulingMode.NONE
        }
        if (envelope.schedulingMode != mode) {
            store.write(envelope.copy(schedulingMode = mode))
        }
    }

    /**
     * A future ARMED session must never remain apparently protected with zero
     * AlarmManager delivery paths. Preserve an actionable, user-driven dial
     * path without submitting an early Telecom request.
     */
    private fun publishSchedulingRecovery(envelope: EmergencySessionEnvelope) {
        val stranded = envelope.copy(schedulingMode = SchedulingMode.NONE)
        if (!store.write(stranded)) return

        val intendedExpiry = wallClockMs() + FALLBACK_TARGET_RETENTION_MS
        val fallbackCandidate = stranded.copy(fallbackExpiresAtMs = intendedExpiry)
        val outcome = try {
            fallbackPoster.post(fallbackCandidate)
        } catch (_: RuntimeException) {
            FallbackOutcome.FAILED
        }
        val posted = outcome == FallbackOutcome.POSTED
        store.write(
            fallbackCandidate.copy(
                lifecycleState = if (posted) {
                    LifecycleState.MANUAL_ACTION_REQUIRED
                } else {
                    LifecycleState.REQUEST_FAILED
                },
                target = if (posted) stranded.target else "",
                callRequestOutcome = CallRequestOutcome.NOT_ATTEMPTED,
                fallbackOutcome = outcome,
                fallbackExpiresAtMs = if (posted) intendedExpiry else 0L,
            ),
        )
    }

    fun wipe(): WipeResult = synchronized(PROCESS_LOCK) {
        val present = SessionSlot.entries.mapNotNull { slot ->
            (store.read(slot) as? SessionRead.Present)?.envelope
        }.distinctBy { it.token }
        val tooLate = present.firstOrNull {
            it.lifecycleState == LifecycleState.CLAIMED
        }
        if (tooLate != null) {
            return@synchronized WipeResult(WipeStatus.TOO_LATE, "dispatchAlreadyClaimed")
        }
        present.forEach { envelope ->
            if (envelope.lifecycleState in setOf(LifecycleState.PREPARING, LifecycleState.ARMED)) {
                val cancelled = envelope.copy(
                    lifecycleState = LifecycleState.CANCELLED,
                    target = "",
                )
                if (!store.write(cancelled)) {
                    return@synchronized WipeResult(WipeStatus.UNKNOWN, "cancelCommitFailed")
                }
                cancelAlarmBestEffort(envelope.token)
            }
            if (envelope.lifecycleState.isTerminal) {
                try {
                    fallbackPoster.clear(envelope)
                } catch (_: RuntimeException) {
                    // Store clear below is authoritative; retained actions are
                    // token-gated and fail closed once the record is absent.
                }
                cancelAlarmBestEffort(envelope.token)
            }
        }
        if (store.clearAll()) {
            submittedInProcess.clear()
            retryScheduledInProcess.clear()
            WipeResult(WipeStatus.COMPLETED)
        } else {
            WipeResult(WipeStatus.UNKNOWN, "wipeCommitFailed")
        }
    }

    private fun cancelAlarmBestEffort(token: SessionToken) {
        try {
            alarmScheduler.cancel(token)
        } catch (_: RuntimeException) {
            // Durable generation/lifecycle checks are authoritative. A late
            // delivery is harmless and the caller must still receive the
            // typed result committed before this cleanup attempt.
        }
    }

    private fun scheduleBestEffort(
        envelope: EmergencySessionEnvelope,
    ): AlarmScheduleResult = try {
        alarmScheduler.schedule(envelope)
    } catch (_: RuntimeException) {
        AlarmScheduleResult(exactAccepted = false, inexactAccepted = false)
    }

    companion object {
        private val PROCESS_LOCK = Any()
        private val submittedInProcess = mutableSetOf<String>()
        private val retryScheduledInProcess = mutableSetOf<String>()
        private const val DISPATCH_RETRY_DELAY_MS = 5_000L

        private fun isValidRandomId(value: String): Boolean =
            value.length in 8..128 && value.all {
                it.isLetterOrDigit() || it == '-' || it == '_' || it == '.'
            }

        private fun SessionToken.processKey(): String =
            "${slot.storageKey}:$randomId:$generation"
    }
}
