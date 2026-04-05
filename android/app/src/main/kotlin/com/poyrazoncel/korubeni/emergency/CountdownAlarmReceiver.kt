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
 * reading persisted recipients/message/primaryNumber from SharedPreferences.
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

        Log.w(TAG, "Countdown alarm fired! Dart timer likely frozen. Executing emergency natively.")

        // Mark that the alarm fired (Dart side checks this to avoid double-execution)
        prefs.edit()
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, true)
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE, false)
            .commit()

        // Read persisted emergency data
        val recipientsRaw = prefs.getString(EmergencyPrefs.KEY_COUNTDOWN_RECIPIENTS, "") ?: ""
        val message = prefs.getString(EmergencyPrefs.KEY_COUNTDOWN_MESSAGE, "") ?: ""
        val primaryNumber = prefs.getString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, "") ?: ""

        val recipients = recipientsRaw.split(",").filter { it.isNotBlank() }

        if (recipients.isEmpty() && primaryNumber.isBlank()) {
            Log.e(TAG, "No emergency data persisted — cannot execute")
            return
        }

        EmergencyExecutor.executeEmergency(context, recipients, message, primaryNumber)
    }
}
