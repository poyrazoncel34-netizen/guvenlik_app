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
    const val CHANNEL_ALERTS = "korubeni_alerts_high"
    const val CHANNEL_SERVICE = "korubeni_service_low"
    const val CHANNEL_GENERAL = "korubeni_general_default"
    const val SHAKE_SERVICE_NOTIFICATION_ID = 7301
    const val RECORDING_NOTIFICATION_ID = 7302
    const val CHECK_IN_NOTIFICATION_ID = 7303

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channels = listOf(
            NotificationChannel(
                CHANNEL_ALERTS,
                "Acil Durum Bildirimleri",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Check-in ve acil durum uyarilari"
                setBypassDnd(true)
                enableVibration(true)
            },
            NotificationChannel(
                CHANNEL_SERVICE,
                "Servis Durumu",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shake algilama ve kayit oturumu durumu"
            },
            NotificationChannel(
                CHANNEL_GENERAL,
                "Genel Bildirimler",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Genel uygulama bilgilendirmeleri"
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
    ) = NotificationCompat.Builder(context, CHANNEL_SERVICE)
        .setSmallIcon(R.drawable.ic_bg_service_small)
        .setContentTitle(title)
        .setContentText(body)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setCategory(NotificationCompat.CATEGORY_SERVICE)
        .setOngoing(true)
        .setAutoCancel(false)
        .setContentIntent(buildLaunchPendingIntent(context, triggerType))
        .build()

    fun showAlert(
        context: Context,
        id: Int,
        title: String,
        body: String,
        triggerType: String,
    ) {
        if (!canPostNotifications(context)) {
            return
        }
        ensureChannels(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ALERTS)
            .setSmallIcon(R.drawable.ic_bg_service_small)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(buildLaunchPendingIntent(context, triggerType))
            .build()

        NotificationManagerCompat.from(context).notify(id, notification)
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
