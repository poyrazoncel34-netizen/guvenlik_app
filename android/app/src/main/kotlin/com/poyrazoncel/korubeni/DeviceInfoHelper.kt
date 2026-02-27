package com.poyrazoncel.korubeni

import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/**
 * Device information helper for Crashlytics context
 */
object DeviceInfoHelper {
    
    fun getDeviceInfo(context: Context): Map<String, String> {
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "android_version" to Build.VERSION.RELEASE,
            "sdk_int" to Build.VERSION.SDK_INT.toString(),
            "device" to Build.DEVICE,
            "board" to Build.BOARD,
            "hardware" to Build.HARDWARE,
            "is_doze_mode" to isInDozeMode(context).toString(),
            "is_power_save_mode" to isPowerSaveMode(context).toString(),
            "device_id" to getDeviceId(context)
        )
    }
    
    private fun isInDozeMode(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isDeviceIdleMode ?: false
        } catch (e: Exception) {
            false
        }
    }
    
    private fun isPowerSaveMode(context: Context): Boolean {
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isPowerSaveMode ?: false
        } catch (e: Exception) {
            false
        }
    }
    
    private fun getDeviceId(context: Context): String {
        return try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        } catch (e: Exception) {
            "unknown"
        }
    }
}
