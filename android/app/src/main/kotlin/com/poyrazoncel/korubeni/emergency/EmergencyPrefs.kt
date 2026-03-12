package com.poyrazoncel.korubeni.emergency

import android.content.Context

object EmergencyPrefs {
    private const val FILE_NAME = "korubeni_emergency"

    const val KEY_PENDING_TRIGGER = "pending_trigger"
    const val KEY_SHAKE_ENABLED = "shake_enabled"
    const val KEY_SHAKE_SENSITIVITY = "shake_sensitivity"
    const val KEY_CHECK_IN_ACTIVE = "check_in_active"
    const val KEY_CHECK_IN_PHASE = "check_in_phase"
    const val KEY_CHECK_IN_DEADLINE = "check_in_deadline"
    const val KEY_CHECK_IN_GRACE_MS = "check_in_grace_ms"

    fun prefs(context: Context) =
        context.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)
}
