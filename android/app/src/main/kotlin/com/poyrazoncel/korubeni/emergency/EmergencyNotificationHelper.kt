package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.poyrazoncel.korubeni.MainActivity
import com.poyrazoncel.korubeni.R

object EmergencyNotificationHelper {
    const val CHANNEL_ALERTS = "emergency_alerts"
    const val CHANNEL_SERVICE = "service_status"
    const val CHANNEL_GENERAL = "general_notifications"
    const val CHECK_IN_NOTIFICATION_ID = 7303
    const val COUNTDOWN_DISPATCH_FAILED_NOTIFICATION_ID = 7304
    const val SAFE_WALK_NOTIFICATION_ID = 7305

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channels = listOf(
            NotificationChannel(
                CHANNEL_ALERTS,
                NativeNotificationText.channelName(context, CHANNEL_ALERTS),
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = NativeNotificationText.channelDescription(context, CHANNEL_ALERTS)
                enableVibration(true)
            },
            NotificationChannel(
                CHANNEL_SERVICE,
                NativeNotificationText.channelName(context, CHANNEL_SERVICE),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = NativeNotificationText.channelDescription(context, CHANNEL_SERVICE)
            },
            NotificationChannel(
                CHANNEL_GENERAL,
                NativeNotificationText.channelName(context, CHANNEL_GENERAL),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = NativeNotificationText.channelDescription(context, CHANNEL_GENERAL)
            },
        )

        manager.createNotificationChannels(channels)
    }

    fun buildLaunchPendingIntent(
        context: Context,
        triggerType: String? = null,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (triggerType != null) {
                putExtra("pending_trigger_type", triggerType)
            }
        }
        return PendingIntent.getActivity(
            context,
            triggerType?.hashCode() ?: 0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun buildOngoingServiceNotification(
        context: Context,
        title: String,
        body: String,
        triggerType: String? = null,
    ) = NativeNotificationText.serviceActive(context).let { fallback ->
        NotificationCompat.Builder(context, CHANNEL_SERVICE)
            .setSmallIcon(R.drawable.ic_bg_service_small)
            .setContentTitle(title.ifBlank { fallback.title })
            .setContentText(body.ifBlank { fallback.body })
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(buildLaunchPendingIntent(context, triggerType))
            .build()
    }

    fun showAlert(
        context: Context,
        id: Int,
        title: String,
        body: String,
        triggerType: String,
        contentIntent: PendingIntent? = null,
        deleteIntent: PendingIntent? = null,
    ): Boolean {
        return try {
            ensureChannels(context)
            if (!canPostNotifications(context)) {
                return false
            }
            val builder = NotificationCompat.Builder(context, CHANNEL_ALERTS)
                .setSmallIcon(R.drawable.ic_bg_service_small)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                // Alert bodies can include an emergency contact number. Keep the
                // content private while the device is locked.
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setAutoCancel(true)
                .setContentIntent(contentIntent ?: buildLaunchPendingIntent(context, triggerType))
                .setDeleteIntent(deleteIntent)

            NotificationManagerCompat.from(context).notify(id, builder.build())
            true
        } catch (_: SecurityException) {
            false
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun canPostNotifications(context: Context): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as? NotificationManager ?: return false
            val channel = manager.getNotificationChannel(CHANNEL_ALERTS) ?: return false
            if (channel.importance < NotificationManager.IMPORTANCE_HIGH) {
                return false
            }
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }
}
