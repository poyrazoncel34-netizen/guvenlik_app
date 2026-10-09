package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.RequiresApi

/**
 * Where "Arka plan korumasını aç" goes (Y-11): this package's own exact-alarm
 * toggle. `ACTION_REQUEST_SCHEDULE_EXACT_ALARM` without a `package:` URI opened
 * the generic "Alarms & reminders" list instead (API 36 emulator).
 */
object ExactAlarmSettingsIntent {
    @RequiresApi(Build.VERSION_CODES.S)
    fun request(packageName: String): Intent =
        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, packageUri(packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    /** For a Settings build without, or refusing, the exact-alarm screen. */
    fun appDetails(packageName: String): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri(packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    /**
     * Opens the toggle, else the app details page. Any refusal falls back --
     * not only ActivityNotFoundException: a SecurityException used to escape
     * and the button silently did nothing. False when neither opened.
     */
    @RequiresApi(Build.VERSION_CODES.S)
    fun open(context: Context): Boolean {
        for (intent in listOf(request(context.packageName), appDetails(context.packageName))) {
            try {
                context.startActivity(intent)
                return true
            } catch (_: RuntimeException) {
                // Try the next destination.
            }
        }
        return false
    }

    private fun packageUri(packageName: String): Uri =
        Uri.fromParts("package", packageName, null)
}
