package com.poyrazoncel.korubeni

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SmsPlugin(private val activity: FlutterActivity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.poyrazoncel.korubeni/sms"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sendSms" -> handleSendSms(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleSendSms(call: MethodCall, result: MethodChannel.Result) {
        val phone = call.argument<String>("phone")
        val message = call.argument<String>("message")

        if (phone.isNullOrBlank() || message.isNullOrBlank()) {
            result.error("INVALID_ARGS", "Phone and message are required", null)
            return
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasPermission) {
            result.error("NO_PERMISSION", "SEND_SMS permission not granted", null)
            return
        }

        try {
            @Suppress("DEPRECATION")
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            
            if (parts.size > 1) {
                // Multipart SMS - send with delivery confirmation
                android.util.Log.d("SmsPlugin", "Sending multipart SMS: ${parts.size} parts")
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                // Single SMS
                android.util.Log.d("SmsPlugin", "Sending single SMS")
                smsManager.sendTextMessage(phone, null, message, null, null)
            }
            
            android.util.Log.d("SmsPlugin", "SMS sent successfully to $phone")
            result.success(true)
        } catch (e: SecurityException) {
            android.util.Log.e("SmsPlugin", "SecurityException: ${e.message}")
            result.error("PERMISSION_DENIED", "SMS permission denied at runtime", e.message)
        } catch (e: IllegalArgumentException) {
            android.util.Log.e("SmsPlugin", "IllegalArgumentException: ${e.message}")
            result.error("INVALID_NUMBER", "Invalid phone number format", e.message)
        } catch (e: Exception) {
            android.util.Log.e("SmsPlugin", "SMS failed: ${e.message}", e)
            result.error("SMS_FAILED", e.message ?: "Unknown error", null)
        }
    }
}
