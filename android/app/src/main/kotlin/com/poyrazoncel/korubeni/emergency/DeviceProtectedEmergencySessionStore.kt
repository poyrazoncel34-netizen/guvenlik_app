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
                    // Absent on records written before the field existed.
                    elapsedBootCount = prefs.getInt(
                        key(prefix, "elapsedBootCount"),
                        UNKNOWN_BOOT_COUNT,
                    ),
                    elapsedStampMs = prefs.getLong(key(prefix, "elapsedStampMs"), -1L),
                    schedulingMode = schedulingMode,
                    callRequestOutcome = callOutcome,
                    fallbackOutcome = fallbackOutcome,
                    fallbackExpiresAtMs = fallbackExpiry,
                    completedAtMs = prefs.getLong(key(prefix, "completedAtMs"), 0L),
                    mainDurationMs = prefs.getLong(key(prefix, "mainDurationMs"), 0L),
                    graceWarningOutcome = prefs.getString(key(prefix, "graceWarningOutcome"), "notAttempted") ?: "unknown",
                    preWarningOutcome = prefs.getString(key(prefix, "preWarningOutcome"), "notAttempted") ?: "unknown",
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
        // Journal on the TRANSITION into a terminal state, not on every write
        // of an already-terminal envelope. expireFallback() (up to 24h later)
        // and consumeFallbackTarget() legitimately re-write the SAME terminal
        // state to drop the retained target; appending again there resurrects
        // an outcome the user already acknowledged and hands it back from
        // pendingOutcomes() as if it were new. A genuine change of terminal
        // state IS new information and still journals.
        val storedState = LifecycleState.fromWire(
            prefs.getString(key(prefix, "lifecycleState"), null),
        )
        val sameTerminalStateRewrite = storedState != null &&
            storedState.isTerminal &&
            storedState == envelope.lifecycleState &&
            prefs.getString(key(prefix, "randomId"), null) == envelope.token.randomId &&
            prefs.getLong(key(prefix, "generation"), -1L) == envelope.token.generation
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
            .putLong(key(prefix, "completedAtMs"), envelope.completedAtMs)
            .putLong(key(prefix, "mainDeadlineMs"), envelope.mainDeadlineMs)
            .putLong(key(prefix, "finalDeadlineMs"), envelope.finalDeadlineMs)
            .putLong(
                key(prefix, "elapsedRealtimeDeadlineMs"),
                envelope.elapsedRealtimeDeadlineMs,
            )
            .putInt(key(prefix, "elapsedBootCount"), envelope.elapsedBootCount)
            .putLong(key(prefix, "elapsedStampMs"), envelope.elapsedStampMs)
            .putString(key(prefix, "schedulingMode"), envelope.schedulingMode.wireValue)
            .putString(
                key(prefix, "callRequestOutcome"),
                envelope.callRequestOutcome.wireValue,
            )
            .putString(key(prefix, "fallbackOutcome"), envelope.fallbackOutcome.wireValue)
            .putLong(key(prefix, "fallbackExpiresAtMs"), envelope.fallbackExpiresAtMs)
            .putLong(key(prefix, "mainDurationMs"), envelope.mainDurationMs)
            .putString(key(prefix, "graceWarningOutcome"), envelope.graceWarningOutcome)
            .putString(key(prefix, "preWarningOutcome"), envelope.preWarningOutcome)
        if (!sameTerminalStateRewrite) EmergencyTerminalJournal.append(editor, envelope)
        return try {
            editor.commit()
        } catch (_: RuntimeException) {
            false
        }
    }

    fun pendingOutcomes(): List<Map<String, Any?>> = EmergencyTerminalJournal.read(prefs)

    fun acknowledgeOutcome(token: SessionToken): Boolean =
        prefs.edit().remove(EmergencyTerminalJournal.key(token)).commit()

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
