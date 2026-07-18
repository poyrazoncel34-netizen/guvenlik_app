package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

/**
 * Play policy contract: KoruBeni is not an alarm-clock or incoming-call app and
 * does not request USE_FULL_SCREEN_INTENT. Grace alerts remain high-importance
 * heads-up notifications on both old and new Android versions.
 */
@RunWith(RobolectricTestRunner::class)
class FullScreenIntentNotificationTest {

    private val context = RuntimeEnvironment.getApplication()

    private val notificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun postGraceAlert() {
        EmergencyNotificationHelper.showAlert(
            context,
            EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID,
            "title",
            "body",
            "checkInGraceStarted",
        )
    }

    private fun postedNotification() =
        Shadows.shadowOf(notificationManager)
            .getNotification(EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID)

    @Test
    @Config(sdk = [29])
    fun graceAlertNeverAttachesFullScreenIntentAtSupportedLowerBound() {
        postGraceAlert()

        val posted = postedNotification()
        assertNotNull("Grace alert must be posted", posted)
        assertNull(
            "Play build must not attach a full-screen intent",
            posted!!.fullScreenIntent,
        )
    }

    @Test
    @Config(sdk = [34])
    fun graceAlertRemainsHeadsUpOnAndroid14() {
        Shadows.shadowOf(RuntimeEnvironment.getApplication())
            .grantPermissions(Manifest.permission.POST_NOTIFICATIONS)

        postGraceAlert()

        val posted = postedNotification()
        assertNotNull("Heads-up alert must still be posted", posted)
        assertNull(
            "Play build must not attach a full-screen intent",
            posted!!.fullScreenIntent,
        )
    }
}
