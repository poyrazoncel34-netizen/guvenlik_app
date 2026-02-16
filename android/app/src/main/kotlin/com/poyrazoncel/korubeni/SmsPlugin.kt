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
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, null, null)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("SMS_FAILED", e.message, null)
        }
    }
}
