package com.poyrazoncel.korubeni.notifications

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
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
        val info = receiverInfo(ComponentName(context, ScheduledNotificationReceiver::class.java))

        assertTrue(info.enabled)
        assertFalse("scheduled notifications are app-private", info.exported)
    }

    @Test
    fun installedPackageRoutesBootToPluginRescheduler() {
        val expected = ComponentName(context, ScheduledNotificationBootReceiver::class.java)
        val matches = bootReceivers(
            Intent(Intent.ACTION_BOOT_COMPLETED).setPackage(context.packageName),
        )

        assertTrue(
            "BOOT_COMPLETED must reach the plugin's scheduled-notification rescheduler",
            matches.any {
                val activity = it.activityInfo ?: return@any false
                ComponentName(activity.packageName, activity.name) == expected
            },
        )
    }

    // The *Flags.of overloads exist only from API 33; minSdk is 29, and on an
    // API 29 emulator they threw NoSuchMethodError (chaos audit 2026-10-08).
    @Suppress("DEPRECATION")
    private fun receiverInfo(component: ComponentName) =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getReceiverInfo(component, PackageManager.ComponentInfoFlags.of(0))
        } else {
            packageManager.getReceiverInfo(component, 0)
        }

    @Suppress("DEPRECATION")
    private fun bootReceivers(intent: Intent) =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryBroadcastReceivers(intent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            packageManager.queryBroadcastReceivers(intent, 0)
        }
}
