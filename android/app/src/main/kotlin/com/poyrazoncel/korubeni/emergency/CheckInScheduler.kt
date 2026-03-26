package com.poyrazoncel.korubeni.emergency

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

object CheckInScheduler {
    private const val REQUEST_CODE = 42031
    const val PHASE_MAIN = "main"
    const val PHASE_GRACE = "grace"

    fun schedule(
        context: Context,
        phase: String,
        deadlineMs: Long,
        graceDurationMs: Long,
    ) {
        val prefs = EmergencyPrefs.prefs(context)
        prefs.edit()
            .putBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, true)
            .putString(EmergencyPrefs.KEY_CHECK_IN_PHASE, phase)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_DEADLINE, deadlineMs)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_GRACE_MS, graceDurationMs)
            .commit()

        scheduleAlarm(context, deadlineMs)
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildPendingIntent(context))
        EmergencyPrefs.prefs(context).edit()
            .remove(EmergencyPrefs.KEY_CHECK_IN_ACTIVE)
            .remove(EmergencyPrefs.KEY_CHECK_IN_PHASE)
            .remove(EmergencyPrefs.KEY_CHECK_IN_DEADLINE)
            .remove(EmergencyPrefs.KEY_CHECK_IN_GRACE_MS)
            .commit()
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return
        }
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    fun restoreAfterBoot(context: Context) {
        val prefs = EmergencyPrefs.prefs(context)
        if (!prefs.getBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, false)) {
            return
        }

        val phase = prefs.getString(EmergencyPrefs.KEY_CHECK_IN_PHASE, PHASE_MAIN) ?: PHASE_MAIN
        val deadlineMs = prefs.getLong(EmergencyPrefs.KEY_CHECK_IN_DEADLINE, 0L)
        val graceDurationMs = prefs.getLong(EmergencyPrefs.KEY_CHECK_IN_GRACE_MS, 0L)
        val now = System.currentTimeMillis()

        if (deadlineMs <= 0L) {
            android.util.Log.w("CheckInScheduler", "Corrupted deadlineMs=$deadlineMs, cancelling check-in")
            EmergencyEventBus.persist(
                context,
                mapOf("type" to "checkInCorrupted", "timestamp" to now)
            )
            cancel(context)
            return
        }

        if (now < deadlineMs) {
            scheduleAlarm(context, deadlineMs)
            return
        }

        if (phase == PHASE_MAIN && graceDurationMs > 0L) {
            val graceDeadline = now + graceDurationMs
            schedule(context, PHASE_GRACE, graceDeadline, 0L)
            EmergencyEventBus.persist(
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
            return
        }

        cancel(context)
        EmergencyEventBus.persist(
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

    private fun scheduleAlarm(context: Context, deadlineMs: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildPendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!canScheduleExactAlarms(context)) {
                android.util.Log.w("CheckInScheduler", "Exact alarm permission denied — alarm may fire late")
                EmergencyEventBus.persist(
                    context,
                    mapOf("type" to "exactAlarmDenied", "timestamp" to System.currentTimeMillis())
                )
            }
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                deadlineMs,
                pendingIntent
            )
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, deadlineMs, pendingIntent)
        }
    }

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, CheckInAlarmReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
