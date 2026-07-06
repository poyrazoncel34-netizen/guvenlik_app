package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
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

    // Distinct from the launch PendingIntent request codes (triggerType hash)
    // so the dial intent never overwrites / gets overwritten by an app-launch
    // PendingIntent for the same notification flow.
    private const val DIAL_REQUEST_CODE = 42101

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
                setBypassDnd(true)
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

    /**
     * Direct-dial PendingIntent for dispatch-failure alerts: opens the system
     * dialer pre-filled with the persisted number. Deliberately NOT an
     * app-launch intent — the in-app PIN gate must never stand between a
     * failed automatic call and the manual fail-safe dial. Uri.fromParts
     * keeps '+' intact without manual encoding. No trampoline: the activity
     * is started directly from the notification's PendingIntent.
     */
    fun buildDialPendingIntent(context: Context, number: String): PendingIntent {
        val intent = Intent(Intent.ACTION_DIAL).apply {
            data = Uri.fromParts("tel", number.trim(), null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return PendingIntent.getActivity(
            context,
            DIAL_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
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
        fullScreen: Boolean = false,
        contentIntent: PendingIntent? = null,
    ) {
        if (!canPostNotifications(context)) {
            return
        }
        ensureChannels(context)
        val builder = NotificationCompat.Builder(context, CHANNEL_ALERTS)
            .setSmallIcon(R.drawable.ic_bg_service_small)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentIntent ?: buildLaunchPendingIntent(context, triggerType))

        // SPEC 3.1/3.3/3.6b: use a full-screen intent for the grace prompt WHEN the
        // platform/user permits it; otherwise degrade gracefully to a high-priority
        // heads-up notification. Must never crash on denial (Android 14+ runtime
        // restriction). USE_FULL_SCREEN_INTENT is declared in the manifest
        // (2026-07-06, SPEC 3.6a closed); on devices where the system still
        // withholds it (Android 14+ non call/alarm default) this stays heads-up.
        if (fullScreen && canUseFullScreenIntent(context)) {
            builder.setFullScreenIntent(
                buildLaunchPendingIntent(context, triggerType),
                true,
            )
        }

        NotificationManagerCompat.from(context).notify(id, builder.build())
    }

    private fun canUseFullScreenIntent(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager
                manager.canUseFullScreenIntent()
            } else {
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun canPostNotifications(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }
}
