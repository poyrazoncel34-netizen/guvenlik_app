package com.poyrazoncel.korubeni.integrity

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.poyrazoncel.korubeni.BuildConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `com.poyrazoncel.korubeni/device_integrity` — `probe` returns the per-check
 * map of [DeviceIntegrityProbe.run]. The probe does file and process I/O, so
 * it never runs on the platform thread. Any failure is a channel error, which
 * the Dart side classifies as unknown, never clean.
 */
object DeviceIntegrityChannel {
    const val NAME = "com.poyrazoncel.korubeni/device_integrity"
    private const val TAG = "DeviceIntegrity"

    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            if (call.method != "probe") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                // One daemon thread per call, not a shared executor: a syscall that
                // blocks forever strands only its own call (Dart times out at 3 s and
                // reports unknown), never every later probe of this process.
                Thread({
                    val started = SystemClock.elapsedRealtime()
                    val reply: Map<String, String>? = try {
                        DeviceIntegrityProbe().run()
                    } catch (_: Exception) {
                        null
                    }
                    val elapsed = SystemClock.elapsedRealtime() - started
                    if (BuildConfig.DEBUG) {
                        // Debug builds only: check names and outcomes, no paths or data.
                        Log.i(TAG, "DEVICE_INTEGRITY_PROBE ms=$elapsed result=$reply")
                    }
                    mainHandler.post {
                        if (reply == null) {
                            result.error("PROBE_FAILED", "integrity probe failed", null)
                        } else {
                            result.success(reply)
                        }
                    }
                }, "device-integrity-probe").apply {
                    isDaemon = true
                    start()
                }
            } catch (_: Exception) {
                result.error("PROBE_UNAVAILABLE", "integrity probe could not start", null)
            }
        }
    }
}
