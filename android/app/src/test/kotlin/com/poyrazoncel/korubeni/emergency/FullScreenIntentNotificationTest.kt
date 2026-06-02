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
 * SPEC §3.1 / §3.3 / §3.6b: the grace prompt uses a full-screen intent WHEN the
 * platform permits it, and degrades gracefully to a high-priority heads-up
 * notification (no crash) when the Android 14+ runtime restriction denies it.
 *
 * Robolectric's NotificationManager.canUseFullScreenIntent() defaults to false
 * on API 34 (denied), while pre-34 the capability is available — so the two SDK
 * levels deterministically exercise both branches without a shadow setter.
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
            fullScreen = true,
        )
    }

    private fun postedNotification() =
        Shadows.shadowOf(notificationManager)
            .getNotification(EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID)

    @Test
    @Config(sdk = [28])
    fun graceAlertUsesFullScreenIntentWhenPermitted() {
        postGraceAlert()

        val posted = postedNotification()
        assertNotNull("Grace alert must be posted", posted)
        assertNotNull(
            "Must attach a full-screen intent when the platform permits it",
            posted!!.fullScreenIntent,
        )
    }

    @Test
    @Config(sdk = [34])
    fun graceAlertFallsBackToHeadsUpWhenFullScreenDenied() {
        // API 34 runtime restriction: canUseFullScreenIntent() is false by default.
        Shadows.shadowOf(RuntimeEnvironment.getApplication())
            .grantPermissions(Manifest.permission.POST_NOTIFICATIONS)

        postGraceAlert() // must NOT throw

        val posted = postedNotification()
        assertNotNull("Heads-up alert must still be posted", posted)
        assertNull(
            "Must NOT attach a full-screen intent when denied (heads-up fallback)",
            posted!!.fullScreenIntent,
        )
    }
}
