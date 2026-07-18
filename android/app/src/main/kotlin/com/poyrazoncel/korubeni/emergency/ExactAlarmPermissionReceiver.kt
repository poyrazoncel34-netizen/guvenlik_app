package com.poyrazoncel.korubeni.emergency

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Android sends this broadcast when exact-alarm access is granted.
 *
 * Revocation itself terminates the process and deletes exact alarms, so it is
 * not an event an app can reliably handle in-process. Each safety deadline also
 * has an independent inexact backup. If the user later grants access, this
 * receiver upgrades every still-active deadline back to exact immediately.
 */
class ExactAlarmPermissionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED) {
            return
        }
        EmergencySessionRuntime.coordinator(context).reconcileCurrentBoot()
    }
}
