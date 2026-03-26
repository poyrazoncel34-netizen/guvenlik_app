package com.poyrazoncel.korubeni.emergency

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

class SmsStatusReceiver : BroadcastReceiver() {

    companion object {
        // Track per-dispatch results: messageId -> (total, failedCount)
        private val dispatches = ConcurrentHashMap<String, DispatchTracker>()

        fun registerDispatch(messageId: String, totalRecipients: Int) {
            dispatches[messageId] = DispatchTracker(totalRecipients)
        }
    }

    private class DispatchTracker(val total: Int) {
        val completed = AtomicInteger(0)
        val failed = AtomicInteger(0)
    }

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

        // SILENT-1: Track send-phase results to detect total failure
        if (phase == "sent") {
            val tracker = dispatches[messageId] ?: return
            if (!success) tracker.failed.incrementAndGet()
            if (tracker.completed.incrementAndGet() >= tracker.total) {
                dispatches.remove(messageId)
                if (tracker.failed.get() >= tracker.total) {
                    // All recipients failed — emit critical event
                    EmergencyEventBus.emit(
                        mapOf(
                            "type" to "smsAllFailed",
                            "messageId" to messageId,
                            "failedCount" to tracker.failed.get(),
                        )
                    )
                }
            }
        }
    }
}
