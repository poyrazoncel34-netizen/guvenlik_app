package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PhoneAccountSelectorTest {
    private val sim1 = PhoneAccountCandidate("sim1", isSimSubscription = true, subscriptionId = 1)
    private val sim2 = PhoneAccountCandidate("sim2", isSimSubscription = true, subscriptionId = 2)

    private class FakeSource(
        private val default: () -> String? = { null },
        private val capable: () -> List<PhoneAccountCandidate<String>> = { emptyList() },
        private val active: () -> Set<Int> = { emptySet() },
        private val preferred: () -> List<Int> = { emptyList() },
    ) : PhoneAccountSource<String> {
        override fun defaultOutgoing(): String? = default()
        override fun callCapable(): List<PhoneAccountCandidate<String>> = capable()
        override fun activeSubscriptionIds(): Set<Int> = active()
        override fun preferredSubscriptionIds(): List<Int> = preferred()
    }

    @Test
    fun `single SIM is passed explicitly`() {
        val choice = PhoneAccountSelector.select(FakeSource(capable = { listOf(sim1) }))
        assertEquals("sim1", choice.handle)
        assertEquals(PhoneAccountChoiceReason.SINGLE_ACCOUNT, choice.reason)
    }

    @Test
    fun `two SIMs with a default use the default`() {
        val choice = PhoneAccountSelector.select(
            FakeSource(default = { "sim2" }, capable = { listOf(sim1, sim2) }),
        )
        assertEquals("sim2", choice.handle)
        assertEquals(PhoneAccountChoiceReason.DEFAULT_ACCOUNT, choice.reason)
    }

    @Test
    fun `two SIMs without a default never leave the choice to the user`() {
        val choice = PhoneAccountSelector.select(
            FakeSource(capable = { listOf(sim1, sim2) }, active = { setOf(1, 2) }),
        )
        assertEquals("sim1", choice.handle)
        assertEquals(PhoneAccountChoiceReason.ACTIVE_SIM, choice.reason)
    }

    @Test
    fun `two SIMs without a default prefer the system preferred subscription`() {
        val choice = PhoneAccountSelector.select(
            FakeSource(
                capable = { listOf(sim1, sim2) },
                active = { setOf(1, 2) },
                preferred = { listOf(2) },
            ),
        )
        assertEquals("sim2", choice.handle)
        assertEquals(PhoneAccountChoiceReason.PREFERRED_SUBSCRIPTION, choice.reason)
    }

    @Test
    fun `an inactive SIM is skipped for an active one`() {
        val choice = PhoneAccountSelector.select(
            FakeSource(capable = { listOf(sim1, sim2) }, active = { setOf(2) }, preferred = { listOf(1) }),
        )
        assertEquals("sim2", choice.handle)
        assertEquals(PhoneAccountChoiceReason.ACTIVE_SIM, choice.reason)
    }

    @Test
    fun `a non SIM account is not preferred over a SIM`() {
        val voip = PhoneAccountCandidate("voip", isSimSubscription = false, subscriptionId = null)
        val other = PhoneAccountCandidate("voip2", isSimSubscription = false, subscriptionId = null)
        val choice = PhoneAccountSelector.select(FakeSource(capable = { listOf(voip, sim2, other) }))
        assertEquals("sim2", choice.handle)
        assertEquals(PhoneAccountChoiceReason.FIRST_CAPABLE, choice.reason)
    }

    @Test
    fun `no accounts yields no handle`() {
        val choice = PhoneAccountSelector.select(FakeSource())
        assertNull(choice.handle)
        assertEquals(PhoneAccountChoiceReason.NO_ACCOUNTS, choice.reason)
    }

    @Test
    fun `SecurityException yields no handle instead of throwing`() {
        val choice = PhoneAccountSelector.select(
            FakeSource(default = { throw SecurityException("READ_PHONE_STATE") }),
        )
        assertNull(choice.handle)
        assertEquals(PhoneAccountChoiceReason.PERMISSION_DENIED, choice.reason)
    }

    @Test
    fun `SecurityException while listing accounts yields no handle`() {
        val choice = PhoneAccountSelector.select(
            FakeSource(capable = { throw SecurityException("READ_PHONE_STATE") }),
        )
        assertNull(choice.handle)
        assertEquals(PhoneAccountChoiceReason.PERMISSION_DENIED, choice.reason)
    }

    @Test
    fun `subscription lookups failing still pick a SIM`() {
        val choice = PhoneAccountSelector.select(
            FakeSource(
                capable = { listOf(sim1, sim2) },
                active = { throw SecurityException("READ_PHONE_STATE") },
                preferred = { throw UnsupportedOperationException("no subscription feature") },
            ),
        )
        assertEquals("sim1", choice.handle)
        assertEquals(PhoneAccountChoiceReason.FIRST_CAPABLE, choice.reason)
    }

    @Test
    fun `other runtime failures yield no handle instead of throwing`() {
        val choice = PhoneAccountSelector.select(
            FakeSource(default = { throw IllegalStateException("binder died") }),
        )
        assertNull(choice.handle)
        assertEquals(PhoneAccountChoiceReason.QUERY_FAILED, choice.reason)
    }
}
