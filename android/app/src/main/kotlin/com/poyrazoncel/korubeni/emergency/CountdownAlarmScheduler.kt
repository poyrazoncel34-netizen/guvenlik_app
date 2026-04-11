package com.poyrazoncel.korubeni.emergency

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Schedules an exact alarm as a backup for the Dart Timer.periodic countdown.
 *
 * Under Android Doze mode or manufacturer battery optimizations, the Dart isolate
 * may be frozen and Timer.periodic stops ticking. This alarm is a degraded
 * native backup; it is not a guarantee when exact alarms are denied or the OS
 * suppresses background work.
 *
 * The primaryNumber is persisted to SharedPreferences so that
 * [CountdownAlarmReceiver] can invoke [EmergencyExecutor] without any
 * Flutter involvement.
 */
object CountdownAlarmScheduler {
    private const val TAG = "CountdownAlarmScheduler"
    private const val REQUEST_CODE = 42099
    const val EXTRA_DISPATCH_ID = "dispatch_id"

    fun schedule(
        context: Context,
        deadlineMs: Long,
        primaryNumber: String,
        dispatchId: String,
    ) {
        val prefs = EmergencyPrefs.prefs(context)
        prefs.edit()
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE, true)
            .putLong(EmergencyPrefs.KEY_COUNTDOWN_DEADLINE_MS, deadlineMs)
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, false)
            .putString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, primaryNumber)
            .putString(EmergencyPrefs.KEY_COUNTDOWN_DISPATCH_ID, dispatchId)
            .commit()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildPendingIntent(context, dispatchId)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (CheckInScheduler.canScheduleExactAlarms(context)) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    deadlineMs,
                    pendingIntent
                )
            } else {
                Log.w(TAG, "Exact alarm permission denied — using inexact fallback")
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    deadlineMs,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, deadlineMs, pendingIntent)
        }

        Log.i(TAG, "Countdown alarm scheduled for $deadlineMs")
    }

    fun cancel(context: Context, dispatchId: String? = null): Boolean {
        val prefs = EmergencyPrefs.prefs(context)
        if (dispatchId != null) {
            val storedDispatchId = prefs.getString(EmergencyPrefs.KEY_COUNTDOWN_DISPATCH_ID, null)
            if (storedDispatchId != dispatchId) {
                Log.w(TAG, "Ignoring countdown cancel for stale dispatch")
                return false
            }
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildPendingIntent(context))
        prefs.edit()
            .remove(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE)
            .remove(EmergencyPrefs.KEY_COUNTDOWN_DEADLINE_MS)
            .remove(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED)
            .remove(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER)
            .remove(EmergencyPrefs.KEY_COUNTDOWN_DISPATCH_ID)
            .commit()
        Log.i(TAG, "Countdown alarm cancelled")
        return true
    }

    fun didAlarmFire(context: Context, dispatchId: String): Boolean {
        val prefs = EmergencyPrefs.prefs(context)
        return prefs.getString(EmergencyPrefs.KEY_COUNTDOWN_DISPATCH_ID, null) == dispatchId &&
            prefs.getBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, false)
    }

    private fun buildPendingIntent(context: Context, dispatchId: String? = null): PendingIntent {
        val intent = Intent(context, CountdownAlarmReceiver::class.java).apply {
            if (dispatchId != null) putExtra(EXTRA_DISPATCH_ID, dispatchId)
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
