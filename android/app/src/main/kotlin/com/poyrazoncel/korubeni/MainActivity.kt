package com.poyrazoncel.korubeni

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.KeyEvent
import android.view.WindowManager
import com.poyrazoncel.korubeni.emergency.EmergencyChannels
import com.poyrazoncel.korubeni.emergency.EmergencyEventStreamHandler
import com.poyrazoncel.korubeni.emergency.EmergencyPlatformHandler
import com.poyrazoncel.korubeni.emergency.PhoneStateStreamHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val ANDROID_INTENTS_CHANNEL = "com.poyrazoncel.korubeni/android_intents"
        private const val SETTINGS_CHANNEL = "com.poyrazoncel.korubeni/settings"
    }

    private val volumeDetector = VolumeButtonDetector()
    private lateinit var dozeModeHandler: DozeModeHandler
    private lateinit var emergencyPlatformHandler: EmergencyPlatformHandler
    private lateinit var phoneStateStreamHandler: PhoneStateStreamHandler

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            val messenger = flutterEngine.dartExecutor.binaryMessenger
            emergencyPlatformHandler = EmergencyPlatformHandler(this)
            phoneStateStreamHandler = PhoneStateStreamHandler(applicationContext)

            // Volume button EventChannel — Flutter'a sürekli event akışı
            try {
                EventChannel(messenger, VolumeButtonDetector.CHANNEL)
                    .setStreamHandler(volumeDetector)
                android.util.Log.d("MainActivity", "Volume detector EventChannel configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Volume EventChannel failed: ${e.message}", e)
            }

            // Volume button MethodChannel — enable/disable kontrolü
            try {
                MethodChannel(messenger, "${VolumeButtonDetector.CHANNEL}/control")
                    .setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
                                "setEnabled" -> {
                                    val enabled = call.argument<Boolean>("enabled") ?: false
                                    volumeDetector.setEnabled(enabled)
                                    result.success(true)
                                }
                                else -> result.notImplemented()
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Volume control error: ${e.message}")
                            result.error("ERROR", e.message, null)
                        }
                    }
                android.util.Log.d("MainActivity", "Volume detector MethodChannel configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Volume MethodChannel failed: ${e.message}", e)
            }

            // Doze Mode handler — battery optimization bypass
            try {
                dozeModeHandler = DozeModeHandler(this)
                MethodChannel(messenger, DozeModeHandler.CHANNEL)
                    .setMethodCallHandler(dozeModeHandler)
                android.util.Log.d("MainActivity", "Doze Mode handler configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Doze Mode handler failed: ${e.message}", e)
            }

            try {
                MethodChannel(messenger, EmergencyChannels.METHOD)
                    .setMethodCallHandler(emergencyPlatformHandler)
                EventChannel(messenger, EmergencyChannels.EVENTS)
                    .setStreamHandler(EmergencyEventStreamHandler())
                EventChannel(messenger, EmergencyChannels.PHONE_STATE)
                    .setStreamHandler(phoneStateStreamHandler)
                android.util.Log.d("MainActivity", "Emergency platform configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Emergency platform failed: ${e.message}", e)
            }

            try {
                MethodChannel(messenger, ANDROID_INTENTS_CHANNEL)
                    .setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
                                "openDialer" -> {
                                    val number = call.argument<String>("number").orEmpty()
                                    result.success(openDialer(number))
                                }
                                else -> result.notImplemented()
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Android intents error: ${e.message}", e)
                            result.error("ANDROID_INTENTS_ERROR", e.message, null)
                        }
                    }
                android.util.Log.d("MainActivity", "Android intent channel configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Android intent channel failed: ${e.message}", e)
            }
            
            // Settings channel (extended) — battery optimization + manufacturer auto-start
            try {
                MethodChannel(messenger, SETTINGS_CHANNEL)
                    .setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
                                "openBatterySettings" -> {
                                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                        Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                            data = Uri.parse("package:$packageName")
                                        }
                                    } else {
                                        Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
                                    }
                                    startActivity(intent)
                                    result.success(true)
                                }
                                "openActivityByComponent" -> {
                                    val component = call.argument<String>("component").orEmpty()
                                    if (component.isEmpty()) {
                                        result.error("INVALID_ARG", "component is empty", null)
                                        return@setMethodCallHandler
                                    }
                                    val parts = component.split("/")
                                    if (parts.size != 2) {
                                        result.error("INVALID_ARG", "component format must be pkg/class", null)
                                        return@setMethodCallHandler
                                    }
                                    val intent = Intent().apply {
                                        setComponent(ComponentName(parts[0], parts[1]))
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(intent)
                                    result.success(true)
                                }
                                else -> result.notImplemented()
                            }
                        } catch (e: ActivityNotFoundException) {
                            result.error("NOT_FOUND", "Settings screen not available: ${e.message}", null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                android.util.Log.d("MainActivity", "Settings channel (extended) configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Settings channel (extended) failed: ${e.message}", e)
            }

            android.util.Log.i("MainActivity", "All platform channels configured successfully")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Critical: configureFlutterEngine failed", e)
            // Don't crash - let Flutter handle it
        }
    }

    /**
     * Tüm key event'lerini yakalar. Eğer volume tuşuysa ve
     * VolumeButtonDetector aktifse, event consume edilir (ses değişmez).
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (volumeDetector.onKeyEvent(event)) {
            return true // Event consume edildi
        }
        return super.dispatchKeyEvent(event)
    }
    
    /**
     * Lifecycle cleanup - prevent memory leaks
     */
    override fun onDestroy() {
        try {
            volumeDetector.setEnabled(false)
            android.util.Log.d("MainActivity", "Resources cleaned up")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Cleanup failed: ${e.message}")
        }
        super.onDestroy()
    }

    private fun openDialer(number: String): Boolean {
        val cleaned = number.trim()
        if (cleaned.isEmpty()) {
            return false
        }

        val intent = Intent(Intent.ACTION_DIAL).apply {
            data = Uri.parse("tel:$cleaned")
        }

        return startExternalIntent(intent)
    }

    private fun startExternalIntent(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            android.util.Log.e("MainActivity", "Intent launch failed: ${e.message}", e)
            false
        }
    }
}
