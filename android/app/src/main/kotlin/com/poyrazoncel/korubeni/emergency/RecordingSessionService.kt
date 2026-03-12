package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import androidx.core.content.ContextCompat
import android.app.Service

class RecordingSessionService : Service() {
    companion object {
        private const val ACTION_START = "action_start"
        private const val ACTION_STOP = "action_stop"

        fun start(context: Context) {
            val intent = Intent(context, RecordingSessionService::class.java).apply {
                action = ACTION_START
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, RecordingSessionService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> startSession()
        }
        return START_STICKY
    }

    private fun startSession() {
        EmergencyNotificationHelper.ensureChannels(this)
        startForeground(
            EmergencyNotificationHelper.RECORDING_NOTIFICATION_ID,
            EmergencyNotificationHelper.buildOngoingServiceNotification(
                this,
                "Ses kaydi devam ediyor",
                "Durdurmak icin bildirime dokunun.",
                "recordingSession"
            )
        )
        if (wakeLock?.isHeld != true) {
            val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = manager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "KoruBeni:RecordingSession"
            ).apply {
                acquire(35 * 60 * 1000L) // 35 min — 5 min above the 30-min Dart recording limit
            }
        }
    }

    override fun onDestroy() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
