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
 * may be frozen and Timer.periodic stops ticking. This alarm guarantees the
 * emergency fires even if the Flutter engine is suspended.
 *
 * The primaryNumber is persisted to SharedPreferences so that
 * [CountdownAlarmReceiver] can invoke [EmergencyExecutor] without any
 * Flutter involvement.
 */
object CountdownAlarmScheduler {
    private const val TAG = "CountdownAlarmScheduler"
    private const val REQUEST_CODE = 42099

    fun schedule(
        context: Context,
        deadlineMs: Long,
        primaryNumber: String,
    ) {
        val prefs = EmergencyPrefs.prefs(context)
        prefs.edit()
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE, true)
            .putLong(EmergencyPrefs.KEY_COUNTDOWN_DEADLINE_MS, deadlineMs)
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, false)
            .putString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, primaryNumber)
            .commit()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildPendingIntent(context)

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

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildPendingIntent(context))
        EmergencyPrefs.prefs(context).edit()
            .remove(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE)
            .remove(EmergencyPrefs.KEY_COUNTDOWN_DEADLINE_MS)
            .remove(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED)
            .remove(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER)
            .commit()
        Log.i(TAG, "Countdown alarm cancelled")
    }

    fun didAlarmFire(context: Context): Boolean {
        return EmergencyPrefs.prefs(context)
            .getBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, false)
    }

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, CountdownAlarmReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
