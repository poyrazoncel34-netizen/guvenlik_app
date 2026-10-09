package com.poyrazoncel.korubeni.emergency

import android.content.Intent
import android.provider.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Y-11 (owner decision 2026-10-09): "Arka plan korumasını aç" must land on
 * KoruBeni's OWN exact-alarm toggle. Without the package URI the intent opened
 * the generic "Alarms & reminders" list on an API 36 emulator (Clock, KoruBeni,
 * KoruBeni Smoke -- all "Not allowed") and the user had to find the app there.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class ExactAlarmSettingsIntentTest {
    @Test
    fun `the request names this package so Settings opens its own toggle`() {
        val intent = ExactAlarmSettingsIntent.request("com.poyrazoncel.korubeni")

        assertEquals(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, intent.action)
        assertEquals("package:com.poyrazoncel.korubeni", intent.dataString)
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    }

    @Test
    fun `the fallback is this app's details page`() {
        val intent = ExactAlarmSettingsIntent.appDetails("com.poyrazoncel.korubeni")

        assertEquals(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, intent.action)
        assertEquals("package:com.poyrazoncel.korubeni", intent.dataString)
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    }
}
