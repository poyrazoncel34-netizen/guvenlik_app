package com.poyrazoncel.korubeni.emergency

import android.content.Context

object EmergencyPrefs {
    private const val FILE_NAME = "korubeni_emergency"

    const val KEY_PENDING_TRIGGER = "pending_trigger"
    const val KEY_CHECK_IN_ACTIVE = "check_in_active"
    const val KEY_CHECK_IN_PHASE = "check_in_phase"
    const val KEY_CHECK_IN_DEADLINE = "check_in_deadline"
    const val KEY_CHECK_IN_GRACE_MS = "check_in_grace_ms"

    // M2 native-backup escalation (yalniz birincil kisi — no failover list).
    // Per-session suffixing is handled by CheckInScheduler.keyFor().
    const val KEY_CHECK_IN_PRIMARY_NUMBER = "check_in_primary_number"
    const val KEY_CHECK_IN_ALARM_FIRED = "check_in_alarm_fired"

    // Countdown backup alarm keys (C4 Doze-mode safety net)
    const val KEY_COUNTDOWN_ACTIVE = "countdown_active"
    const val KEY_COUNTDOWN_DEADLINE_MS = "countdown_deadline_ms"
    const val KEY_COUNTDOWN_ALARM_FIRED = "countdown_alarm_fired"
    const val KEY_COUNTDOWN_PRIMARY_NUMBER = "countdown_primary_number"
    const val KEY_COUNTDOWN_DISPATCH_ID = "countdown_dispatch_id"

    fun prefs(context: Context) =
        context.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

    /**
     * KVKK Md.7 (silme): wipe the entire native emergency store. Called only
     * from the "Verilerimi Sil" reset path (AppResetService) so the persisted
     * primary contact number does not survive a data deletion. Reset-only --
     * the live emergency flow's own writes/reads are unchanged.
     */
    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }
}
