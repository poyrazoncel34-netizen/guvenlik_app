package com.poyrazoncel.korubeni.emergency

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

/** Clears the actionable fallback and its retained phone target on dismiss/TTL. */
class EmergencyFallbackCleanupReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        EmergencyReceiverGuard.run(
            context,
            NativeSafetyEventCode.FALLBACK_CLEANUP_RECEIVER_BOUNDARY_FAILURE,
        ) {
            val token = SessionToken(
                protocolVersion = intent?.getIntExtra(EXTRA_PROTOCOL_VERSION, -1) ?: -1,
                randomId = intent?.getStringExtra(EXTRA_RANDOM_ID).orEmpty(),
                generation = intent?.getLongExtra(EXTRA_GENERATION, -1L) ?: -1L,
                kind = SessionKind.fromWire(intent?.getStringExtra(EXTRA_KIND)) ?: return@run,
            )
            if (
                token.protocolVersion != EMERGENCY_PROTOCOL_VERSION ||
                token.randomId.isBlank() || token.generation <= 0L
            ) return@run

            val notificationId = intent?.getIntExtra(EXTRA_NOTIFICATION_ID, -1) ?: -1
            val expiresAtMs = intent?.getLongExtra(EXTRA_EXPIRES_AT_MS, -1L) ?: -1L
            val expired = EmergencySessionRuntime.coordinator(context).expireFallback(token)
            // A stale generation may share the kind-level notification ID with
            // a newer fallback. Never let its cleanup cancel the newer action.
            if (!expired) return@run
            if (notificationId >= 0) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as? NotificationManager
                manager?.cancel(notificationId)
            }
            EmergencyFallbackDialActivity.pendingIntent(
                context,
                token,
                notificationId,
                expiresAtMs,
            ).cancel()
        }
    }

    companion object {
        private const val ACTION_CLEANUP =
            "com.poyrazoncel.korubeni.EMERGENCY_FALLBACK_CLEANUP"
        private const val EXTRA_PROTOCOL_VERSION = "protocol_version"
        private const val EXTRA_RANDOM_ID = "random_id"
        private const val EXTRA_GENERATION = "generation"
        private const val EXTRA_KIND = "kind"
        private const val EXTRA_NOTIFICATION_ID = "notification_id"
        private const val EXTRA_EXPIRES_AT_MS = "expires_at_ms"
        private const val REQUEST_CODE = 42590

        fun pendingIntent(
            context: Context,
            token: SessionToken,
            notificationId: Int,
            expiresAtMs: Long,
        ): PendingIntent {
            val intent = Intent(context, EmergencyFallbackCleanupReceiver::class.java).apply {
                action = ACTION_CLEANUP
                data = Uri.Builder()
                    .scheme("korubeni")
                    .authority("fallback-cleanup")
                    .appendPath(token.kind.wireValue)
                    .appendPath(token.randomId)
                    .appendPath(token.generation.toString())
                    .build()
                putExtra(EXTRA_PROTOCOL_VERSION, token.protocolVersion)
                putExtra(EXTRA_RANDOM_ID, token.randomId)
                putExtra(EXTRA_GENERATION, token.generation)
                putExtra(EXTRA_KIND, token.kind.wireValue)
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_EXPIRES_AT_MS, expiresAtMs)
            }
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun schedule(
            context: Context,
            cleanupIntent: PendingIntent,
            expiresAtMs: Long,
        ): Boolean {
            val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: return false
            return try {
                if (
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                    manager.canScheduleExactAlarms()
                ) {
                    manager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        expiresAtMs,
                        cleanupIntent,
                    )
                } else {
                    // Permission can be revoked after arm. Keep a best-effort
                    // cleanup rather than dropping the actionable fallback.
                    manager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        expiresAtMs,
                        cleanupIntent,
                    )
                }
                true
            } catch (_: SecurityException) {
                false
            } catch (_: RuntimeException) {
                false
            }
        }

        fun fallbackIdentity(token: SessionToken): String =
            "fallback:${token.kind.wireValue}:${token.randomId}:${token.generation}"
    }
}
