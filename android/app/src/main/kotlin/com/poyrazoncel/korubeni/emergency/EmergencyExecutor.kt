package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import java.util.concurrent.Executors

/**
 * Native-side emergency executor — runs independently of Flutter.
 * If the Flutter engine dies mid-emergency, this continues dispatching
 * SMS and call on the Android side.
 *
 * Acquires a partial wake lock to prevent CPU sleep during dispatch.
 */
object EmergencyExecutor {
    private const val TAG = "EmergencyExecutor"
    private val executor = Executors.newFixedThreadPool(3)

    fun executeEmergency(
        context: Context,
        recipients: List<String>,
        message: String,
        primaryNumber: String,
    ) {
        // Acquire wake lock to keep CPU alive during dispatch
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "KoruBeni:EmergencyExec"
        )?.apply { acquire(120_000) } // 2 minutes max

        executor.execute {
            try {
                // SILENT-2: Persist dispatch-attempted flag for Flutter to check on resume
                context.getSharedPreferences("emergency_executor", Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean("nativeDispatchAttempted", true)
                    .putLong("nativeDispatchTimestamp", System.currentTimeMillis())
                    .commit()

                // Dispatch SMS
                try {
                    SmsSender.send(context, null, recipients, message)
                    Log.i(TAG, "SMS dispatched to ${recipients.size} recipients")
                } catch (e: Exception) {
                    Log.e(TAG, "SMS dispatch failed", e)
                }

                // Dispatch call
                try {
                    openCallDirect(context, primaryNumber)
                    Log.i(TAG, "Call initiated to primary number")
                } catch (e: Exception) {
                    Log.e(TAG, "Call dispatch failed", e)
                }
            } finally {
                try {
                    wakeLock?.release()
                } catch (_: Exception) {}
            }
        }
    }

    private fun openCallDirect(context: Context, number: String) {
        val cleaned = number.trim()
        if (cleaned.isEmpty()) return

        val canDirect = ContextCompat.checkSelfPermission(
            context, Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED

        val intent = if (canDirect) {
            Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:${Uri.encode(cleaned)}")
            }
        } else {
            Intent(Intent.ACTION_DIAL).apply {
                data = Uri.parse("tel:${Uri.encode(cleaned)}")
            }
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}
