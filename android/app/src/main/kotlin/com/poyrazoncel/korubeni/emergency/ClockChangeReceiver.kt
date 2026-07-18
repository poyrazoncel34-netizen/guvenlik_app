package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Keeps active safety timers duration-based when the wall clock changes. */
class ClockChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_TIME_CHANGED &&
            intent?.action != Intent.ACTION_TIMEZONE_CHANGED
        ) {
            return
        }

        EmergencySessionRuntime.coordinator(context).reconcileAfterClockChange()
    }
}
