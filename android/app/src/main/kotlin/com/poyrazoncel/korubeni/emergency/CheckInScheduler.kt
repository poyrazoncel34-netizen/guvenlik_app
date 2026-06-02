package com.poyrazoncel.korubeni.emergency

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log

object CheckInScheduler {
    private const val TAG = "CheckInScheduler"
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
        primaryNumber: String? = null,
    ) {
        val session = normalizeSession(sessionId)
        val prefs = EmergencyPrefs.prefs(context)
        val editor = prefs.edit()
            .putBoolean(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ACTIVE), true)
            .putString(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PHASE), phase)
            .putLong(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_DEADLINE), deadlineMs)
            .putLong(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_GRACE_MS), graceDurationMs)
        if (primaryNumber != null) {
            // Fresh arm: persist the single primary target (yalniz birincil kisi —
            // no failover list) and reset the native-fired dedup flag.
            editor
                .putString(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PRIMARY_NUMBER), primaryNumber)
                .putBoolean(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ALARM_FIRED), false)
        }
        editor.apply()

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
            .remove(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PRIMARY_NUMBER))
            .remove(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ALARM_FIRED))
            .apply()
    }

    fun isActive(context: Context, sessionId: String): Boolean {
        val session = normalizeSession(sessionId)
        return safeGetBoolean(
            EmergencyPrefs.prefs(context),
            keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ACTIVE),
            false,
        )
    }

    fun primaryNumber(context: Context, sessionId: String): String {
        val session = normalizeSession(sessionId)
        return safeGetString(
            EmergencyPrefs.prefs(context),
            keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PRIMARY_NUMBER),
            "",
        ) ?: ""
    }

    fun didAlarmFire(context: Context, sessionId: String): Boolean {
        val session = normalizeSession(sessionId)
        return safeGetBoolean(
            EmergencyPrefs.prefs(context),
            keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ALARM_FIRED),
            false,
        )
    }

    /**
     * Native escalation dedup: mark that the backup call was dispatched and
     * deactivate the session so a late/duplicate alarm is rejected. Keeps the
     * primary number + fired flag so the Dart side can detect the native fire
     * on resume and skip a duplicate call (mirrors countdown KEY_COUNTDOWN_ALARM_FIRED).
     */
    fun markAlarmFiredAndDeactivate(context: Context, sessionId: String) {
        val session = normalizeSession(sessionId)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildPendingIntent(context, session))
        EmergencyPrefs.prefs(context).edit()
            .putBoolean(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ALARM_FIRED), true)
            .putBoolean(keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ACTIVE), false)
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
        return safeGetBoolean(prefs, keyFor(SESSION_CHECK_IN, EmergencyPrefs.KEY_CHECK_IN_ACTIVE), false) ||
            safeGetBoolean(prefs, keyFor(SESSION_SAFE_WALK, EmergencyPrefs.KEY_CHECK_IN_ACTIVE), false)
    }

    fun sessionFromIntent(intent: Intent?): String {
        return normalizeSession(intent?.getStringExtra("sessionId"))
    }

    fun phase(context: Context, sessionId: String): String {
        val session = normalizeSession(sessionId)
        val prefs = EmergencyPrefs.prefs(context)
        return safeGetString(
            prefs,
            keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PHASE),
            PHASE_MAIN
        ) ?: PHASE_MAIN
    }

    fun graceDurationMs(context: Context, sessionId: String): Long {
        val session = normalizeSession(sessionId)
        val prefs = EmergencyPrefs.prefs(context)
        return safeGetLong(
            prefs,
            keyFor(session, EmergencyPrefs.KEY_CHECK_IN_GRACE_MS),
            0L
        )
    }

    private fun restoreSessionAfterBoot(context: Context, sessionId: String) {
        val session = normalizeSession(sessionId)
        val prefs = EmergencyPrefs.prefs(context)
        if (!safeGetBoolean(prefs, keyFor(session, EmergencyPrefs.KEY_CHECK_IN_ACTIVE), false)) {
            return
        }

        val phase = safeGetString(prefs, keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PHASE), PHASE_MAIN) ?: PHASE_MAIN
        val deadlineMs = safeGetLong(prefs, keyFor(session, EmergencyPrefs.KEY_CHECK_IN_DEADLINE), 0L)
        val graceDurationMs = safeGetLong(prefs, keyFor(session, EmergencyPrefs.KEY_CHECK_IN_GRACE_MS), 0L)
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
            val copy = NativeNotificationText.graceStarted(
                context,
                session,
                restoredAfterBoot = true,
            )
            EmergencyNotificationHelper.showAlert(
                context,
                EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID,
                copy.title,
                copy.body,
                "checkInGraceStarted"
            )
            return
        }

        // Grace already elapsed while the device was off — escalate natively
        // (SPEC 3.5: no longer notification-only). Yalniz birincil kisi, 112 yok.
        val primary = safeGetString(prefs, keyFor(session, EmergencyPrefs.KEY_CHECK_IN_PRIMARY_NUMBER), "") ?: ""
        if (primary.isNotBlank()) {
            markAlarmFiredAndDeactivate(context, session)
            EmergencyExecutor.executeEmergency(context, primary)
        } else {
            cancel(context, session)
        }
        EmergencyEventBus.persist(
            context,
            mapOf("type" to "checkInExpired", "timestamp" to now, "sessionId" to session)
        )
        val copy = NativeNotificationText.expired(
            context,
            session,
            restoredAfterBoot = true,
        )
        EmergencyNotificationHelper.showAlert(
            context,
            EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID,
            copy.title,
            copy.body,
            "checkInExpired"
        )
    }

    private fun scheduleAlarm(context: Context, sessionId: String, deadlineMs: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildPendingIntent(context, sessionId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (canScheduleExactAlarms(context)) {
                try {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        deadlineMs,
                        pendingIntent
                    )
                    return
                } catch (e: SecurityException) {
                    Log.w(TAG, "Exact alarm access revoked during schedule; using inexact fallback")
                } catch (e: RuntimeException) {
                    Log.w(TAG, "Exact alarm schedule failed; using inexact fallback")
                }
            }
            scheduleInexactAlarm(alarmManager, deadlineMs, pendingIntent)
        } else {
            try {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, deadlineMs, pendingIntent)
            } catch (e: RuntimeException) {
                Log.w(TAG, "Legacy exact alarm schedule failed; using inexact fallback")
                alarmManager.set(AlarmManager.RTC_WAKEUP, deadlineMs, pendingIntent)
            }
        }
    }

    private fun scheduleInexactAlarm(
        alarmManager: AlarmManager,
        deadlineMs: Long,
        pendingIntent: PendingIntent,
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    deadlineMs,
                    pendingIntent
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, deadlineMs, pendingIntent)
            }
        } catch (e: RuntimeException) {
            Log.w(TAG, "Inexact idle alarm schedule failed; using standard alarm fallback")
            alarmManager.set(AlarmManager.RTC_WAKEUP, deadlineMs, pendingIntent)
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

    fun normalizeSession(sessionId: String?): String {
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

    private fun safeGetBoolean(
        prefs: SharedPreferences,
        key: String,
        defaultValue: Boolean,
    ): Boolean {
        return try {
            prefs.getBoolean(key, defaultValue)
        } catch (_: ClassCastException) {
            defaultValue
        }
    }

    private fun safeGetLong(
        prefs: SharedPreferences,
        key: String,
        defaultValue: Long,
    ): Long {
        return try {
            prefs.getLong(key, defaultValue)
        } catch (_: ClassCastException) {
            defaultValue
        }
    }

    private fun safeGetString(
        prefs: SharedPreferences,
        key: String,
        defaultValue: String?,
    ): String? {
        return try {
            prefs.getString(key, defaultValue)
        } catch (_: ClassCastException) {
            defaultValue
        }
    }
}
