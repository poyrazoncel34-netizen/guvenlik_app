package com.poyrazoncel.korubeni.emergency

import android.util.Log

/**
 * Last-resort process boundary for system-delivered safety broadcasts.
 *
 * Coordinators still return durable typed outcomes for expected failures. This
 * guard covers failures while constructing Android dependencies (for example a
 * broken device-protected storage service) before a coordinator can exist.
 * No token, target, intent extras, or exception text is written to the log.
 */
internal object EmergencyReceiverGuard {
    fun run(receiverName: String, block: () -> Unit) {
        try {
            block()
        } catch (_: RuntimeException) {
            Log.e(TAG, "$receiverName failed at the Android receiver boundary")
        }
    }

    private const val TAG = "EmergencyReceiver"
}
