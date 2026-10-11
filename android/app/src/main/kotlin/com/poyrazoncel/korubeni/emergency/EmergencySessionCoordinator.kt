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
    private val warningPoster: EmergencyWarningPoster = EmergencyWarningPoster { _, _ -> false },
    /** Identity of the current boot ([UNKNOWN_BOOT_COUNT] when unavailable). */
    private val bootCount: () -> Int = { UNKNOWN_BOOT_COUNT },
    /** Kernel boot id: the second identity when [bootCount] is unreadable. */
    private val bootId: () -> String? = { null },
) {
    /** Which clock may be trusted for a record, and what its age means. */
    private val clocks = SessionClockAuthority(
        wallClockMs = { wallClockMs() },
        elapsedRealtimeMs = { elapsedRealtimeMs() },
        bootCount = { currentBootCount() },
        bootId = { currentBootId() },
    )

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
        // BOTH clocks are read here, monotonic FIRST, with nothing between them.
        // These two reads used to sit ~80 lines apart, with a capability
        // snapshot (several binder calls) and a store read in between, so the
        // elapsed deadline computed below landed that gap LATER in real time
        // than the wall deadline.
        //
        // Harmless while claimAndDispatch gated on the wall clock. OD-1 made
        // that gate monotonic, and Dart anchors its dispatch to the WALL
        // deadline (safety_clock.dart, audit K-03: native must not refuse a
        // dispatch a microsecond early). So an on-time Dart dispatch read
        // NOT_DUE for the length of the gap, Dart concluded the request had
        // failed and opened the dialer, and the exact alarm placed the
        // automatic call moments later -- a dialer on screen AND a call.
        //
        // Monotonic first also puts any residual skew on the safe side: the
        // native deadline lands a hair EARLIER than the wall one, so an on-time
        // dispatch is accepted rather than refused.
        val elapsedNow = elapsedRealtimeMs()
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
        // elapsedNow was captured next to `now` at the top of arm(); see there.
        val elapsedDeadline = elapsedNow +
            (request.finalDeadlineMs - now).coerceAtLeast(0L)
        val preparing = EmergencySessionEnvelope(
            token = token,
            lifecycleState = LifecycleState.PREPARING,
            target = normalizedTarget,
            mainDeadlineMs = request.mainDeadlineMs,
            finalDeadlineMs = request.finalDeadlineMs,
            elapsedRealtimeDeadlineMs = elapsedDeadline,
            elapsedBootCount = currentBootCount(),
            elapsedBootId = currentBootId(),
            elapsedStampMs = elapsedNow,
            schedulingMode = SchedulingMode.NONE,
            mainDurationMs = revisionFrom?.mainDurationMs ?: (request.mainDeadlineMs - now),
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

    /** Durable claim suppresses exact/inexact repeats; a crash remains unknown. */
    fun warn(token: SessionToken, preWarning: Boolean): String = synchronized(PROCESS_LOCK) {
        val current = (store.read(token.slot) as? SessionRead.Present)?.envelope
            ?: return@synchronized "unknown"
        if (current.token != token || current.lifecycleState != LifecycleState.ARMED ||
            token.kind == SessionKind.PANIC ||
            (preWarning && token.kind != SessionKind.SAFE_WALK)) return@synchronized "stale"
        val deadline = current.mainDeadlineMs - if (preWarning) current.preWarningLeadMs else 0L
        if (wallClockMs() < deadline || wallClockMs() >= current.finalDeadlineMs ||
            (preWarning && wallClockMs() >= current.mainDeadlineMs)) return@synchronized "stale"
        val previous = if (preWarning) current.preWarningOutcome else current.graceWarningOutcome
        // "unknown" is a CLAIM, not a result: it means the durable claim
        // committed but we never learned what the post did -- typically because
        // the process died in that window, or the completing write failed.
        // Treating it as terminal (as a dispatch claim is treated) permanently
        // swallows the warning for this generation, which is the exact defect
        // the native warning exists to prevent. Retrying is safe: the warning
        // reuses ONE notification id per kind, so Android REPLACES it instead
        // of stacking, and warn() can never reach the final dispatch.
        if (previous != "notAttempted" && previous != "unknown") {
            return@synchronized previous
        }
        val claimed = if (preWarning) current.copy(preWarningOutcome = "unknown")
            else current.copy(graceWarningOutcome = "unknown")
        if (!store.write(claimed)) return@synchronized "unknown"
        val outcome = try { if (warningPoster.post(claimed, preWarning)) "posted" else "failed" }
            catch (_: RuntimeException) { "failed" }
        val completed = if (preWarning) claimed.copy(preWarningOutcome = outcome)
            else claimed.copy(graceWarningOutcome = outcome)
        if (store.write(completed)) outcome else "unknown"
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
        // OD-1: every path that can dial goes through OverdueDispatchPolicy, and
        // this is the one most Android components reach -- both alarm receivers
        // and the Dart dispatch channel. It used to ask only "has the wall clock
        // passed the deadline", which both let an hours-late delivery call the
        // contact and refused an on-time ELAPSED_REALTIME alarm whenever the
        // user had set the wall clock back.
        val freshness = clocks.deadlineDecision(current)
        when (freshness.verdict) {
            OverdueDispatchPolicy.Verdict.NOT_DUE ->
                // CLAIMED is deliberately exempt, but NOT for the reason first
                // written here. That comment said the bounded retry rewrites the
                // deadlines to now + DISPATCH_RETRY_DELAY_MS; it does not --
                // `retryEnvelope` below is handed to scheduleBestEffort and is
                // never persisted (security review F5). Inside one boot a
                // CLAIMED record therefore cannot read NOT_DUE at all.
                //
                // The exemption is reachable only when the WALL authority reads
                // earlier than the deadline across a reboot (an RTC that came
                // back wrong). Dispatching there is the deliberate choice:
                // something already claimed this session and may have reached
                // Telecom, so refusing would strand a call the user is waiting
                // on, and it matches what reconcile did before OD-1.
                if (current.lifecycleState == LifecycleState.ARMED) {
                    return@synchronized DispatchResult.notAttempted(token, LifecycleState.ARMED)
                }
            OverdueDispatchPolicy.Verdict.OFFER_MANUAL -> {
                offerOverdueInsteadOfDialling(current)
                val offered = (store.read(token.slot) as? SessionRead.Present)?.envelope
                return@synchronized DispatchResult(
                    token = token,
                    callRequestOutcome = offered?.callRequestOutcome
                        ?: CallRequestOutcome.NOT_ATTEMPTED,
                    fallbackOutcome = offered?.fallbackOutcome
                        ?: FallbackOutcome.NOT_ATTEMPTED,
                    terminalState = offered?.lifecycleState,
                )
            }
            OverdueDispatchPolicy.Verdict.DISPATCH -> Unit
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
            completedAtMs = wallClockMs(),
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
        if (
            current.token != token ||
            (
                current.fallbackOutcome !in
                    setOf(FallbackOutcome.POSTED, FallbackOutcome.EXPIRED) &&
                    !publishedCrashWindow
                )
        ) {
            return@synchronized false
        }
        if (current.fallbackOutcome == FallbackOutcome.EXPIRED && current.target.isBlank()) {
            return@synchronized true
        }
        store.write(
            current.copy(
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
        // If the process died after publishing the immutable notification but
        // before recording POSTED, CLAIMED is the only admissible recovery
        // state. The PendingIntent's embedded expiry remains authoritative.
        val publishedCrashWindow = current.lifecycleState == LifecycleState.CLAIMED &&
            current.fallbackOutcome == FallbackOutcome.NOT_ATTEMPTED
        if (
            current.token != token || intendedExpiryMs <= now ||
            intendedExpiryMs > now + FALLBACK_TARGET_RETENTION_MS ||
            (!terminalPosted && !publishedCrashWindow) ||
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
                lifecycleState = if (publishedCrashWindow) {
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

    /**
     * An ARMED session whose deadline passed more than [MAX_OVERDUE_DISPATCH_MS]
     * ago is OFFERED to the user instead of dialled.
     *
     * The defect this closes: a user starts a panic countdown, the phone is
     * force-stopped or powered off, no call goes out and nothing is said. When
     * the app is next opened -- the same day or a week later -- reconcile() ran
     * this branch with no age limit at all and called the emergency contact as
     * if the emergency were live. The project's own emulator capture timed that
     * at 82 ms after LOCKED_BOOT_COMPLETED, before Flutter even loaded. An
     * unwanted outgoing call cannot be taken back, and the second time it
     * happens the contact stops taking the app seriously (audit A-001).
     *
     * The limit is a product decision, not a technical one: the opposite error
     * -- a missed call in a real emergency -- is also a real cost. 5 minutes
     * keeps a short interruption (a reboot, a brief power-off) on the automatic
     * path while ending the "days later" dispatch entirely.
     *
     * Nothing new is invented here. MANUAL_ACTION_REQUIRED and the fallback
     * notification already exist for exactly this shape: a terminal session
     * that retains its target so the user can authorise the call with one tap,
     * via consumeFallbackTarget. Only the copy is new, because the standard
     * manual-fallback text promises an automatic request that will not happen.
     *
     * If the notification cannot be posted, the session ends as REQUEST_FAILED
     * with the target cleared rather than silently falling back to dialling:
     * failing to reach the user is not permission to call on their behalf.
     */
    private fun offerOverdueInsteadOfDialling(envelope: EmergencySessionEnvelope) {
        val intendedExpiry = wallClockMs() + FALLBACK_TARGET_RETENTION_MS
        val candidate = envelope.copy(fallbackExpiresAtMs = intendedExpiry)
        val outcome = try {
            fallbackPoster.post(candidate, FallbackReason.OVERDUE_NOT_DISPATCHED)
        } catch (_: RuntimeException) {
            FallbackOutcome.FAILED
        }
        val posted = outcome == FallbackOutcome.POSTED
        // A write failure leaves the envelope ARMED, so the next reconcile
        // offers again. At-least-once NOTIFICATION is the safe direction; the
        // tap cannot dial either, because consumeFallbackTarget requires the
        // terminal+POSTED state this failed to commit.
        store.write(
            candidate.copy(
                completedAtMs = wallClockMs(),
                lifecycleState = if (posted) {
                    LifecycleState.MANUAL_ACTION_REQUIRED
                } else {
                    LifecycleState.REQUEST_FAILED
                },
                target = if (posted) envelope.target else "",
                callRequestOutcome = CallRequestOutcome.NOT_ATTEMPTED,
                fallbackOutcome = outcome,
                fallbackExpiresAtMs = if (posted) intendedExpiry else 0L,
            ),
        )
        cancelAlarmBestEffort(envelope.token)
    }

    /** Re-arms future alarms or dispatches fresh elapsed ARMED/CLAIMED sessions. */
    fun reconcileAfterBoot() = reconcile(rebaseElapsedFromWall = true)

    /** Used for package replacement, unlock, and exact-permission grant. */
    fun reconcileCurrentBoot() = reconcile(rebaseElapsedFromWall = false)

    private fun reconcile(rebaseElapsedFromWall: Boolean) = synchronized(PROCESS_LOCK) {
        SessionSlot.entries.forEach { slot ->
            val envelope = (store.read(slot) as? SessionRead.Present)?.envelope ?: return@forEach
            when (envelope.lifecycleState) {
                LifecycleState.ARMED -> reconcileArmedFromWall(
                    envelope,
                    alwaysRebaseElapsed = rebaseElapsedFromWall,
                )
                LifecycleState.CLAIMED -> {
                    // CLAIMED is a durable uncertainty boundary, not timeless
                    // permission to call. A process may die after the claim
                    // commit but before any external side effect; reopening days
                    // later must follow the same freshness policy as an overdue
                    // ARMED session. claimAndDispatch now applies that policy
                    // itself, so this branch no longer repeats the rule -- it
                    // just hands the record over.
                    claimAndDispatch(envelope.token)
                }
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
                else -> Unit
            }
        }
    }

    /**
     * The wall deadline is the only reference that survives a reboot: an
     * overdue session is dispatched or offered, a pending one is scheduled, and
     * its elapsed deadline is rebuilt for THIS boot when [alwaysRebaseElapsed]
     * or when it was written in another boot.
     */
    private fun reconcileArmedFromWall(
        envelope: EmergencySessionEnvelope,
        alwaysRebaseElapsed: Boolean,
    ) {
        // OD-1: judged on the clock that may be trusted for THIS record, not
        // always the wall clock. Inside one boot a wall clock the user moved
        // forward used to terminate a session that still had time left, and one
        // moved back used to hide a session that was genuinely due.
        val freshness = clocks.deadlineDecision(envelope)
        if (freshness.verdict != OverdueDispatchPolicy.Verdict.NOT_DUE) {
            // claimAndDispatch applies the same verdict, including OFFER_MANUAL,
            // so the decision is not restated here.
            claimAndDispatch(envelope.token)
            return
        }
        // A record older than the boot identities is re-tied to this boot now,
        // while wall time is authoritative, so a later TIME_SET can tell (A-02r).
        //
        // OD-1c: `alwaysRebaseElapsed` used to mean literally always, so a boot
        // broadcast rebuilt the elapsed deadline from the wall clock even when
        // the boot identity proved the record belonged to THIS boot. With a
        // wall clock that had moved while the app was stopped, that collapsed a
        // live session's deadline to "due now" and called the contact hours
        // early -- measured on API 36 against a real 2-hour Check-In, reachable
        // because Android 15+ re-delivers BOOT_COMPLETED after a force-stop.
        // A boot broadcast is now a reason to distrust an UNPROVEN stamp, not a
        // licence to overwrite a proven one; after a real reboot the identity
        // differs and the rebase below still runs.
        val keepElapsed = if (alwaysRebaseElapsed) {
            clocks.isProvenSameBoot(envelope)
        } else {
            envelope.elapsedStampMs >= 0L && !clocks.isFromAnotherBoot(envelope)
        }
        if (keepElapsed) {
            // The monotonic clock is the authority for this record, so a wall
            // deadline that has drifted away from it (a clock change the app was
            // not running to hear) is stale projection data. Dart reads those
            // wall deadlines for the countdown, so correct them here instead of
            // waiting for a TIME_SET that already happened.
            // F3 (security review): rebasedWallFromElapsed OVERWRITES
            // finalDeadlineMs, the only reference that survives a reboot, so it
            // is a destructive write and takes the proof-grade check rather
            // than `keepElapsed`'s weaker one. They differ only when NO boot
            // identity is readable at all; there, treating an unknown boot as
            // "the same boot" could push the wall deadline out by the previous
            // boot's uptime. Rescheduling still happens -- only the overwrite
            // is withheld.
            val corrected = if (clocks.isProvenSameBoot(envelope)) {
                rebasedWallFromElapsed(envelope)
            } else {
                null
            }
            scheduleBestEffort(corrected ?: envelope)
            return
        }
        val elapsedNow = elapsedRealtimeMs()
        val rebased = envelope.copy(
            elapsedRealtimeDeadlineMs = elapsedNow +
                (envelope.finalDeadlineMs - wallClockMs()).coerceAtLeast(0L),
            elapsedBootCount = currentBootCount(),
            elapsedBootId = currentBootId(),
            elapsedStampMs = elapsedNow,
        )
        // Scheduled even if the commit fails: the stored copy keeps its old
        // boot stamp, so the next reconcile rebases again, and the old elapsed
        // deadline may be the previous boot's uptime away.
        store.write(rebased)
        scheduleBestEffort(rebased)
    }

    /** [bootCount], with any failure read as an unknown boot. */
    private fun currentBootCount(): Int = try {
        bootCount()
    } catch (_: Exception) {
        UNKNOWN_BOOT_COUNT
    }

    /** [bootId], with any failure read as unknown (""). */
    private fun currentBootId(): String = try {
        bootId().orEmpty()
    } catch (_: Exception) {
        ""
    }





    /**
     * [envelope] with its wall deadlines rebuilt from the monotonic remainder
     * and durably committed, or null when nothing needed changing.
     *
     * The arithmetic lives in [SessionClockAuthority]; only the write is here,
     * because that is the part that needs the store. A write failure is not
     * fatal -- the monotonic deadline still decides, and the alarm is already
     * scheduled on it.
     */
    private fun rebasedWallFromElapsed(
        envelope: EmergencySessionEnvelope,
    ): EmergencySessionEnvelope? {
        val rebased = clocks.wallRebasedFromElapsed(envelope) ?: return null
        return if (store.write(rebased)) rebased else null
    }

    /** Preserve elapsed duration when the user/network changes wall time. */
    fun reconcileAfterClockChange() = synchronized(PROCESS_LOCK) {
        SessionSlot.entries.forEach { slot ->
            val envelope = (store.read(slot) as? SessionRead.Present)?.envelope ?: return@forEach
            if (envelope.lifecycleState != LifecycleState.ARMED) return@forEach
            if (clocks.isFromAnotherBoot(envelope)) {
                // TIME_SET of a new boot delivered before that boot's own
                // reconcile (audit A-02): broadcast order is not guaranteed, so
                // do here exactly what the boot reconcile would do.
                reconcileArmedFromWall(envelope, alwaysRebaseElapsed = true)
                return@forEach
            }
            val remaining = (
                envelope.elapsedRealtimeDeadlineMs - elapsedRealtimeMs()
            ).coerceAtLeast(0L)
            if (remaining == 0L) {
                // Due on the monotonic clock. A backward wall change can leave
                // the wall deadline in the future, which used to make this the
                // only path that could dispatch at all; claimAndDispatch now
                // judges the same record on the same monotonic clock, so the
                // wall deadline is rebased purely to keep the stored projection
                // and the Dart countdown honest.
                val now = wallClockMs()
                if (now < envelope.finalDeadlineMs) {
                    store.write(
                        envelope.copy(
                            mainDeadlineMs = minOf(envelope.mainDeadlineMs, now),
                            finalDeadlineMs = now,
                        ),
                    )
                }
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
            if (store.write(rebased)) scheduleBestEffort(rebased)
        }
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

        /**
         * How stale an ARMED session may be and still be dialled WITHOUT
         * asking. Owner decision, 2026-09-20. See
         * [offerOverdueInsteadOfDialling] for why this is a balance and not a
         * safety maximum.
         */
        /** Kept as the historical name; the rule lives in [OverdueDispatchPolicy]. */
        const val MAX_OVERDUE_DISPATCH_MS = OverdueDispatchPolicy.MAX_OVERDUE_DISPATCH_MS


        private fun isValidRandomId(value: String): Boolean =
            value.length in 8..128 && value.all {
                it.isLetterOrDigit() || it == '-' || it == '_' || it == '.'
            }

        private fun SessionToken.processKey(): String =
            "${slot.storageKey}:$randomId:$generation"
    }
}
