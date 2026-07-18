package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class CheckInAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val token = AndroidEmergencySessionAlarmScheduler.tokenFromIntent(intent) ?: return
        val dispatch = EmergencySessionRuntime.coordinator(context).claimAndDispatch(token)
        if (DirectBootAccess.isUserUnlocked(context) && (
                dispatch.callRequestOutcome != CallRequestOutcome.NOT_ATTEMPTED ||
                    dispatch.fallbackOutcome != FallbackOutcome.NOT_ATTEMPTED
                )
        ) {
            EmergencyEventBus.emitOrPersist(
                context,
                mapOf(
                    "type" to "emergencySessionDispatched",
                    "timestamp" to System.currentTimeMillis(),
                    "kind" to token.kind.wireValue,
                    "randomId" to token.randomId,
                    "generation" to token.generation,
                    "callRequestOutcome" to dispatch.callRequestOutcome.wireValue,
                    "fallbackOutcome" to dispatch.fallbackOutcome.wireValue,
                ),
            )
        }
    }
}
