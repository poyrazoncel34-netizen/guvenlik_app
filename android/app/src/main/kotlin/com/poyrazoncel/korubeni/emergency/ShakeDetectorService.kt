package com.poyrazoncel.korubeni.emergency

import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import android.os.PowerManager
import androidx.core.content.ContextCompat
import kotlin.math.abs
import kotlin.math.sqrt

class ShakeDetectorService : Service(), SensorEventListener {
    companion object {
        private const val ACTION_START = "action_start"
        private const val ACTION_STOP = "action_stop"
        private const val ACTION_UPDATE = "action_update"

        fun start(context: Context) {
            val intent = Intent(context, ShakeDetectorService::class.java).apply {
                action = ACTION_START
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, ShakeDetectorService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        fun update(context: Context) {
            val intent = Intent(context, ShakeDetectorService::class.java).apply {
                action = ACTION_UPDATE
            }
            context.startService(intent)
        }
    }

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private val shakeTimestamps = ArrayDeque<Long>()
    private var lastTriggerAt: Long = 0L
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> startMonitoring()
        }
        return START_STICKY
    }

    private fun startMonitoring() {
        EmergencyNotificationHelper.ensureChannels(this)
        startForeground(
            EmergencyNotificationHelper.SHAKE_SERVICE_NOTIFICATION_ID,
            EmergencyNotificationHelper.buildOngoingServiceNotification(
                this,
                "Shake algilama aktif",
                "Telefonu sallayarak panik ekranini hazirlayin.",
                "shakeDetected"
            )
        )

        if (wakeLock?.isHeld != true) {
            val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = manager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "KoruBeni:ShakeDetector"
            ).apply {
                acquire(24 * 60 * 60 * 1000L) // 24h safety net; onDestroy() releases normally
            }
        }

        accelerometer?.let {
            sensorManager.unregisterListener(this)
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val values = event?.values ?: return
        val magnitude = sqrt(
            values[0] * values[0] + values[1] * values[1] + values[2] * values[2]
        )
        val threshold = when (
            EmergencyPrefs.prefs(this).getInt(EmergencyPrefs.KEY_SHAKE_SENSITIVITY, 1)
        ) {
            0 -> 22.0
            2 -> 10.0
            else -> 15.0
        }

        if (abs(magnitude - 9.8) <= threshold) {
            return
        }

        val now = System.currentTimeMillis()
        if (now - lastTriggerAt < 3000L) {
            return
        }

        while (shakeTimestamps.isNotEmpty() && now - shakeTimestamps.first() > 1500L) {
            shakeTimestamps.removeFirst()
        }
        shakeTimestamps.addLast(now)

        if (shakeTimestamps.size >= 3) {
            shakeTimestamps.clear()
            lastTriggerAt = now
            EmergencyEventBus.emitOrPersist(
                this,
                mapOf("type" to "shakeDetected", "timestamp" to now)
            )
            EmergencyNotificationHelper.showAlert(
                this,
                EmergencyNotificationHelper.SHAKE_SERVICE_NOTIFICATION_ID + 100,
                "Shake algilandi",
                "Panik geri sayimi icin uygulamayi acin.",
                "shakeDetected"
            )
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
