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
                    val sessionId = call.argument<String>("sessionId") ?: CheckInScheduler.SESSION_CHECK_IN
                    val phase = call.argument<String>("phase") ?: CheckInScheduler.PHASE_MAIN
                    val deadlineMs = call.argument<Number>("deadlineMs")?.toLong() ?: 0L
                    val graceDurationMs = call.argument<Number>("graceDurationMs")?.toLong() ?: 0L
                    val primaryNumber = call.argument<String>("primaryNumber")
                    CheckInScheduler.schedule(context, sessionId, phase, deadlineMs, graceDurationMs, primaryNumber)
                    result.success(mapOf(
                        "scheduled" to true,
                        "exact" to CheckInScheduler.canScheduleExactAlarms(context)
                    ))
                }
                "didCheckInAlarmFire" -> {
                    val sessionId = call.argument<String>("sessionId") ?: CheckInScheduler.SESSION_CHECK_IN
                    result.success(CheckInScheduler.didAlarmFire(context, sessionId))
                }
                "cancelCheckIn" -> {
                    val sessionId = call.argument<String>("sessionId") ?: CheckInScheduler.SESSION_CHECK_IN
                    CheckInScheduler.cancel(context, sessionId)
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
                    result.success(EmergencyExecutor.executeEmergency(context, primaryNumber))
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
                    val dispatchId = call.argument<String>("dispatchId").orEmpty()
                    if (deadlineMs <= 0L || primaryNumber.isBlank() || dispatchId.isBlank()) {
                        result.success(mapOf("scheduled" to false, "exact" to false))
                        return
                    }
                    CountdownAlarmScheduler.schedule(context, deadlineMs, primaryNumber, dispatchId)
                    result.success(mapOf(
                        "scheduled" to true,
                        "exact" to CheckInScheduler.canScheduleExactAlarms(context)
                    ))
                }
                "cancelCountdownAlarm" -> {
                    val dispatchId = call.argument<String>("dispatchId")
                    result.success(CountdownAlarmScheduler.cancel(context, dispatchId))
                }
                "didCountdownAlarmFire" -> {
                    val dispatchId = call.argument<String>("dispatchId").orEmpty()
                    result.success(CountdownAlarmScheduler.didAlarmFire(context, dispatchId))
                }
                "clearEmergencyPrefs" -> {
                    // KVKK Md.7 (silme): reset path wipes the native emergency store
                    // (primary contact number) so it does not survive data deletion.
                    EmergencyPrefs.clear(context)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("EMERGENCY_PLATFORM_ERROR", "Emergency platform request failed", null)
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
