package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * BroadcastReceiver fired by AlarmManager when the countdown backup alarm triggers.
 *
 * This is the Doze safety net. Dart and AlarmManager both present the same
 * token to [EmergencySessionCoordinator.claimAndDispatch]; the durable
 * generation/lifecycle claim, rather than a second fired flag, decides which
 * contender may perform safety side effects.
 */
class CountdownAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        EmergencyReceiverGuard.run("CountdownAlarmReceiver") {
            val token = AndroidEmergencySessionAlarmScheduler.tokenFromIntent(intent)
                ?: return@run
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
}
