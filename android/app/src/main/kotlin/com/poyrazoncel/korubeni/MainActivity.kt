package com.poyrazoncel.korubeni

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val volumeDetector = VolumeButtonDetector()
    private lateinit var dozeModeHandler: DozeModeHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            val messenger = flutterEngine.dartExecutor.binaryMessenger

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
}
