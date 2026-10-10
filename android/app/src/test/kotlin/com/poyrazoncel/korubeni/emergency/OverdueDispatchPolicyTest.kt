package com.poyrazoncel.korubeni.emergency

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The boundary semantics of [OverdueDispatchPolicy], stated once, here.
 *
 * OD-1 requires the rule to live in exactly one place; this is the test that
 * pins that one place, and [OverdueDispatchParityTest] is what proves every
 * native path actually routes through it.
 */
class OverdueDispatchPolicyTest {
    private val limit = OverdueDispatchPolicy.MAX_OVERDUE_DISPATCH_MS

    @Test
    fun `the limit is five minutes`() {
        assertEquals(300_000L, limit)
    }

    @Test
    fun `the age boundary is inclusive at the limit`() {
        // The owner's rule: "0-5 minutes may dispatch; past 5 minutes may not."
        // Exactly 5:00.000 is not past it.
        assertEquals(verdict(-1L), OverdueDispatchPolicy.Verdict.NOT_DUE)
        assertEquals(verdict(0L), OverdueDispatchPolicy.Verdict.DISPATCH)
        assertEquals(verdict(1L), OverdueDispatchPolicy.Verdict.DISPATCH)
        assertEquals(verdict(limit - 1L), OverdueDispatchPolicy.Verdict.DISPATCH)
        assertEquals(verdict(limit), OverdueDispatchPolicy.Verdict.DISPATCH)
        assertEquals(verdict(limit + 1L), OverdueDispatchPolicy.Verdict.OFFER_MANUAL)
        assertEquals(verdict(6L * 60_000L), OverdueDispatchPolicy.Verdict.OFFER_MANUAL)
        assertEquals(verdict(3_600_000L), OverdueDispatchPolicy.Verdict.OFFER_MANUAL)
        assertEquals(verdict(30L * 24L * 3_600_000L), OverdueDispatchPolicy.Verdict.OFFER_MANUAL)
    }

    @Test
    fun `the monotonic clock outranks the wall clock whenever it has an opinion`() {
        // Wall says "two hours overdue", monotonic says "not due yet".
        val live = OverdueDispatchPolicy.decide(
            wallOverdueMs = 2L * 3_600_000L,
            monotonicOverdueMs = -118_000L,
        )
        assertEquals(OverdueDispatchPolicy.Verdict.NOT_DUE, live.verdict)
        assertEquals(OverdueDispatchPolicy.ClockAuthority.MONOTONIC, live.authority)

        // Wall says "not due", monotonic says "due now".
        val due = OverdueDispatchPolicy.decide(
            wallOverdueMs = -3_600_000L,
            monotonicOverdueMs = 0L,
        )
        assertEquals(OverdueDispatchPolicy.Verdict.DISPATCH, due.verdict)
        assertEquals(OverdueDispatchPolicy.ClockAuthority.MONOTONIC, due.authority)
    }

    @Test
    fun `the wall clock decides only when this boot cannot measure the interval`() {
        val decision = OverdueDispatchPolicy.decide(
            wallOverdueMs = 90_000L,
            monotonicOverdueMs = null,
        )
        assertEquals(OverdueDispatchPolicy.Verdict.DISPATCH, decision.verdict)
        assertEquals(OverdueDispatchPolicy.ClockAuthority.WALL, decision.authority)
        assertEquals(90_000L, decision.overdueMs)
    }

    /**
     * Property: whichever clock is authoritative, the verdict is a monotone
     * step function of age with exactly two edges, and it never depends on the
     * other clock. Random because a hand-picked table can agree with an
     * off-by-one implementation by accident.
     */
    @Test
    fun `property -- the verdict depends only on the authoritative clock`() {
        val random = Random(20261010)
        repeat(20_000) {
            val authoritative = random.nextLong(-2L * limit, 4L * limit)
            val noise = random.nextLong(-30L * 24L * 3_600_000L, 30L * 24L * 3_600_000L)
            val expected = when {
                authoritative < 0L -> OverdueDispatchPolicy.Verdict.NOT_DUE
                authoritative <= limit -> OverdueDispatchPolicy.Verdict.DISPATCH
                else -> OverdueDispatchPolicy.Verdict.OFFER_MANUAL
            }
            assertEquals(
                "monotonic authority, wall noise $noise, age $authoritative",
                expected,
                OverdueDispatchPolicy.decide(
                    wallOverdueMs = noise,
                    monotonicOverdueMs = authoritative,
                ).verdict,
            )
            assertEquals(
                "wall authority, age $authoritative",
                expected,
                OverdueDispatchPolicy.decide(
                    wallOverdueMs = authoritative,
                    monotonicOverdueMs = null,
                ).verdict,
            )
        }
    }

    /** Property: the verdict never moves backwards as a record gets older. */
    @Test
    fun `property -- age only ever narrows what is allowed`() {
        val random = Random(20261011)
        val rank = mapOf(
            OverdueDispatchPolicy.Verdict.NOT_DUE to 0,
            OverdueDispatchPolicy.Verdict.DISPATCH to 1,
            OverdueDispatchPolicy.Verdict.OFFER_MANUAL to 2,
        )
        repeat(20_000) {
            val younger = random.nextLong(-2L * limit, 4L * limit)
            val older = younger + random.nextLong(0L, 10L * limit)
            val a = rank.getValue(verdict(younger))
            val b = rank.getValue(verdict(older))
            assert(b >= a) { "verdict went backwards between $younger and $older" }
        }
    }

    private fun verdict(overdueMs: Long) = OverdueDispatchPolicy
        .decide(wallOverdueMs = overdueMs, monotonicOverdueMs = overdueMs)
        .verdict
}
