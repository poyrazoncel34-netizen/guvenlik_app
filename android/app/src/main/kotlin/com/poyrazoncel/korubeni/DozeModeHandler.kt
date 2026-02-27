package com.poyrazoncel.korubeni

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel

/**
 * Doze Mode whitelist handler for Android.
 * 
 * Allows the app to bypass Doze Mode restrictions, critical for emergency apps
 * that need to send alerts even when the device is in deep sleep.
 */
class DozeModeHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    
    companion object {
        const val CHANNEL = "com.poyrazoncel.korubeni/doze"
    }
    
    override fun onMethodCall(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDozeWhitelisted" -> {
                result.success(isWhitelisted())
            }
            "requestDozeWhitelist" -> {
                requestWhitelist()
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Check if app is whitelisted from Doze Mode restrictions.
     */
    private fun isWhitelisted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            // Doze Mode introduced in Android 6.0 (API 23)
            return true
        }
        
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (powerManager == null) {
                android.util.Log.e("DozeModeHandler", "PowerManager not available")
                return false
            }
            
            val packageName = context.packageName
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } catch (e: Exception) {
            android.util.Log.e("DozeModeHandler", "isWhitelisted check failed: ${e.message}")
            false
        }
    }
    
    /**
     * Request Doze Mode whitelist by opening system settings.
     */
    private fun requestWhitelist() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }
        
        try {
            val intent = Intent().apply {
                action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                data = Uri.parse("package:${context.packageName}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("DozeModeHandler", "Failed to open Doze settings", e)
            
            // Fallback: open general battery optimization settings
            try {
                val fallbackIntent = Intent().apply {
                    action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(fallbackIntent)
            } catch (e2: Exception) {
                android.util.Log.e("DozeModeHandler", "Fallback also failed", e2)
            }
        }
    }
}
