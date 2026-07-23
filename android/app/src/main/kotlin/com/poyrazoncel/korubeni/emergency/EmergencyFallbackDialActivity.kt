package com.poyrazoncel.korubeni.emergency

import android.app.Activity
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Native, Direct-Boot-capable notification action gate. The immutable
 * PendingIntent lands here (not in Flutter), the stored token/TTL is checked
 * fail-closed, and only then is the user-initiated ACTION_DIAL opened.
 */
class EmergencyFallbackDialActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val token = tokenFromIntent(intent)
        val notificationId = intent?.getIntExtra(EXTRA_NOTIFICATION_ID, -1) ?: -1
        val expiresAtMs = intent?.getLongExtra(EXTRA_EXPIRES_AT_MS, -1L) ?: -1L
        val target = token?.let {
            EmergencySessionRuntime.coordinator(this)
                .consumeFallbackTarget(it, expiresAtMs)
        }
        if (token != null && target != null && EmergencyTargetValidator.isCallable(target)) {
            try {
                startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", target, null)))
                cleanupRetainedActions(token, notificationId, expiresAtMs)
            } catch (_: RuntimeException) {
                // Keep the already visible action usable if Android cannot
                // resolve/open the dialer. The same token/target/TTL is restored
                // only while no newer session has replaced it.
                EmergencySessionRuntime.coordinator(this)
                    .restoreConsumedFallbackTarget(token, expiresAtMs, target)
            }
        }
        finish()
    }

    private fun cleanupRetainedActions(
        token: SessionToken,
        notificationId: Int,
        expiresAtMs: Long,
    ) {
        if (notificationId >= 0) {
            (getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
                ?.cancel(notificationId)
        }
        EmergencyFallbackCleanupReceiver.pendingIntent(
            this,
            token,
            notificationId,
            expiresAtMs,
        ).cancel()
    }

    companion object {
        private const val EXTRA_PROTOCOL_VERSION = "protocol_version"
        private const val EXTRA_RANDOM_ID = "random_id"
        private const val EXTRA_GENERATION = "generation"
        private const val EXTRA_KIND = "kind"
        private const val EXTRA_NOTIFICATION_ID = "notification_id"
        private const val EXTRA_EXPIRES_AT_MS = "expires_at_ms"

        fun pendingIntent(
            context: Context,
            token: SessionToken,
            notificationId: Int,
            expiresAtMs: Long,
        ): PendingIntent {
            val intent = Intent(context, EmergencyFallbackDialActivity::class.java).apply {
                data = Uri.Builder()
                    .scheme("korubeni")
                    .authority("fallback-dial")
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
            return PendingIntent.getActivity(
                context,
                EmergencyFallbackCleanupReceiver.fallbackIdentity(token).hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun tokenFromIntent(intent: Intent?): SessionToken? {
            val protocol = intent?.getIntExtra(EXTRA_PROTOCOL_VERSION, -1) ?: -1
            val randomId = intent?.getStringExtra(EXTRA_RANDOM_ID).orEmpty()
            val generation = intent?.getLongExtra(EXTRA_GENERATION, -1L) ?: -1L
            val kind = SessionKind.fromWire(intent?.getStringExtra(EXTRA_KIND)) ?: return null
            if (
                protocol != EMERGENCY_PROTOCOL_VERSION ||
                randomId.isBlank() || generation <= 0L
            ) return null
            return SessionToken(protocol, randomId, generation, kind)
        }
    }
}
