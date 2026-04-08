package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class EmergencyPlatformHandler(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    private val context: Context = activity.applicationContext

    fun openBatterySettingsProxy(): Boolean = openBatterySettings()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "scheduleCheckIn" -> {
                    val phase = call.argument<String>("phase") ?: CheckInScheduler.PHASE_MAIN
                    val deadlineMs = call.argument<Number>("deadlineMs")?.toLong() ?: 0L
                    val graceDurationMs = call.argument<Number>("graceDurationMs")?.toLong() ?: 0L
                    CheckInScheduler.schedule(context, phase, deadlineMs, graceDurationMs)
                    result.success(true)
                }
                "cancelCheckIn" -> {
                    CheckInScheduler.cancel(context)
                    result.success(true)
                }
                "consumePendingTrigger" -> {
                    result.success(EmergencyEventBus.consumePendingTrigger(context))
                }
                "canScheduleExactAlarms" -> {
                    result.success(CheckInScheduler.canScheduleExactAlarms(context))
                }
                "requestExactAlarmPermission" -> {
                    CheckInScheduler.openExactAlarmSettings(context)
                    result.success(true)
                }
                "executeEmergencyNative" -> {
                    val primaryNumber = call.argument<String>("primaryNumber").orEmpty()
                    EmergencyExecutor.executeEmergency(context, primaryNumber)
                    result.success(mapOf("status" to "dispatched"))
                }
                "getDeviceState" -> {
                    result.success(getDeviceState())
                }
                "openManufacturerSettings" -> {
                    result.success(openManufacturerSettings())
                }
                "openBatterySettings" -> {
                    result.success(openBatterySettings())
                }
                "scheduleCountdownAlarm" -> {
                    val deadlineMs = call.argument<Number>("deadlineMs")?.toLong() ?: 0L
                    val primaryNumber = call.argument<String>("primaryNumber").orEmpty()
                    CountdownAlarmScheduler.schedule(context, deadlineMs, primaryNumber)
                    result.success(true)
                }
                "cancelCountdownAlarm" -> {
                    CountdownAlarmScheduler.cancel(context)
                    result.success(true)
                }
                "didCountdownAlarmFire" -> {
                    result.success(CountdownAlarmScheduler.didAlarmFire(context))
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("EMERGENCY_PLATFORM_ERROR", e.message, null)
        }
    }

    private fun getDeviceState(): Map<String, Any?> {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val callGranted =
            ContextCompat.checkSelfPermission(context, Manifest.permission.CALL_PHONE) ==
                PackageManager.PERMISSION_GRANTED

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "sdkInt" to Build.VERSION.SDK_INT,
            "isAirplaneModeOn" to (Settings.Global.getInt(
                context.contentResolver,
                Settings.Global.AIRPLANE_MODE_ON,
                0
            ) == 1),
            "simState" to (telephonyManager?.simState ?: TelephonyManager.SIM_STATE_UNKNOWN),
            "hasSim" to (telephonyManager?.simState == TelephonyManager.SIM_STATE_READY),
            "batteryOptimizationsIgnored" to
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
                } else {
                    true
                }),
            "canScheduleExactAlarms" to CheckInScheduler.canScheduleExactAlarms(context),
            "callPermissionGranted" to callGranted,
        )
    }

    private fun openManufacturerSettings(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val candidates = when {
            manufacturer.contains("xiaomi") -> listOf(
                Intent().apply {
                    component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity",
                    )
                }
            )
            manufacturer.contains("samsung") -> listOf(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            )
            manufacturer.contains("huawei") -> listOf(
                Intent().apply {
                    component = ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.optimize.process.ProtectActivity",
                    )
                }
            )
            manufacturer.contains("oneplus") -> listOf(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            )
            else -> emptyList()
        } + Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)

        return candidates.firstOrNull { launchIntent(it) } != null
    }

    private fun openBatterySettings(): Boolean {
        val candidates = listOf(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
            },
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
        )
        return candidates.firstOrNull { launchIntent(it) } != null
    }

    private fun openCall(number: String): Map<String, Any?> {
        val cleaned = number.trim()
        if (cleaned.isEmpty()) {
            return mapOf("status" to "failed")
        }

        val canDirectCall =
            ContextCompat.checkSelfPermission(context, Manifest.permission.CALL_PHONE) ==
                PackageManager.PERMISSION_GRANTED
        val intent = if (canDirectCall) {
            Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:${Uri.encode(cleaned)}")
            }
        } else {
            Intent(Intent.ACTION_DIAL).apply {
                data = Uri.parse("tel:${Uri.encode(cleaned)}")
            }
        }

        return if (launchIntent(intent)) {
            mapOf("status" to if (canDirectCall) "directCallStarted" else "dialerOpened")
        } else {
            mapOf("status" to "failed")
        }
    }

    private fun launchIntent(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
