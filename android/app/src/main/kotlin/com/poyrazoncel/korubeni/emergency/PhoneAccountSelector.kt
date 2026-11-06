package com.poyrazoncel.korubeni.emergency

/**
 * One call-capable account as Telecom reports it. [H] is
 * android.telecom.PhoneAccountHandle in production and a plain value in JVM
 * tests, so the choice below stays a pure function.
 */
data class PhoneAccountCandidate<H>(
    val handle: H,
    val isSimSubscription: Boolean,
    /** Null when the OS cannot map the account to a subscription (API 29). */
    val subscriptionId: Int?,
)

/**
 * Read-only view of the device's calling accounts. Every method may throw
 * SecurityException (READ_PHONE_STATE revoked) or another RuntimeException
 * (binder/OEM failure); [PhoneAccountSelector] absorbs both.
 */
interface PhoneAccountSource<H> {
    /** Telecom's user-chosen default for "tel"; null means "ask every time". */
    fun defaultOutgoing(): H?
    fun callCapable(): List<PhoneAccountCandidate<H>>
    fun activeSubscriptionIds(): Set<Int>
    /** Valid subscription ids in priority order (default voice, then default data). */
    fun preferredSubscriptionIds(): List<Int>
}

enum class PhoneAccountChoiceReason {
    DEFAULT_ACCOUNT,
    SINGLE_ACCOUNT,
    PREFERRED_SUBSCRIPTION,
    ACTIVE_SIM,
    FIRST_CAPABLE,
    NO_ACCOUNTS,
    PERMISSION_DENIED,
    QUERY_FAILED,
}

data class PhoneAccountChoice<H>(
    val handle: H?,
    val reason: PhoneAccountChoiceReason,
)

/**
 * Picks the account an emergency call must be placed on, so Telecom never
 * parks it in SELECT_PHONE_ACCOUNT ("ask every time" on dual-SIM phones)
 * while the screen is locked or the phone is in a pocket.
 *
 * A null handle is never an error for the caller: the call is still placed
 * without an explicit account, exactly as before this selector existed.
 */
object PhoneAccountSelector {
    fun <H> select(source: PhoneAccountSource<H>): PhoneAccountChoice<H> {
        val default: H?
        val capable: List<PhoneAccountCandidate<H>>
        try {
            default = source.defaultOutgoing()
            if (default != null) {
                return PhoneAccountChoice(default, PhoneAccountChoiceReason.DEFAULT_ACCOUNT)
            }
            capable = source.callCapable()
        } catch (_: SecurityException) {
            return PhoneAccountChoice(null, PhoneAccountChoiceReason.PERMISSION_DENIED)
        } catch (_: RuntimeException) {
            return PhoneAccountChoice(null, PhoneAccountChoiceReason.QUERY_FAILED)
        }
        when (capable.size) {
            0 -> return PhoneAccountChoice(null, PhoneAccountChoiceReason.NO_ACCOUNTS)
            1 -> return PhoneAccountChoice(capable[0].handle, PhoneAccountChoiceReason.SINGLE_ACCOUNT)
        }

        // Subscription facts only refine the order; losing them must never
        // lose the explicit account, so each lookup degrades to "unknown".
        val active = orEmpty { source.activeSubscriptionIds() }
        val preferred = orEmpty { source.preferredSubscriptionIds() }
        val pool = capable.filter { it.isSimSubscription }.ifEmpty { capable }
        fun isActive(c: PhoneAccountCandidate<H>) =
            active.isEmpty() || c.subscriptionId in active

        for (subId in preferred) {
            val match = pool.firstOrNull { it.subscriptionId == subId && isActive(it) }
            if (match != null) {
                return PhoneAccountChoice(match.handle, PhoneAccountChoiceReason.PREFERRED_SUBSCRIPTION)
            }
        }
        if (active.isNotEmpty()) {
            val match = pool.firstOrNull { it.subscriptionId in active }
            if (match != null) {
                return PhoneAccountChoice(match.handle, PhoneAccountChoiceReason.ACTIVE_SIM)
            }
        }
        return PhoneAccountChoice(pool.first().handle, PhoneAccountChoiceReason.FIRST_CAPABLE)
    }

    private inline fun <T> orEmpty(read: () -> Collection<T>): Collection<T> = try {
        read()
    } catch (_: RuntimeException) {
        emptyList()
    }
}
