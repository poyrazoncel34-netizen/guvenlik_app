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
 * If the Flutter engine dies mid-emergency, this continues the call
 * dispatch on the Android side.
 *
 * Acquires a partial wake lock to prevent CPU sleep during dispatch.
 */
object EmergencyExecutor {
    private const val TAG = "EmergencyExecutor"
    private val executor = Executors.newFixedThreadPool(1)

    fun executeEmergency(
        context: Context,
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
                // Dispatch call
                try {
                    openCallDirect(context, primaryNumber)
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
        val cleaned = number.trim().ifEmpty { "112" }

        val canDirect = ContextCompat.checkSelfPermission(
            context, Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED

        Log.i(TAG, "EMERGENCY_CALL_TRIGGERED number=$cleaned CALL_PATH=${if (canDirect) "ACTION_CALL" else "ACTION_DIAL"}")

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

        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "FALLBACK_112 primary intent failed: ${e.message}")
            // HARD FAILSAFE — open 112 dialer no matter what
            try {
                val fallback = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:112")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(fallback)
            } catch (ignored: Exception) {
                Log.e(TAG, "112 dialer fallback also failed", ignored)
            }
        }
    }
}
