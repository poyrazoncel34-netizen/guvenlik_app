package com.poyrazoncel.korubeni.emergency

import android.content.SharedPreferences
import org.json.JSONObject

/** Redacted outcomes survive slot reuse until credential-protected history commits. */
internal object EmergencyTerminalJournal {
    private const val PREFIX = "outcome_"
    fun key(token: SessionToken) = "$PREFIX${token.protocolVersion}_${token.kind.wireValue}_${token.randomId}_${token.generation}"

    fun append(editor: SharedPreferences.Editor, envelope: EmergencySessionEnvelope) {
        if (!envelope.lifecycleState.isTerminal || envelope.lifecycleState in setOf(
                LifecycleState.CANCELLED, LifecycleState.CORRUPTED)) return
        // Commit journal and terminal envelope atomically, without retaining the target.
        val redacted = envelope.copy(target = "", fallbackExpiresAtMs = 0L)
        editor.putString(key(envelope.token), JSONObject(ReadSessionResult.Present(redacted).toMap()).toString())
    }

    fun read(prefs: SharedPreferences): List<Map<String, Any?>> = prefs.all
        .filterKeys { it.startsWith(PREFIX) }
        .values.mapNotNull { value ->
            try { decode(JSONObject(value as String)) }
            catch (_: Exception) { null } // Preserve valid outcomes; corrupt entry remains for retry/wipe.
        }

    private fun decode(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key ->
        when (val value = json.get(key)) {
            JSONObject.NULL -> null
            is JSONObject -> decode(value)
            else -> value
        }
    }
}
