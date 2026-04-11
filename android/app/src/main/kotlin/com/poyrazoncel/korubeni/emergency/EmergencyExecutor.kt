package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Native-side emergency executor — runs independently of Flutter.
 * If the Flutter engine dies mid-emergency, this continues the call
 * dispatch on the Android side.
 *
 * Acquires a partial wake lock to prevent CPU sleep during dispatch.
 */
object EmergencyExecutor {
    private const val TAG = "EmergencyExecutor"

    fun executeEmergency(
        context: Context,
        primaryNumber: String,
    ): Map<String, Any?> {
        // Acquire wake lock to keep CPU alive during dispatch
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "KoruBeni:EmergencyExec"
        )?.apply { acquire(120_000) } // 2 minutes max

        return try {
            val result = openCall(context, primaryNumber)
            Log.i(TAG, "Call dispatch result: ${result["status"]}")
            result
        } catch (e: Exception) {
            Log.e(TAG, "Call dispatch failed")
            mapOf("status" to "failed", "number" to primaryNumber.trim())
        } finally {
            try {
                wakeLock?.release()
            } catch (_: Exception) {}
        }
    }

    private fun openCall(context: Context, number: String): Map<String, Any?> {
        val cleaned = number.trim()
        if (cleaned.isEmpty()) {
            return mapOf("status" to "failed", "number" to cleaned)
        }

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
        return mapOf(
            "status" to if (canDirect) "directCallStarted" else "dialerOpened",
            "number" to cleaned,
        )
    }
}
