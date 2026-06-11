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
 *
 * Calls ONLY the explicitly configured emergency target. It never synthesizes,
 * coerces, or falls back to 112 (or any other official short code): if the
 * target cannot be opened with ACTION_CALL or ACTION_DIAL, it returns
 * status=failed so the caller can run its own fail-safe (manual-dial dialog).
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

    /**
     * Kotlin mirror of the Dart normalizePhoneNumber chokepoint: keep digits
     * plus a single leading '+', drop every separator. Defense-in-depth for
     * numbers persisted RAW by older builds (audit F5) — makes a storage
     * migration unnecessary because stale values are sanitized at dial time.
     */
    fun sanitizeForDial(raw: String): String {
        val stripped = raw.trim().filter { it.isDigit() || it == '+' }
        if (stripped.isEmpty()) return ""
        return if (stripped.first() == '+') {
            "+" + stripped.drop(1).filter { it.isDigit() }
        } else {
            stripped.filter { it.isDigit() }
        }
    }

    private fun openCall(context: Context, number: String): Map<String, Any?> {
        val cleaned = sanitizeForDial(number)

        // No configured target — never synthesize 112. Report failure so the
        // caller surfaces the manual-dial fail-safe instead of calling anyone.
        if (cleaned.isEmpty()) {
            Log.e(TAG, "No emergency target configured; nothing to dial")
            return mapOf("status" to "failed", "number" to cleaned)
        }

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
            Log.e(TAG, "ACTION_DIAL failed; no emergency intent could be opened")
        }

        // Both ACTION_CALL and ACTION_DIAL failed. Do NOT fall back to 112 —
        // report failure and let the caller run its fail-safe flow.
        return mapOf("status" to "failed", "number" to cleaned)
    }

    private fun startTelIntent(context: Context, action: String, number: String) {
        val intent = Intent(action).apply {
            data = Uri.parse("tel:${Uri.encode(number)}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
