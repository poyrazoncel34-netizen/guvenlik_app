package com.poyrazoncel.korubeni.notifications

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver
import com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ScheduledNotificationManifestInstrumentationTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val packageManager = context.packageManager

    @Test
    fun installedPackageDeclaresScheduledDeliveryReceiver() {
        val info = packageManager.getReceiverInfo(
            ComponentName(context, ScheduledNotificationReceiver::class.java),
            PackageManager.ComponentInfoFlags.of(0),
        )

        assertTrue(info.enabled)
        assertFalse("scheduled notifications are app-private", info.exported)
    }

    @Test
    fun installedPackageRoutesBootToPluginRescheduler() {
        val expected = ComponentName(context, ScheduledNotificationBootReceiver::class.java)
        val matches = packageManager.queryBroadcastReceivers(
            Intent(Intent.ACTION_BOOT_COMPLETED).setPackage(context.packageName),
            PackageManager.ResolveInfoFlags.of(0),
        )

        assertTrue(
            "BOOT_COMPLETED must reach the plugin's scheduled-notification rescheduler",
            matches.any {
                val activity = it.activityInfo ?: return@any false
                ComponentName(activity.packageName, activity.name) == expected
            },
        )
    }
}
