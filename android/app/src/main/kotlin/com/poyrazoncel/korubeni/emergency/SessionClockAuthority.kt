package com.poyrazoncel.korubeni.emergency

/**
 * Which clock may be trusted for one safety record, and what its age means.
 *
 * Extracted from [EmergencySessionCoordinator] while closing OD-1, under this
 * repository's rule that a file already over the 800-line limit gives logic up
 * rather than taking more on. It is also the honest shape of the thing: every
 * function here is a pure question about two clocks and a boot identity, with
 * no store, no alarms and no Telecom, so it can be reasoned about and tested
 * without any of that.
 *
 * The decisions themselves are documented at each function. The short version:
 *
 *  - [deadlineDecision] picks the authoritative clock and hands the age to
 *    [OverdueDispatchPolicy], which owns the 5-minute boundary.
 *  - [isFromAnotherBoot] answers "may I apply a same-boot clock change?" and
 *    falls back to the historical same-boot assumption when nothing is known.
 *  - [isProvenSameBoot] answers "may I OVERWRITE this elapsed deadline?" and
 *    treats an unknown identity as no. The asymmetry is deliberate and is the
 *    whole of the OD-1c fix.
 *  - [wallRebasedFromElapsed] rebuilds a stale wall deadline from the monotonic
 *    remainder, for the Dart projection that renders it.
 */
internal class SessionClockAuthority(
    private val wallClockMs: () -> Long,
    private val elapsedRealtimeMs: () -> Long,
    /** Current BOOT_COUNT, already failure-mapped to [UNKNOWN_BOOT_COUNT]. */
    private val bootCount: () -> Int,
    /** Current kernel boot id, already failure-mapped to "". */
    private val bootId: () -> String,
) {
    /**
     * The [OverdueDispatchPolicy] verdict for [envelope], on the clock that may
     * be trusted for it (OD-1).
     *
     * Monotonic authority needs an elapsed stamp (a record written before that
     * field existed, or seeded by a device probe, carries -1) that is not from
     * another boot -- elapsedRealtime restarts at zero, so a previous boot's
     * deadline is that boot's uptime plus the remainder and means nothing here.
     * With neither, the persisted wall deadline is the only reference there is.
     *
     * This deliberately uses [isFromAnotherBoot] and NOT [isProvenSameBoot].
     * Choosing which clock to READ an age from is not destructive, and on a
     * device where no boot identity is readable at all, demanding proof would
     * hand every decision back to the wall clock and undo OD-1 entirely. The
     * stamp comparison alone already catches the ordinary reboot, because a
     * fresh boot's elapsed clock is far below any stamp a previous boot wrote.
     * OVERWRITING an elapsed deadline is destructive, so that one does demand
     * proof -- see the `keepElapsed` decision in [reconcileArmedFromWall].
     */
    fun deadlineDecision(
        envelope: EmergencySessionEnvelope,
    ): OverdueDispatchPolicy.Decision = OverdueDispatchPolicy.decide(
        wallOverdueMs = wallClockMs() - envelope.finalDeadlineMs,
        monotonicOverdueMs = if (
            envelope.elapsedStampMs >= 0L && !isFromAnotherBoot(envelope)
        ) {
            elapsedRealtimeMs() - envelope.elapsedRealtimeDeadlineMs
        } else {
            null
        },
    )

    /**
     * Whether [envelope]'s elapsed deadline was written in an earlier boot.
     *
     * elapsedRealtime restarts at zero on every boot, so that deadline is then
     * the previous boot's uptime plus the remaining time. Signals: an elapsed
     * clock now BELOW the one recorded when the deadline was written (it never
     * runs backwards within a boot), then the kernel boot id, then BOOT_COUNT.
     * The kernel id is unique per boot by construction and decides whenever
     * both sides have one; BOOT_COUNT depends on when Settings increments it
     * relative to the boot receivers, and a count stamped before that increment
     * made a later same-boot clock change look foreign (review of A-02r).
     * With none known the historical same-boot assumption stands rather than a
     * guess: treating an unknown as "another boot" would apply a same-boot clock
     * change to the deadline, and which error to prefer is a product decision.
     */
    fun isFromAnotherBoot(envelope: EmergencySessionEnvelope): Boolean {
        if (envelope.elapsedStampMs >= 0L && elapsedRealtimeMs() < envelope.elapsedStampMs) {
            return true
        }
        val id = bootId()
        if (id.isNotEmpty() && envelope.elapsedBootId.isNotEmpty()) {
            return envelope.elapsedBootId != id
        }
        val current = bootCount()
        return current != UNKNOWN_BOOT_COUNT && envelope.elapsedBootCount != UNKNOWN_BOOT_COUNT &&
            envelope.elapsedBootCount != current
    }

    /**
     * Whether [envelope]'s elapsed stamp PROVABLY belongs to the current boot.
     *
     * The inverse of [isFromAnotherBoot] is not this. That function answers
     * "may I apply a same-boot clock change?" and deliberately falls back to
     * the historical same-boot assumption when no boot identity is readable.
     * This one answers "may I trust this elapsed deadline, or overwrite it?",
     * where an unknown identity must mean NO: the cost of a wrong yes is a
     * previous boot's deadline treated as live, and the cost of a wrong no is
     * only that the wall deadline decides instead.
     *
     * Signals, strongest first: an elapsed clock below the recorded stamp
     * disproves it outright (that clock never runs backwards inside a boot);
     * then the kernel boot id, unique per boot by construction; then
     * BOOT_COUNT. Nothing known at all is NOT proof.
     */
    fun isProvenSameBoot(envelope: EmergencySessionEnvelope): Boolean {
        if (envelope.elapsedStampMs < 0L) return false
        if (elapsedRealtimeMs() < envelope.elapsedStampMs) return false
        val id = bootId()
        if (id.isNotEmpty() && envelope.elapsedBootId.isNotEmpty()) {
            return envelope.elapsedBootId == id
        }
        val current = bootCount()
        if (current != UNKNOWN_BOOT_COUNT && envelope.elapsedBootCount != UNKNOWN_BOOT_COUNT) {
            return envelope.elapsedBootCount == current
        }
        return false
    }

    /**
     * [envelope] with its wall deadlines rebuilt from the monotonic remainder,
     * or null when they already agree within [WALL_DRIFT_TOLERANCE_MS].
     *
     * Pure: the caller commits it.
     *
     * Same arithmetic as the TIME_SET path: keep the grace phase length and put
     * the final deadline `remaining` ms from now. This runs when a clock change
     * happened while the app was not running, so no TIME_SET was ever delivered
     * and the stored wall deadline is simply wrong. A write failure is not
     * fatal -- the monotonic deadline still decides, and the alarm is already
     * scheduled on it.
     */
    fun wallRebasedFromElapsed(
        envelope: EmergencySessionEnvelope,
    ): EmergencySessionEnvelope? {
        val remaining = (
            envelope.elapsedRealtimeDeadlineMs - elapsedRealtimeMs()
        ).coerceAtLeast(0L)
        val now = wallClockMs()
        val finalDeadline = now + remaining
        if (kotlin.math.abs(finalDeadline - envelope.finalDeadlineMs) <= WALL_DRIFT_TOLERANCE_MS) {
            return null
        }
        val phaseLength = (envelope.finalDeadlineMs - envelope.mainDeadlineMs)
            .coerceAtLeast(0L)
        val rebased = envelope.copy(
            mainDeadlineMs = (finalDeadline - phaseLength).coerceAtLeast(now),
            finalDeadlineMs = finalDeadline,
        )
        return rebased
    }

    private companion object {
        /**
         * How far a stored wall deadline may sit from the monotonic one before
         * reconcile rewrites it. Wide enough that ordinary NTP nudges and the
         * few ms between the two clock reads do not cause a write on every
         * reconcile; far below the smallest user-visible countdown step.
         */
        const val WALL_DRIFT_TOLERANCE_MS = 2_000L
    }
}
