package com.poyrazoncel.korubeni.emergency

import android.content.Intent
import android.net.Uri
import android.provider.Settings

/**
 * Where "Arka plan korumasını aç" goes (Y-11): this package's own exact-alarm
 * toggle. `ACTION_REQUEST_SCHEDULE_EXACT_ALARM` without a `package:` URI opened
 * the generic "Alarms & reminders" list instead (API 36 emulator).
 */
object ExactAlarmSettingsIntent {
    fun request(packageName: String): Intent =
        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, packageUri(packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    /** For a Settings build without the exact-alarm screen. */
    fun appDetails(packageName: String): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri(packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    private fun packageUri(packageName: String): Uri =
        Uri.fromParts("package", packageName, null)
}
