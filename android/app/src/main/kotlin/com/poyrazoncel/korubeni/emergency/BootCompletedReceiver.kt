package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        CheckInScheduler.restoreAfterBoot(context)
        val prefs = EmergencyPrefs.prefs(context)
        if (prefs.getBoolean(EmergencyPrefs.KEY_SHAKE_ENABLED, false)) {
            ShakeDetectorService.start(context)
        }
    }
}
