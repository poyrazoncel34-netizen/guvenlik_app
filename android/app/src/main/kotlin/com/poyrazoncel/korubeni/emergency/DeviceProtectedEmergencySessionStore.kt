package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.content.SharedPreferences

/**
 * Minimal Direct-Boot-readable envelope. This store intentionally contains no
 * PIN/lockout data, contact name, location, history, RevenueCat identifier, or
 * free-form logs. The normalized call target is retained only while armed or
 * while an actionable fallback remains inside its bounded retention window.
 */
class DeviceProtectedEmergencySessionStore(context: Context) : EmergencySessionStore {
    private val deviceContext = context.applicationContext.createDeviceProtectedStorageContext()
    private val prefs: SharedPreferences = deviceContext.getSharedPreferences(
        FILE_NAME,
        Context.MODE_PRIVATE,
    )

    override fun read(slot: SessionSlot): SessionRead {
        val prefix = prefix(slot)
        if (!prefs.contains(key(prefix, "schemaVersion"))) return SessionRead.Absent
        return try {
            val schemaVersion = prefs.getInt(key(prefix, "schemaVersion"), -1)
            if (schemaVersion != EMERGENCY_SESSION_SCHEMA_VERSION) {
                return SessionRead.Corrupted("unknownSchema")
            }
            val protocolVersion = prefs.getInt(key(prefix, "protocolVersion"), -1)
            if (protocolVersion != EMERGENCY_PROTOCOL_VERSION) {
                return SessionRead.Corrupted("unknownProtocol")
            }
            val randomId = prefs.getString(key(prefix, "randomId"), null).orEmpty()
            val generation = prefs.getLong(key(prefix, "generation"), -1L)
            val kind = SessionKind.fromWire(prefs.getString(key(prefix, "kind"), null))
                ?: return SessionRead.Corrupted("unknownKind")
            val lifecycle = LifecycleState.fromWire(
                prefs.getString(key(prefix, "lifecycleState"), null),
            ) ?: return SessionRead.Corrupted("unknownLifecycle")
            val target = prefs.getString(key(prefix, "target"), null)
                ?: return SessionRead.Corrupted("missingTarget")
            val mainDeadline = prefs.getLong(key(prefix, "mainDeadlineMs"), -1L)
            val finalDeadline = prefs.getLong(key(prefix, "finalDeadlineMs"), -1L)
            val elapsedDeadline = prefs.getLong(
                key(prefix, "elapsedRealtimeDeadlineMs"),
                -1L,
            )
            val schedulingMode = SchedulingMode.entries.firstOrNull {
                it.wireValue == prefs.getString(key(prefix, "schedulingMode"), null)
            } ?: return SessionRead.Corrupted("unknownSchedulingMode")
            val callOutcome = CallRequestOutcome.entries.firstOrNull {
                it.wireValue == prefs.getString(key(prefix, "callRequestOutcome"), null)
            } ?: return SessionRead.Corrupted("unknownCallOutcome")
            val fallbackOutcome = FallbackOutcome.entries.firstOrNull {
                it.wireValue == prefs.getString(key(prefix, "fallbackOutcome"), null)
            } ?: return SessionRead.Corrupted("unknownFallbackOutcome")
            val fallbackExpiry = prefs.getLong(key(prefix, "fallbackExpiresAtMs"), 0L)

            if (
                randomId.isBlank() || generation <= 0L || kind.slot != slot ||
                mainDeadline <= 0L || finalDeadline < mainDeadline || elapsedDeadline < 0L
            ) {
                return SessionRead.Corrupted("invalidEnvelope")
            }
            if (
                lifecycle in setOf(
                    LifecycleState.PREPARING,
                    LifecycleState.ARMED,
                    LifecycleState.CLAIMED,
                ) && !EmergencyTargetValidator.isCallable(target)
            ) {
                return SessionRead.Corrupted("invalidActiveTarget")
            }

            SessionRead.Present(
                EmergencySessionEnvelope(
                    schemaVersion = schemaVersion,
                    token = SessionToken(protocolVersion, randomId, generation, kind),
                    lifecycleState = lifecycle,
                    target = target,
                    mainDeadlineMs = mainDeadline,
                    finalDeadlineMs = finalDeadline,
                    elapsedRealtimeDeadlineMs = elapsedDeadline,
                    schedulingMode = schedulingMode,
                    callRequestOutcome = callOutcome,
                    fallbackOutcome = fallbackOutcome,
                    fallbackExpiresAtMs = fallbackExpiry,
                ),
            )
        } catch (_: ClassCastException) {
            SessionRead.Corrupted("typeMismatch")
        } catch (_: RuntimeException) {
            SessionRead.Corrupted("storeReadFailed")
        }
    }

    override fun write(envelope: EmergencySessionEnvelope): Boolean {
        val prefix = prefix(envelope.token.slot)
        val editor = prefs.edit()
        prefs.all.keys.filter { it.startsWith(prefix) }.forEach(editor::remove)
        editor
            .putInt(key(prefix, "schemaVersion"), envelope.schemaVersion)
            .putInt(key(prefix, "protocolVersion"), envelope.token.protocolVersion)
            .putString(key(prefix, "randomId"), envelope.token.randomId)
            .putLong(key(prefix, "generation"), envelope.token.generation)
            .putString(key(prefix, "kind"), envelope.token.kind.wireValue)
            .putString(key(prefix, "lifecycleState"), envelope.lifecycleState.wireValue)
            .putString(key(prefix, "target"), envelope.target)
            .putLong(key(prefix, "mainDeadlineMs"), envelope.mainDeadlineMs)
            .putLong(key(prefix, "finalDeadlineMs"), envelope.finalDeadlineMs)
            .putLong(
                key(prefix, "elapsedRealtimeDeadlineMs"),
                envelope.elapsedRealtimeDeadlineMs,
            )
            .putString(key(prefix, "schedulingMode"), envelope.schedulingMode.wireValue)
            .putString(
                key(prefix, "callRequestOutcome"),
                envelope.callRequestOutcome.wireValue,
            )
            .putString(key(prefix, "fallbackOutcome"), envelope.fallbackOutcome.wireValue)
            .putLong(key(prefix, "fallbackExpiresAtMs"), envelope.fallbackExpiresAtMs)
        return try {
            editor.commit()
        } catch (_: RuntimeException) {
            false
        }
    }

    override fun clearAll(): Boolean = try {
        prefs.edit().clear().commit()
    } catch (_: RuntimeException) {
        false
    }

    companion object {
        private const val FILE_NAME = "korubeni_emergency_session_v1"

        private fun prefix(slot: SessionSlot): String = "session_${slot.storageKey}_"
        private fun key(prefix: String, field: String): String = "$prefix$field"
    }
}
