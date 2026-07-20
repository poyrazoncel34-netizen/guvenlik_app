package com.poyrazoncel.korubeni.emergency

import android.content.Context
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
    fun run(
        context: Context,
        eventCode: NativeSafetyEventCode,
        block: () -> Unit,
    ) {
        try {
            block()
        } catch (_: RuntimeException) {
            NativeSafetyEventRecorder.record(context, eventCode)
            Log.e(TAG, "${eventCode.wireValue} at Android receiver boundary")
        }
    }

    private const val TAG = "EmergencyReceiver"
}
