package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the ORDER of [CapabilitySnapshot.rejectionReason] (2026-11-02).
 *
 * A device that lacks several capabilities is refused for exactly one of them,
 * and the order decides which. The Dart side depends on it twice: the blocked
 * panic dialog offers the fix for the refusal it got, then walks the remaining
 * capabilities in this order when the user returns from Settings
 * (`ArmRemedy.capabilityOrder`); and the Y-11 review deliberately put
 * exact-alarm access BEFORE CALL_PHONE, so a device missing both is blocked
 * instead of dropping to the dialer-only countdown. A reorder here would
 * silently change both.
 *
 * Each row is checked with itself AND every later condition failing: the
 * reason must still be that row. Checking one failure at a time would pass for
 * any order.
 */
class CapabilitySnapshotRejectionOrderTest {
    private val ready = CapabilitySnapshot(
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

    /** The documented order: reason code, and how to break that condition. */
    private val order: List<Pair<String, (CapabilitySnapshot) -> CapabilitySnapshot>> = listOf(
        "unsupportedOs" to { it.copy(supportedOs = false) },
        "entitlementDenied" to { it.copy(entitlementDecision = EntitlementDecision.DENIED) },
        "entitlementUnknown" to { it.copy(entitlementDecision = EntitlementDecision.UNKNOWN) },
        "pinNotConfigured" to { it.copy(pinConfigured = false) },
        "targetNotCallable" to { it.copy(callableTarget = false) },
        "telephonyUnavailable" to { it.copy(telephonyCalling = false) },
        "telecomUnavailable" to { it.copy(telecomAvailable = false) },
        "dialHandlerUnavailable" to { it.copy(dialHandlerAvailable = false) },
        "exactAlarmDenied" to { it.copy(exactAlarmGranted = false) },
        "callPermissionDenied" to { it.copy(callPermissionGranted = false) },
        "notificationsDisabled" to { it.copy(notificationsEnabled = false) },
        "alertChannelNotHigh" to { it.copy(alertChannelHigh = false) },
    )

    @Test
    fun `a ready device is not refused`() {
        assertNull(ready.rejectionReason())
    }

    @Test
    fun `each condition alone is refused with its own code`() {
        for ((code, breakIt) in order) {
            assertEquals(code, breakIt(ready).rejectionReason())
        }
    }

    @Test
    fun `each condition wins over every condition after it`() {
        // entitlementDenied and entitlementUnknown are two values of ONE field:
        // breaking the later would overwrite the earlier, so that pair is
        // skipped by the field they share, not by their names.
        for ((index, row) in order.withIndex()) {
            val (code, breakIt) = row
            var snapshot = breakIt(ready)
            for ((_, breakLater) in order.drop(index + 1)) {
                val sameField = breakIt(ready).entitlementDecision != ready.entitlementDecision &&
                    breakLater(ready).entitlementDecision != ready.entitlementDecision
                if (sameField) continue
                snapshot = breakLater(snapshot)
            }
            assertEquals("with every later condition failing too", code, snapshot.rejectionReason())
        }
    }

    @Test
    fun `exact-alarm access is refused before CALL_PHONE`() {
        // Y-11: missing both must block, not drop to the dialer-only countdown.
        val both = ready.copy(exactAlarmGranted = false, callPermissionGranted = false)
        assertEquals("exactAlarmDenied", both.rejectionReason())
    }

    @Test
    fun `the device capabilities come last, in the order the Dart dialog walks them`() {
        val codes = order.map { it.first }
        assertEquals(
            listOf("exactAlarmDenied", "callPermissionDenied", "notificationsDisabled", "alertChannelNotHigh"),
            codes.takeLast(4),
        )
    }
}
