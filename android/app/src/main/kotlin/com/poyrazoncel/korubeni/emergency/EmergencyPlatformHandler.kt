package com.poyrazoncel.korubeni.emergency

import android.app.Activity
import android.app.AlarmManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telephony.TelephonyManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class EmergencyPlatformHandler(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    private val context: Context = activity.applicationContext

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "armEmergencySession" -> {
                    result.success(armEmergencySession(call).toMap())
                }
                "cancelEmergencySession" -> {
                    val token = tokenFromCall(call)
                    if (token == null) {
                        result.success(mapOf(
                            "type" to "unknown",
                            "reasonCode" to "invalidToken",
                        ))
                    } else {
                        result.success(
                            EmergencySessionRuntime.coordinator(context)
                                .cancel(token)
                                .toMap(),
                        )
                    }
                }
                "readEmergencySession" -> {
                    result.success(readEmergencySession(call))
                }
                "readEmergencySessionByKind" -> {
                    result.success(readEmergencySessionByKind(call))
                }
                "dispatchEmergencySession" -> {
                    val token = tokenFromCall(call)
                    if (token == null) {
                        result.success(mapOf(
                            "callRequestOutcome" to "notAttempted",
                            "fallbackOutcome" to "notAttempted",
                            "connectionState" to "unknown",
                            "reasonCode" to "invalidToken",
                        ))
                    } else {
                        result.success(
                            EmergencySessionRuntime.coordinator(context)
                                .claimAndDispatch(token)
                                .toMap(),
                        )
                    }
                }
                "getEmergencyCapabilities" -> {
                    result.success(getEmergencyCapabilities(call).toMap())
                }
                "wipeEmergencySessions" -> {
                    val wipe = EmergencySessionRuntime.coordinator(context).wipe()
                    if (wipe.status == WipeStatus.COMPLETED) {
                        // Remove pre-v1 credential-protected remnants only
                        // after the authoritative device-protected wipe is
                        // durably acknowledged.
                        EmergencyPrefs.clear(context)
                        if (!clearNativeSafetyDiagnostics()) {
                            result.success(
                                WipeResult(
                                    WipeStatus.PENDING,
                                    "nativeDiagnosticsWipeFailed",
                                ).toMap(),
                            )
                            return
                        }
                    }
                    result.success(wipe.toMap())
                }
                // Removed production safety authorities. Keeping these names
                // explicitly notImplemented lets old Flutter code fail closed
                // while every supported flow uses the typed coordinator API.
                "scheduleCheckIn",
                "didCheckInAlarmFire",
                "getCheckInDeadlineState",
                "cancelCheckIn",
                "executeEmergencyNative",
                "scheduleCountdownAlarm",
                "cancelCountdownAlarm",
                "didCountdownAlarmFire",
                "clearEmergencyPrefs" -> result.notImplemented()
                "consumePendingTrigger" -> {
                    result.success(EmergencyEventBus.consumePendingTrigger(context))
                }
                "canScheduleExactAlarms" -> {
                    result.success(canScheduleExactAlarms())
                }
                "requestExactAlarmPermission" -> {
                    openExactAlarmSettings()
                    result.success(true)
                }
                "getDeviceState" -> {
                    result.success(getDeviceState())
                }
                "readNativeSafetyDiagnostics" -> {
                    result.success(
                        DeviceProtectedNativeSafetyEventRing(context)
                            .read()
                            .map(NativeSafetyEvent::toMap),
                    )
                }
                "openManufacturerSettings" -> {
                    result.success(openManufacturerSettings())
                }
                "requestBatteryOptimizationExemption" -> {
                    result.success(requestBatteryOptimizationExemption())
                }
                "openBatteryOptimizationSettings" -> {
                    result.success(openBatteryOptimizationSettings())
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("EMERGENCY_PLATFORM_ERROR", "Emergency platform request failed", null)
        }
    }

    private fun armEmergencySession(call: MethodCall): ArmResult {
        val protocol = call.argument<Number>("protocolVersion")?.toInt() ?: -1
        val kind = SessionKind.fromWire(call.argument<String>("kind"))
            ?: return ArmResult.Rejected("invalidKind")
        val randomId = call.argument<String>("randomId").orEmpty()
        val requestedGeneration =
            call.argument<Number>("requestedGeneration")?.toLong() ?: -1L
        val mainDeadline = call.argument<Number>("mainDeadlineMs")?.toLong() ?: -1L
        val finalDeadline = call.argument<Number>("finalDeadlineMs")?.toLong() ?: -1L
        val target = call.argument<String>("target").orEmpty()
        val entitlement = EntitlementDecision.fromWire(
            call.argument<String>("entitlementDecision"),
        )
        val pinConfigured = call.argument<Boolean>("pinConfigured") == true
        return EmergencySessionRuntime.coordinator(context).arm(
            ArmRequest(
                protocolVersion = protocol,
                randomId = randomId,
                kind = kind,
                mainDeadlineMs = mainDeadline,
                finalDeadlineMs = finalDeadline,
                target = target,
                entitlementDecision = entitlement,
                pinConfigured = pinConfigured,
                requestedGeneration = requestedGeneration,
            ),
        )
    }

    private fun readEmergencySession(call: MethodCall): Map<String, Any?> {
        val token = tokenFromCall(call)
            ?: return mapOf("type" to "corrupted", "reasonCode" to "invalidToken")
        val read = EmergencySessionRuntime.coordinator(context).read(token.kind)
        if (read is ReadSessionResult.Present && read.envelope.token != token) {
            return ReadSessionResult.Absent.toMap()
        }
        return read.toMap()
    }

    /**
     * Recovers the native authority when Flutter's best-effort projection was
     * never written (for example, process death immediately after native ARM).
     * The caller still has to prove protocol and requested kind.  A different
     * long-running kind shares the same native slot but is never projected as
     * the requested controller.
     */
    private fun readEmergencySessionByKind(call: MethodCall): Map<String, Any?> {
        val protocol = call.argument<Number>("protocolVersion")?.toInt() ?: -1
        if (protocol != EMERGENCY_PROTOCOL_VERSION) {
            return mapOf("type" to "corrupted", "reasonCode" to "unsupportedProtocol")
        }
        val kind = SessionKind.fromWire(call.argument<String>("kind"))
            ?: return mapOf("type" to "corrupted", "reasonCode" to "invalidKind")
        val read = EmergencySessionRuntime.coordinator(context).read(kind)
        if (read is ReadSessionResult.Present && read.envelope.token.kind != kind) {
            return ReadSessionResult.Absent.toMap()
        }
        return read.toMap()
    }

    private fun getEmergencyCapabilities(call: MethodCall): CapabilitySnapshot {
        val callableTarget = call.argument<Boolean>("callableTarget") == true
        val entitlement = EntitlementDecision.fromWire(
            call.argument<String>("entitlementDecision"),
        )
        return AndroidEmergencyCapabilityProvider(context).snapshot(
            ArmRequest(
                protocolVersion = call.argument<Number>("protocolVersion")?.toInt() ?: -1,
                randomId = "capability-probe",
                kind = SessionKind.CHECK_IN,
                mainDeadlineMs = System.currentTimeMillis() + 60_000L,
                finalDeadlineMs = System.currentTimeMillis() + 120_000L,
                target = if (callableTarget) "+900000000000" else "",
                entitlementDecision = entitlement,
                pinConfigured = call.argument<Boolean>("pinConfigured") == true,
            ),
        )
    }

    private fun tokenFromCall(call: MethodCall): SessionToken? {
        val raw = call.argument<Map<String, Any?>>("token")
        return SessionToken.fromMap(raw)
    }

    private fun getDeviceState(): Map<String, Any?> {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val capabilities = AndroidEmergencyCapabilityProvider(context).snapshot(
            ArmRequest(
                protocolVersion = EMERGENCY_PROTOCOL_VERSION,
                randomId = "readiness-probe",
                kind = SessionKind.CHECK_IN,
                mainDeadlineMs = System.currentTimeMillis() + 60_000L,
                finalDeadlineMs = System.currentTimeMillis() + 120_000L,
                target = "+905000000000",
                entitlementDecision = EntitlementDecision.AUTHORIZED,
                pinConfigured = true,
            ),
        )

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
            "supportedOs" to capabilities.supportedOs,
            "telephonyCalling" to capabilities.telephonyCalling,
            "telecomAvailable" to capabilities.telecomAvailable,
            "dialHandlerAvailable" to capabilities.dialHandlerAvailable,
            "canScheduleExactAlarms" to capabilities.exactAlarmGranted,
            "callPermissionGranted" to capabilities.callPermissionGranted,
            "notificationsEnabled" to capabilities.notificationsEnabled,
            "alertChannelHigh" to capabilities.alertChannelHigh,
        )
    }

    private fun clearNativeSafetyDiagnostics(): Boolean = try {
        DeviceProtectedNativeSafetyEventRing(context).clear()
    } catch (_: RuntimeException) {
        false
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

    /**
     * Opens Android's app-scoped exemption request. This method is exposed
     * only through the emergency platform channel and must be reached from an
     * explicit user gesture after the in-app disclosure.
     *
     * A true result means only that Android accepted the intent. It does not
     * mean the user granted the exemption; callers must read device state
     * again after the app resumes.
     */
    private fun requestBatteryOptimizationExemption(): Boolean {
        return launchIntent(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
            },
        )
    }

    /** Opens the generic system list without requesting an exemption. */
    private fun openBatteryOptimizationSettings(): Boolean {
        return launchIntent(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
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

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        return alarmManager?.canScheduleExactAlarms() == true
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }
}
