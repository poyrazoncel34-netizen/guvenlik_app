package com.poyrazoncel.korubeni.emergency

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SmsStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val recipient = intent.getStringExtra("recipient").orEmpty()
        val messageId = intent.getStringExtra("messageId").orEmpty()
        val phase = if (action == SmsSender.ACTION_SMS_SENT) "sent" else "delivery"
        val success = resultCode == Activity.RESULT_OK

        EmergencyEventBus.emit(
            mapOf(
                "type" to "smsStatus",
                "phase" to phase,
                "success" to success,
                "recipient" to recipient,
                "messageId" to messageId,
                "resultCode" to resultCode,
            )
        )
    }
}
