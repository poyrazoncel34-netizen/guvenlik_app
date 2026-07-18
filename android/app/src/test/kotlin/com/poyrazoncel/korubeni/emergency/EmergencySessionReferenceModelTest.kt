package com.poyrazoncel.korubeni.emergency

import java.util.Random
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * High-volume reference-model exploration. This does not stand in for device
 * AlarmManager/Telecom evidence; it proves that the declared lifecycle
 * invariants survive a broad deterministic operation space before slower
 * production-coordinator and physical-device tests are considered.
 */
class EmergencySessionReferenceModelTest {
    @Test
    fun `twenty fixed seeds explore ten thousand fifty operation traces`() {
        var invariantViolations = 0
        val seeds = (0 until 20).map { 0x4B4F5255L + it }

        seeds.forEach { seed ->
            val random = Random(seed)
            repeat(10_000) {
                val model = ReferenceModel()
                repeat(50) {
                    model.step(random)
                    if (!model.invariantsHold()) invariantViolations += 1
                }
            }
        }

        assertEquals(0, invariantViolations)
    }

    private class ReferenceModel {
        private enum class State { ABSENT, ARMED, CANCELLED, TERMINAL }

        private var state = State.ABSENT
        private var generation = 0L
        private var staleGeneration = 0L
        private var target = ""
        private var armedTarget = ""
        private var submittedRequests = 0
        private var acknowledgedCancel = false
        private var failNextCommit = false

        fun step(random: Random) {
            when (random.nextInt(15)) {
                0 -> arm(random)
                1 -> reviseDeadline()
                2 -> cancel()
                3, 4 -> dispatch(generation)
                5 -> dispatch(staleGeneration)
                6 -> Unit // process death: durable model is unchanged
                7 -> Unit // reboot: deadlines reconcile, identity is unchanged
                8 -> Unit // permission revoke cannot mutate an armed lease
                9 -> Unit // contact mutation cannot redirect an armed target
                10 -> Unit // entitlement change cannot revoke an armed lease
                11 -> Unit // wall-clock shift is handled by stored deadlines
                12 -> failNextCommit = true
                13 -> wipe()
                else -> Unit // corrupt input is rejected without a transition
            }
        }

        private fun arm(random: Random) {
            if (state != State.ABSENT) return
            if (consumeCommitFailure()) return
            staleGeneration = generation
            generation += 1
            target = "+90500${random.nextInt(10_000_000).toString().padStart(7, '0')}"
            armedTarget = target
            submittedRequests = 0
            acknowledgedCancel = false
            state = State.ARMED
        }

        private fun reviseDeadline() {
            if (state != State.ARMED || consumeCommitFailure()) return
            staleGeneration = generation
            generation += 1
        }

        private fun cancel() {
            if (state != State.ARMED || consumeCommitFailure()) return
            state = State.CANCELLED
            target = ""
            acknowledgedCancel = true
        }

        private fun dispatch(candidateGeneration: Long) {
            if (state != State.ARMED || candidateGeneration != generation) return
            if (consumeCommitFailure()) return
            state = State.TERMINAL
            submittedRequests += 1
        }

        private fun wipe() {
            if (consumeCommitFailure()) return
            state = State.ABSENT
            target = ""
            armedTarget = ""
            submittedRequests = 0
            acknowledgedCancel = false
        }

        private fun consumeCommitFailure(): Boolean {
            if (!failNextCommit) return false
            failNextCommit = false
            return true
        }

        fun invariantsHold(): Boolean {
            if (submittedRequests > 1) return false
            if (acknowledgedCancel && submittedRequests != 0) return false
            if (state == State.CANCELLED && target.isNotEmpty()) return false
            if (state == State.ARMED && target != armedTarget) return false
            if (generation < staleGeneration) return false
            return true
        }
    }
}
