package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.TelecomManager
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

object EmergencySessionRuntime {
    fun coordinator(context: Context): EmergencySessionCoordinator {
        val appContext = context.applicationContext
        return EmergencySessionCoordinator(
            store = DeviceProtectedEmergencySessionStore(appContext),
            alarmScheduler = AndroidEmergencySessionAlarmScheduler(appContext),
            fallbackPoster = AndroidEmergencyFallbackPoster(appContext),
            callRequester = AndroidEmergencyCallRequester(appContext),
            capabilityProvider = AndroidEmergencyCapabilityProvider(appContext),
        )
    }
}

class AndroidEmergencyCapabilityProvider(
    private val context: Context,
) : EmergencyCapabilityProvider {
    override fun snapshot(request: ArmRequest): CapabilitySnapshot {
        EmergencyNotificationHelper.ensureChannels(context)
        val packageManager = context.packageManager
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        val alertChannelHigh = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = notificationManager
                ?.getNotificationChannel(EmergencyNotificationHelper.CHANNEL_ALERTS)
                ?.importance ?: NotificationManager.IMPORTANCE_NONE
            importance >= NotificationManager.IMPORTANCE_HIGH
        } else {
            true
        }
        val exactAlarmGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager?.canScheduleExactAlarms() == true
        } else {
            true
        }
        val dialIntent = Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", "0", null))
        val telecom = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager

        return CapabilitySnapshot(
            supportedOs = Build.VERSION.SDK_INT in 29..36,
            telephonyCalling = packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY),
            telecomAvailable = telecom != null,
            dialHandlerAvailable = dialIntent.resolveActivity(packageManager) != null,
            exactAlarmGranted = exactAlarmGranted,
            notificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled(),
            alertChannelHigh = alertChannelHigh,
            callPermissionGranted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.CALL_PHONE,
            ) == PackageManager.PERMISSION_GRANTED,
            pinConfigured = request.pinConfigured,
            callableTarget = EmergencyTargetValidator.isCallable(request.target),
            entitlementDecision = request.entitlementDecision,
        )
    }
}

class AndroidEmergencyCallRequester(
    private val context: Context,
) : EmergencyCallRequester {
    override fun requestCall(target: String): CallRequestOutcome {
        val cleaned = EmergencyTargetValidator.normalizedCallableOrNull(target)
            ?: return CallRequestOutcome.FAILED
        if (
            ContextCompat.checkSelfPermission(context, Manifest.permission.CALL_PHONE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return CallRequestOutcome.FAILED
        }
        val telecom = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
            ?: return CallRequestOutcome.FAILED
        return try {
            // This proves only that the request was submitted to Android's
            // Telecom service. Ringing/connection state remains unknowable.
            telecom.placeCall(Uri.fromParts("tel", cleaned, null), Bundle())
            CallRequestOutcome.SUBMITTED_UNCONFIRMED
        } catch (_: SecurityException) {
            CallRequestOutcome.FAILED
        } catch (_: RuntimeException) {
            CallRequestOutcome.FAILED
        }
    }
}

class AndroidEmergencyFallbackPoster(
    private val context: Context,
) : EmergencyFallbackPoster {
    override fun post(envelope: EmergencySessionEnvelope): FallbackOutcome {
        val target = envelope.target
        if (!EmergencyTargetValidator.isCallable(target)) return FallbackOutcome.FAILED
        val copy = NativeNotificationText.manualFallback(context)
        val notificationId = notificationId(envelope.token.kind)
        val dialIntent = EmergencyFallbackDialActivity.pendingIntent(
            context,
            envelope.token,
            notificationId,
            envelope.fallbackExpiresAtMs,
        )
        val cleanupIntent = EmergencyFallbackCleanupReceiver.pendingIntent(
            context,
            envelope.token,
            notificationId,
            envelope.fallbackExpiresAtMs,
        )
        val posted = EmergencyNotificationHelper.showAlert(
            context = context,
            id = notificationId,
            title = copy.title,
            body = copy.body,
            triggerType = "emergencyManualFallback",
            contentIntent = dialIntent,
            deleteIntent = cleanupIntent,
        )
        if (!posted) {
            cleanupIntent.cancel()
            dialIntent.cancel()
            return FallbackOutcome.FAILED
        }
        val cleanupScheduled = EmergencyFallbackCleanupReceiver.schedule(
            context,
            cleanupIntent,
            envelope.fallbackExpiresAtMs,
        )
        if (!cleanupScheduled) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
                ?.cancel(notificationId)
            cleanupIntent.cancel()
            dialIntent.cancel()
            return FallbackOutcome.FAILED
        }
        return FallbackOutcome.POSTED
    }

    override fun clear(envelope: EmergencySessionEnvelope) {
        val notificationId = notificationId(envelope.token.kind)
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
            ?.cancel(notificationId)
        val dialIntent = EmergencyFallbackDialActivity.pendingIntent(
            context,
            envelope.token,
            notificationId,
            envelope.fallbackExpiresAtMs,
        )
        val cleanupIntent = EmergencyFallbackCleanupReceiver.pendingIntent(
            context,
            envelope.token,
            notificationId,
            envelope.fallbackExpiresAtMs,
        )
        dialIntent.cancel()
        (context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager)
            ?.cancel(cleanupIntent)
        cleanupIntent.cancel()
    }

    private fun notificationId(kind: SessionKind): Int = when (kind) {
        SessionKind.PANIC -> EmergencyNotificationHelper.COUNTDOWN_DISPATCH_FAILED_NOTIFICATION_ID
        SessionKind.CHECK_IN -> EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID
        SessionKind.SAFE_WALK -> EmergencyNotificationHelper.SAFE_WALK_NOTIFICATION_ID
    }
}

class AndroidEmergencySessionAlarmScheduler(
    private val context: Context,
) : EmergencySessionAlarmScheduler {
    override fun schedule(envelope: EmergencySessionEnvelope): AlarmScheduleResult {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return AlarmScheduleResult(false, false)
        val exactIntent = pendingIntent(envelope.token, exact = true)
        val inexactIntent = pendingIntent(envelope.token, exact = false)
        val triggerAt = envelope.elapsedRealtimeDeadlineMs

        val exactAccepted = if (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        ) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    manager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAt,
                        exactIntent,
                    )
                } else {
                    manager.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, exactIntent)
                }
                true
            } catch (_: SecurityException) {
                false
            } catch (_: RuntimeException) {
                false
            }
        } else {
            false
        }

        val inexactAccepted = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                manager.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    inexactIntent,
                )
            } else {
                manager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, inexactIntent)
            }
            true
        } catch (_: RuntimeException) {
            false
        }
        return AlarmScheduleResult(exactAccepted, inexactAccepted)
    }

    override fun cancel(token: SessionToken) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        manager.cancel(pendingIntent(token, exact = true))
        manager.cancel(pendingIntent(token, exact = false))
    }

    private fun pendingIntent(token: SessionToken, exact: Boolean): PendingIntent {
        val receiver = if (token.kind == SessionKind.PANIC) {
            CountdownAlarmReceiver::class.java
        } else {
            CheckInAlarmReceiver::class.java
        }
        val identity = if (exact) "exact" else "inexact"
        val intent = Intent(context, receiver).apply {
            action = ACTION_DISPATCH
            data = Uri.Builder()
                .scheme("korubeni")
                .authority("emergency-session")
                .appendPath(token.kind.wireValue)
                .appendPath(token.randomId)
                .appendPath(token.generation.toString())
                .appendPath(identity)
                .build()
            putExtra(EXTRA_PROTOCOL_VERSION, token.protocolVersion)
            putExtra(EXTRA_RANDOM_ID, token.randomId)
            putExtra(EXTRA_GENERATION, token.generation)
            putExtra(EXTRA_KIND, token.kind.wireValue)
        }
        return PendingIntent.getBroadcast(
            context,
            if (exact) EXACT_REQUEST_CODE else INEXACT_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        const val ACTION_DISPATCH = "com.poyrazoncel.korubeni.EMERGENCY_SESSION_DISPATCH"
        const val EXTRA_PROTOCOL_VERSION = "emergency_protocol_version"
        const val EXTRA_RANDOM_ID = "emergency_random_id"
        const val EXTRA_GENERATION = "emergency_generation"
        const val EXTRA_KIND = "emergency_kind"
        private const val EXACT_REQUEST_CODE = 42501
        private const val INEXACT_REQUEST_CODE = 42502

        fun tokenFromIntent(intent: Intent?): SessionToken? {
            if (intent?.action != ACTION_DISPATCH) return null
            val protocol = intent.getIntExtra(EXTRA_PROTOCOL_VERSION, -1)
            val randomId = intent.getStringExtra(EXTRA_RANDOM_ID).orEmpty()
            val generation = intent.getLongExtra(EXTRA_GENERATION, -1L)
            val kind = SessionKind.fromWire(intent.getStringExtra(EXTRA_KIND)) ?: return null
            if (protocol != EMERGENCY_PROTOCOL_VERSION || randomId.isBlank() || generation <= 0L) {
                return null
            }
            return SessionToken(protocol, randomId, generation, kind)
        }
    }
}
