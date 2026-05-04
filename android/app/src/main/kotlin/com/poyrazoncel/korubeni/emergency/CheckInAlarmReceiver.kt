package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class CheckInAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        EmergencyNotificationHelper.ensureChannels(context)

        val sessionId = CheckInScheduler.sessionFromIntent(intent)
        val phase = CheckInScheduler.phase(context, sessionId)
        val graceDurationMs = CheckInScheduler.graceDurationMs(context, sessionId)
        val now = System.currentTimeMillis()

        if (phase == CheckInScheduler.PHASE_MAIN && graceDurationMs > 0L) {
            EmergencyEventBus.emitOrPersist(
                context,
                mapOf("type" to "checkInGraceStarted", "timestamp" to now, "sessionId" to sessionId)
            )
            val copy = NativeNotificationText.graceStarted(context, sessionId)
            EmergencyNotificationHelper.showAlert(
                context,
                EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID,
                copy.title,
                copy.body,
                "checkInGraceStarted"
            )
            CheckInScheduler.schedule(
                context,
                sessionId,
                CheckInScheduler.PHASE_GRACE,
                now + graceDurationMs,
                0L,
            )
            return
        }

        CheckInScheduler.cancel(context, sessionId)
        EmergencyEventBus.emitOrPersist(
            context,
            mapOf("type" to "checkInExpired", "timestamp" to now, "sessionId" to sessionId)
        )
        val copy = NativeNotificationText.expired(context, sessionId)
        EmergencyNotificationHelper.showAlert(
            context,
            EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID,
            copy.title,
            copy.body,
            "checkInExpired"
        )
    }
}
