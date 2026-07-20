package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Fixed diagnostic vocabulary for failures at Android safety boundaries.
 *
 * There is intentionally no free-form message, exception, token, target or
 * metadata field. Adding a code is a source-reviewed schema change.
 */
enum class NativeSafetyEventCode(val wireValue: String) {
    BOOT_RECEIVER_BOUNDARY_FAILURE("boot_receiver_boundary_failure"),
    CLOCK_RECEIVER_BOUNDARY_FAILURE("clock_receiver_boundary_failure"),
    EXACT_ALARM_PERMISSION_RECEIVER_BOUNDARY_FAILURE(
        "exact_alarm_permission_receiver_boundary_failure",
    ),
    PANIC_RECEIVER_BOUNDARY_FAILURE("panic_receiver_boundary_failure"),
    LONG_SESSION_RECEIVER_BOUNDARY_FAILURE("long_session_receiver_boundary_failure"),
    FALLBACK_CLEANUP_RECEIVER_BOUNDARY_FAILURE(
        "fallback_cleanup_receiver_boundary_failure",
    );

    companion object {
        fun fromWire(value: String?): NativeSafetyEventCode? =
            entries.firstOrNull { it.wireValue == value }
    }
}

data class NativeSafetyEvent(
    val code: NativeSafetyEventCode,
    val occurredAtMs: Long,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "code" to code.wireValue,
        "occurredAtMs" to occurredAtMs,
    )
}

/**
 * Small Direct-Boot-readable ring used only for redacted native diagnostics.
 * It is deliberately separate from the authoritative emergency-session store.
 */
class DeviceProtectedNativeSafetyEventRing(
    context: Context,
    private val clockMs: () -> Long = System::currentTimeMillis,
) {
    private val prefs: SharedPreferences = context.applicationContext
        .createDeviceProtectedStorageContext()
        .getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

    fun record(code: NativeSafetyEventCode): Boolean = synchronized(PROCESS_LOCK) {
        val retained = readInternal().takeLast(MAX_EVENTS - 1).toMutableList()
        retained += NativeSafetyEvent(code, clockMs())
        writeInternal(retained)
    }

    fun read(): List<NativeSafetyEvent> = synchronized(PROCESS_LOCK) {
        readInternal().takeLast(MAX_EVENTS)
    }

    fun clear(): Boolean = synchronized(PROCESS_LOCK) {
        try {
            prefs.edit().clear().commit()
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun readInternal(): List<NativeSafetyEvent> {
        return try {
            val raw = prefs.getString(EVENTS_KEY, null) ?: return emptyList()
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val value = array.optJSONObject(index) ?: continue
                    val code = NativeSafetyEventCode.fromWire(
                        value.optString(CODE_KEY),
                    ) ?: continue
                    val occurredAtMs = value.optLong(OCCURRED_AT_KEY, -1L)
                    if (occurredAtMs <= 0L) continue
                    add(NativeSafetyEvent(code, occurredAtMs))
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun writeInternal(events: List<NativeSafetyEvent>): Boolean {
        return try {
            val payload = JSONArray()
            events.takeLast(MAX_EVENTS).forEach { event ->
                payload.put(
                    JSONObject()
                        .put(CODE_KEY, event.code.wireValue)
                        .put(OCCURRED_AT_KEY, event.occurredAtMs),
                )
            }
            prefs.edit().putString(EVENTS_KEY, payload.toString()).commit()
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        const val MAX_EVENTS = 64
        private const val FILE_NAME = "korubeni_native_safety_events_v1"
        private const val EVENTS_KEY = "events"
        private const val CODE_KEY = "code"
        private const val OCCURRED_AT_KEY = "occurredAtMs"
        private val PROCESS_LOCK = Any()
    }
}

internal object NativeSafetyEventRecorder {
    fun record(context: Context, code: NativeSafetyEventCode) {
        try {
            DeviceProtectedNativeSafetyEventRing(context).record(code)
        } catch (_: RuntimeException) {
            // Diagnostics are best-effort and can never interrupt safety work.
        }
    }
}
