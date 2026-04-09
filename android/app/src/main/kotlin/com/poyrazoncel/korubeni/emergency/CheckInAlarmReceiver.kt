package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class CheckInAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        EmergencyNotificationHelper.ensureChannels(context)

        val prefs = EmergencyPrefs.prefs(context)
        val phase = prefs.getString(EmergencyPrefs.KEY_CHECK_IN_PHASE, CheckInScheduler.PHASE_MAIN)
            ?: CheckInScheduler.PHASE_MAIN
        val graceDurationMs = prefs.getLong(EmergencyPrefs.KEY_CHECK_IN_GRACE_MS, 0L)
        val now = System.currentTimeMillis()

        if (phase == CheckInScheduler.PHASE_MAIN && graceDurationMs > 0L) {
            EmergencyEventBus.emitOrPersist(
                context,
                mapOf("type" to "checkInGraceStarted", "timestamp" to now)
            )
            EmergencyNotificationHelper.showAlert(
                context,
                EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID,
                "Check-in suresi doldu",
                "Lutfen guvende oldugunuzu onaylayin.",
                "checkInGraceStarted"
            )
            CheckInScheduler.schedule(
                context,
                CheckInScheduler.PHASE_GRACE,
                now + graceDurationMs,
                0L,
            )
            return
        }

        CheckInScheduler.cancel(context)
        EmergencyEventBus.emitOrPersist(
            context,
            mapOf("type" to "checkInExpired", "timestamp" to now)
        )
        EmergencyNotificationHelper.showAlert(
            context,
            EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID,
            "Check-in acil durumu",
            "Guvenli yuruyus zamani doldu.",
            "checkInExpired"
        )
    }
}
