package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Keeps active safety timers duration-based when the wall clock changes. */
class ClockChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        EmergencyReceiverGuard.run(
            context,
            NativeSafetyEventCode.CLOCK_RECEIVER_BOUNDARY_FAILURE,
        ) {
            if (intent?.action != Intent.ACTION_TIME_CHANGED &&
                intent?.action != Intent.ACTION_TIMEZONE_CHANGED
            ) {
                return@run
            }

            try {
                EmergencySessionRuntime.coordinator(context).reconcileAfterClockChange()
            } finally {
                // The Dart projections hold wall deadlines too; a running engine
                // must re-read the rebased ones (audit Y-01) -- and after a failed
                // reconcile still more. Emit only, never persist: the single
                // pending-trigger slot may hold a dispatch outcome, and a cold
                // start re-reads every session anyway.
                EmergencyEventBus.emit(
                    mapOf(
                        "type" to "safetyClockChanged",
                        "timestamp" to System.currentTimeMillis(),
                    ),
                )
            }
        }
    }
}
