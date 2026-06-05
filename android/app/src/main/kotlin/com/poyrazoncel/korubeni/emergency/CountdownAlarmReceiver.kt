package com.poyrazoncel.korubeni.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver fired by AlarmManager when the countdown backup alarm triggers.
 *
 * This is the C4 safety net: if the Dart Timer.periodic froze under Doze mode,
 * this receiver executes the emergency natively using [EmergencyExecutor],
 * reading the persisted primaryNumber from SharedPreferences.
 *
 * The receiver marks KEY_COUNTDOWN_ALARM_FIRED = true so that when the Dart side
 * resumes, it can detect the alarm fired and skip duplicate execution.
 */
class CountdownAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "CountdownAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = EmergencyPrefs.prefs(context)

        if (!prefs.getBoolean(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE, false)) {
            Log.i(TAG, "Alarm fired but countdown not active — cancelled by PIN. Ignoring.")
            return
        }

        val intentDispatchId =
            intent?.getStringExtra(CountdownAlarmScheduler.EXTRA_DISPATCH_ID).orEmpty()
        val storedDispatchId =
            prefs.getString(EmergencyPrefs.KEY_COUNTDOWN_DISPATCH_ID, "").orEmpty()
        if (intentDispatchId.isBlank() || intentDispatchId != storedDispatchId) {
            Log.w(TAG, "Ignoring stale countdown alarm dispatch")
            return
        }

        Log.w(TAG, "Countdown alarm fired! Dart timer likely frozen. Executing emergency natively.")

        // Mark that the alarm fired (Dart side checks this to avoid double-execution)
        prefs.edit()
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, true)
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE, false)
            .commit()

        // Read persisted emergency target. Never synthesize 112: only dispatch
        // when a real number was persisted; otherwise place no call.
        val primaryNumber =
            prefs.getString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, "")
                ?.trim()
                .orEmpty()

        if (primaryNumber.isNotEmpty()) {
            EmergencyExecutor.executeEmergency(context, primaryNumber)
        } else {
            Log.w(TAG, "Countdown alarm fired but no primary number persisted; no call placed")
        }
    }
}
