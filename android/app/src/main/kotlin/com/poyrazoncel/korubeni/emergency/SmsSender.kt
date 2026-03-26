package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.os.Build
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import com.poyrazoncel.korubeni.BuildConfig
import java.util.UUID
import java.util.concurrent.Executors

object SmsSender {
    const val ACTION_SMS_SENT = "com.poyrazoncel.korubeni.SMS_SENT"
    const val ACTION_SMS_DELIVERED = "com.poyrazoncel.korubeni.SMS_DELIVERED"
    private val executor = Executors.newFixedThreadPool(5)

    fun send(
        context: Context,
        activity: Activity?,
        recipients: List<String>,
        message: String,
    ): Map<String, Any?> {
        val cleaned = recipients
            .map { it.replace(Regex("[\\s\\-()]"), "") }
            .filter { it.isNotBlank() }
            .distinct()

        if (cleaned.isEmpty()) {
            return mapOf("status" to "failed", "error" to "no_recipients")
        }

        if (!BuildConfig.ALLOW_DIRECT_SMS) {
            return openComposer(context, activity, cleaned, message)
        }

        val smsPermissionGranted =
            ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) ==
                PackageManager.PERMISSION_GRANTED
        if (!smsPermissionGranted) {
            return openComposer(context, activity, cleaned, message)
        }

        if (isAirplaneModeOn(context)) {
            return mapOf("status" to "failed", "error" to "airplane_mode")
        }

        if (!hasSim(context)) {
            return mapOf("status" to "failed", "error" to "sim_unavailable")
        }

        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        cleaned.forEachIndexed { index, recipient ->
            executor.execute {
                try {
                    val messageId = UUID.randomUUID().toString()
                    val parts = smsManager.divideMessage(message)
                    val sentIntents = ArrayList<PendingIntent>(parts.size)
                    val deliveredIntents = ArrayList<PendingIntent>(parts.size)

                    parts.indices.forEach { partIndex ->
                        sentIntents += statusPendingIntent(
                            context,
                            ACTION_SMS_SENT,
                            recipient,
                            messageId,
                            index * 100 + partIndex,
                        )
                        deliveredIntents += statusPendingIntent(
                            context,
                            ACTION_SMS_DELIVERED,
                            recipient,
                            messageId,
                            index * 100 + partIndex + 50,
                        )
                    }

                    smsManager.sendMultipartTextMessage(
                        recipient,
                        null,
                        parts,
                        sentIntents,
                        deliveredIntents,
                    )
                } catch (e: Exception) {
                    android.util.Log.e("SmsSender", "SMS dispatch failed for recipient: ${e.message}", e)
                    // Non-fatal: malformed number or SmsManager error — other recipients continue
                }
            }
        }

        return mapOf(
            "status" to "nativeDispatched",
            "direct" to true,
            "recipients" to cleaned,
        )
    }

    private fun openComposer(
        context: Context,
        activity: Activity?,
        recipients: List<String>,
        message: String,
    ): Map<String, Any?> {
        return try {
            val recipientsString = recipients.joinToString(";")
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = android.net.Uri.parse("smsto:${android.net.Uri.encode(recipientsString)}")
                putExtra("address", recipientsString)
                putExtra("sms_body", message)
                if (activity == null) {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
            (activity ?: context).startActivity(intent)
            mapOf(
                "status" to "composerOpened",
                "direct" to false,
                "recipients" to recipients,
            )
        } catch (e: Exception) {
            mapOf("status" to "failed", "error" to (e.message ?: "composer_failed"))
        }
    }

    private fun statusPendingIntent(
        context: Context,
        action: String,
        recipient: String,
        messageId: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, SmsStatusReceiver::class.java).apply {
            this.action = action
            putExtra("recipient", recipient)
            putExtra("messageId", messageId)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun hasSim(context: Context): Boolean {
        val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            ?: return false
        return when (telephonyManager.simState) {
            TelephonyManager.SIM_STATE_READY,
            TelephonyManager.SIM_STATE_PIN_REQUIRED,
            TelephonyManager.SIM_STATE_PUK_REQUIRED,
            TelephonyManager.SIM_STATE_NETWORK_LOCKED -> true
            else -> false
        }
    }

    private fun isAirplaneModeOn(context: Context): Boolean {
        return Settings.Global.getInt(
            context.contentResolver,
            Settings.Global.AIRPLANE_MODE_ON,
            0,
        ) == 1
    }
}
