package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class CheckInAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        EmergencyNotificationHelper.ensureChannels(context)

        val sessionId = CheckInScheduler.sessionFromIntent(intent)

        // Iptal sonrasi alarm reddi (SPEC 3.3 / 5): if the session was cancelled
        // (confirmSafe/stop) before this alarm fired, reject it silently — mirrors
        // the countdown KEY_COUNTDOWN_ACTIVE guard.
        if (!CheckInScheduler.isActive(context, sessionId)) {
            return
        }

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
                CheckInScheduler.notificationIdFor(sessionId),
                copy.title,
                copy.body,
                "checkInGraceStarted",
                fullScreen = true,
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

        // ESCALATE (grace deadline reached). Native-backup call: works even if the
        // Dart isolate is dead (Doze/app-kill). YALNIZ BIRINCIL KISI — no failover
        // list, no 112 fallback (SPEC 0 Karar 1/2 + 3.2).
        val primary = CheckInScheduler.primaryNumber(context, sessionId)
        var dispatchFailed = false
        if (primary.isNotBlank()) {
            // Deactivate first (stale-alarm rejection); the fired dedup flag is
            // written only after a SUCCESSFUL dispatch so a failed native call
            // never suppresses the Dart-side retry + fail-safe (FRESH_AUDIT F1).
            CheckInScheduler.deactivateForEscalation(context, sessionId)
            val result = EmergencyExecutor.executeEmergency(context, primary)
            dispatchFailed = result["status"] == "failed"
            if (!dispatchFailed) {
                CheckInScheduler.markAlarmFired(context, sessionId)
            }
        } else {
            // No callable primary target — never synthesize 112 for check-in/safe-walk.
            CheckInScheduler.cancel(context, sessionId)
        }

        EmergencyEventBus.emitOrPersist(
            context,
            mapOf("type" to "checkInExpired", "timestamp" to now, "sessionId" to sessionId)
        )
        val copy = if (dispatchFailed) {
            // Manual-call fail-safe copy (with the number) instead of the
            // misleading "timer ended" success copy.
            NativeNotificationText.dispatchFailed(context, primary)
        } else {
            NativeNotificationText.expired(context, sessionId)
        }
        EmergencyNotificationHelper.showAlert(
            context,
            CheckInScheduler.notificationIdFor(sessionId),
            copy.title,
            copy.body,
            "checkInExpired"
        )
    }
}
