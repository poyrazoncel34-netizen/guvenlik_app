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
    private val OFFICIAL_EMERGENCY_SHORT_CODES = setOf("112", "911", "999", "110", "155", "156", "122")

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
            mapOf("status" to "failed", "number" to normalizeEmergencyTarget(primaryNumber))
        } finally {
            try {
                wakeLock?.release()
            } catch (_: Exception) {}
        }
    }

    private fun openCall(context: Context, number: String): Map<String, Any?> {
        val cleaned = normalizeEmergencyTarget(number)

        val canDirect = ContextCompat.checkSelfPermission(
            context, Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED
        Log.i(TAG, "EMERGENCY_CALL_TRIGGERED path=${if (canDirect) "ACTION_CALL" else "ACTION_DIAL"}")

        if (canDirect) {
            try {
                startTelIntent(context, Intent.ACTION_CALL, cleaned)
                return mapOf("status" to "directCallStarted", "number" to cleaned)
            } catch (e: Exception) {
                Log.e(TAG, "ACTION_CALL failed; falling back to ACTION_DIAL")
            }
        }

        try {
            startTelIntent(context, Intent.ACTION_DIAL, cleaned)
            return mapOf("status" to "dialerOpened", "number" to cleaned)
        } catch (e: Exception) {
            Log.e(TAG, "ACTION_DIAL primary fallback failed")
        }

        if (cleaned != "112") {
            Log.e(TAG, "FALLBACK_112 primary dial intent failed")
            startTelIntent(context, Intent.ACTION_DIAL, "112")
            return mapOf("status" to "dialerOpened", "number" to "112")
        }

        throw IllegalStateException("No emergency call or dial intent could be opened")
    }

    private fun startTelIntent(context: Context, action: String, number: String) {
        val intent = Intent(action).apply {
            data = Uri.parse("tel:${Uri.encode(number)}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    private fun normalizeEmergencyTarget(number: String): String {
        val cleaned = number.trim().ifEmpty { "112" }
        val digits = cleaned.filter { it.isDigit() }
        val valid = OFFICIAL_EMERGENCY_SHORT_CODES.contains(digits) || digits.length >= 7
        return if (valid) cleaned else "112"
    }
}
