package com.poyrazoncel.korubeni.emergency

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

object CheckInScheduler {
    private const val CHECK_IN_REQUEST_CODE = 42031
    private const val SAFE_WALK_REQUEST_CODE = 42032
    const val SESSION_CHECK_IN = "check_in"
    const val SESSION_SAFE_WALK = "safe_walk"
    const val PHASE_MAIN = "main"
    const val PHASE_GRACE = "grace"

    fun schedule(
        context: Context,
        sessionId: String,
        phase: String,
        deadlineMs: Long,
        graceDurationMs: Long,
    ) {
        val session = normalizeSession(sessionId)
        val prefs = EmergencyPrefs.prefs(context)
        prefs.edit()
            .putBoolean(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ACTIVE), true)
            .putString(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PHASE), phase)
            .putLong(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_DEADLINE), deadlineMs)
            .putLong(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_GRACE_MS), graceDurationMs)
            .apply()

        scheduleAlarm(context, session, deadlineMs)
    }

    fun cancel(context: Context, sessionId: String) {
        val session = normalizeSession(sessionId)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildPendingIntent(context, session))
        EmergencyPrefs.prefs(context).edit()
            .remove(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ACTIVE))
            .remove(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PHASE))
            .remove(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_DEADLINE))
            .remove(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_GRACE_MS))
            .apply()
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
        restoreSessionAfterBoot(context, SESSION_CHECK_IN)
        restoreSessionAfterBoot(context, SESSION_SAFE_WALK)
    }

    fun hasActiveSession(context: Context): Boolean {
        val prefs = EmergencyPrefs.prefs(context)
        return prefs.getBoolean(keyFor(SESSION_CHECK_IN, EmergencyPrefs.KEY_CHECK_IN_ACTIVE), false) ||
            prefs.getBoolean(keyFor(SESSION_SAFE_WALK, EmergencyPrefs.KEY_CHECK_IN_ACTIVE), false)
    }

    fun sessionFromIntent(intent: Intent?): String {
        return normalizeSession(intent?.getStringExtra("sessionId"))
    }

    fun phase(context: Context, sessionId: String): String {
        val session = normalizeSession(sessionId)
        return EmergencyPrefs.prefs(context).getString(
            keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PHASE),
            PHASE_MAIN
        ) ?: PHASE_MAIN
    }

    fun graceDurationMs(context: Context, sessionId: String): Long {
        val session = normalizeSession(sessionId)
        return EmergencyPrefs.prefs(context).getLong(
            keyFor(session, EmergencyPrefs.KEY_CHECK_IN_GRACE_MS),
            0L
        )
    }

    private fun restoreSessionAfterBoot(context: Context, sessionId: String) {
        val session = normalizeSession(sessionId)
        val prefs = EmergencyPrefs.prefs(context)
        if (!prefs.getBoolean(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ACTIVE), false)) {
            return
        }

        val phase = prefs.getString(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PHASE), PHASE_MAIN) ?: PHASE_MAIN
        val deadlineMs = prefs.getLong(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_DEADLINE), 0L)
        val graceDurationMs = prefs.getLong(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_GRACE_MS), 0L)
        val now = System.currentTimeMillis()

        if (deadlineMs <= 0L) {
            EmergencyEventBus.persist(
                context,
                mapOf("type" to "checkInCorrupted", "timestamp" to now, "sessionId" to session)
            )
            cancel(context, session)
            return
        }

        if (now < deadlineMs) {
            scheduleAlarm(context, session, deadlineMs)
            return
        }

        if (phase == PHASE_MAIN && graceDurationMs > 0L) {
            val graceDeadline = now + graceDurationMs
            schedule(context, session, PHASE_GRACE, graceDeadline, 0L)
            EmergencyEventBus.persist(
                context,
                mapOf("type" to "checkInGraceStarted", "timestamp" to now, "sessionId" to session)
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

        cancel(context, session)
        EmergencyEventBus.persist(
            context,
            mapOf("type" to "checkInExpired", "timestamp" to now, "sessionId" to session)
        )
        EmergencyNotificationHelper.showAlert(
            context,
            EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID,
            "Check-in acil durumu",
            "Guvenli yuruyus zamani doldu.",
            "checkInExpired"
        )
    }

    private fun scheduleAlarm(context: Context, sessionId: String, deadlineMs: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildPendingIntent(context, sessionId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (canScheduleExactAlarms(context)) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    deadlineMs,
                    pendingIntent
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    deadlineMs,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, deadlineMs, pendingIntent)
        }
    }

    private fun buildPendingIntent(context: Context, sessionId: String): PendingIntent {
        val session = normalizeSession(sessionId)
        val intent = Intent(context, CheckInAlarmReceiver::class.java).apply {
            putExtra("sessionId", session)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCodeFor(session),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun normalizeSession(sessionId: String?): String {
        return when (sessionId) {
            SESSION_SAFE_WALK -> SESSION_SAFE_WALK
            else -> SESSION_CHECK_IN
        }
    }

    private fun requestCodeFor(sessionId: String): Int {
        return if (sessionId == SESSION_SAFE_WALK) SAFE_WALK_REQUEST_CODE else CHECK_IN_REQUEST_CODE
    }

    private fun keyFor(sessionId: String, baseKey: String): String {
        return if (sessionId == SESSION_CHECK_IN) baseKey else "${baseKey}_${sessionId}"
    }
}
