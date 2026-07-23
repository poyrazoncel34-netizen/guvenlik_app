package com.poyrazoncel.korubeni.emergency

const val EMERGENCY_PROTOCOL_VERSION = 1
const val EMERGENCY_SESSION_SCHEMA_VERSION = 1
const val FALLBACK_TARGET_RETENTION_MS = 24L * 60L * 60L * 1_000L

enum class SessionKind(val wireValue: String) {
    PANIC("panic"),
    CHECK_IN("checkIn"),
    SAFE_WALK("safeWalk");

    val slot: SessionSlot
        get() = if (this == PANIC) SessionSlot.PANIC else SessionSlot.LONG_RUNNING

    companion object {
        fun fromWire(value: String?): SessionKind? = entries.firstOrNull { it.wireValue == value }
    }
}

enum class SessionSlot(val storageKey: String) {
    PANIC("panic"),
    LONG_RUNNING("long"),
}

enum class LifecycleState(val wireValue: String) {
    PREPARING("preparing"),
    ARMED("armed"),
    CLAIMED("claimed"),
    CANCELLED("cancelled"),
    REQUEST_SUBMITTED_UNCONFIRMED("requestSubmittedUnconfirmed"),
    MANUAL_ACTION_REQUIRED("manualActionRequired"),
    REQUEST_FAILED("requestFailed"),
    CORRUPTED("corrupted");

    val isTerminal: Boolean
        get() = this in setOf(
            CANCELLED,
            REQUEST_SUBMITTED_UNCONFIRMED,
            MANUAL_ACTION_REQUIRED,
            REQUEST_FAILED,
            CORRUPTED,
        )

    companion object {
        fun fromWire(value: String?): LifecycleState? = entries.firstOrNull { it.wireValue == value }
    }
}

enum class CallRequestOutcome(val wireValue: String) {
    NOT_ATTEMPTED("notAttempted"),
    SUBMITTED_UNCONFIRMED("submittedUnconfirmed"),
    FAILED("failed"),
}

enum class FallbackOutcome(val wireValue: String) {
    NOT_ATTEMPTED("notAttempted"),
    POSTED("posted"),
    FAILED("failed"),
    EXPIRED("expired"),
}

enum class ConnectionState(val wireValue: String) {
    UNKNOWN("unknown"),
}

enum class EntitlementDecision(val wireValue: String) {
    AUTHORIZED("authorized"),
    DENIED("denied"),
    UNKNOWN("unknown");

    companion object {
        fun fromWire(value: String?): EntitlementDecision =
            entries.firstOrNull { it.wireValue == value } ?: UNKNOWN
    }
}

enum class SchedulingMode(val wireValue: String) {
    EXACT_AND_INEXACT("exactAndInexact"),
    EXACT_ONLY("exactOnly"),
    INEXACT_ONLY("inexactOnly"),
    NONE("none"),
}

data class SessionToken(
    val protocolVersion: Int,
    val randomId: String,
    val generation: Long,
    val kind: SessionKind,
) {
    val slot: SessionSlot get() = kind.slot

    fun toMap(): Map<String, Any> = mapOf(
        "protocolVersion" to protocolVersion,
        "randomId" to randomId,
        "generation" to generation,
        "kind" to kind.wireValue,
    )

    companion object {
        fun fromMap(value: Map<*, *>?): SessionToken? {
            if (value == null) return null
            val protocolVersion = (value["protocolVersion"] as? Number)?.toInt() ?: return null
            val randomId = value["randomId"] as? String ?: return null
            val generation = (value["generation"] as? Number)?.toLong() ?: return null
            val kind = SessionKind.fromWire(value["kind"] as? String) ?: return null
            if (randomId.isBlank() || generation <= 0L) return null
            return SessionToken(protocolVersion, randomId, generation, kind)
        }
    }
}

data class ArmRequest(
    val protocolVersion: Int,
    val randomId: String,
    val kind: SessionKind,
    val mainDeadlineMs: Long,
    val finalDeadlineMs: Long,
    val target: String,
    val entitlementDecision: EntitlementDecision,
    val pinConfigured: Boolean,
    val requestedGeneration: Long = 1L,
)

data class CapabilitySnapshot(
    val supportedOs: Boolean,
    val telephonyCalling: Boolean,
    val telecomAvailable: Boolean,
    val dialHandlerAvailable: Boolean,
    val exactAlarmGranted: Boolean,
    val notificationsEnabled: Boolean,
    val alertChannelHigh: Boolean,
    val callPermissionGranted: Boolean,
    val pinConfigured: Boolean,
    val callableTarget: Boolean,
    val entitlementDecision: EntitlementDecision,
) {
    fun rejectionReason(): String? = when {
        !supportedOs -> "unsupportedOs"
        entitlementDecision == EntitlementDecision.DENIED -> "entitlementDenied"
        entitlementDecision == EntitlementDecision.UNKNOWN -> "entitlementUnknown"
        !pinConfigured -> "pinNotConfigured"
        !callableTarget -> "targetNotCallable"
        !telephonyCalling -> "telephonyUnavailable"
        !telecomAvailable -> "telecomUnavailable"
        !dialHandlerAvailable -> "dialHandlerUnavailable"
        !callPermissionGranted -> "callPermissionDenied"
        !exactAlarmGranted -> "exactAlarmDenied"
        !notificationsEnabled -> "notificationsDisabled"
        !alertChannelHigh -> "alertChannelNotHigh"
        else -> null
    }

    fun toMap(): Map<String, Any> = mapOf(
        "supportedOs" to supportedOs,
        "telephonyCalling" to telephonyCalling,
        "telecomAvailable" to telecomAvailable,
        "dialHandlerAvailable" to dialHandlerAvailable,
        "exactAlarmGranted" to exactAlarmGranted,
        "notificationsEnabled" to notificationsEnabled,
        "alertChannelHigh" to alertChannelHigh,
        "callPermissionGranted" to callPermissionGranted,
        "pinConfigured" to pinConfigured,
        "callableTarget" to callableTarget,
        "entitlementDecision" to entitlementDecision.wireValue,
    )
}

data class EmergencySessionEnvelope(
    val schemaVersion: Int = EMERGENCY_SESSION_SCHEMA_VERSION,
    val token: SessionToken,
    val lifecycleState: LifecycleState,
    val target: String,
    val mainDeadlineMs: Long,
    val finalDeadlineMs: Long,
    val elapsedRealtimeDeadlineMs: Long,
    val schedulingMode: SchedulingMode,
    val callRequestOutcome: CallRequestOutcome = CallRequestOutcome.NOT_ATTEMPTED,
    val fallbackOutcome: FallbackOutcome = FallbackOutcome.NOT_ATTEMPTED,
    val fallbackExpiresAtMs: Long = 0L,
)

sealed interface SessionRead {
    data object Absent : SessionRead
    data class Present(val envelope: EmergencySessionEnvelope) : SessionRead
    data class Corrupted(val reasonCode: String) : SessionRead
}

sealed interface ArmResult {
    fun toMap(): Map<String, Any?>

    data class Armed(
        val token: SessionToken,
        val mainDeadlineMs: Long,
        val finalDeadlineMs: Long,
    ) : ArmResult {
        override fun toMap(): Map<String, Any?> = mapOf(
            "type" to "armed",
            "token" to token.toMap(),
            "mainDeadlineMs" to mainDeadlineMs,
            "finalDeadlineMs" to finalDeadlineMs,
        )
    }

    data class Rejected(val reasonCode: String) : ArmResult {
        override fun toMap(): Map<String, Any?> = mapOf(
            "type" to "rejected",
            "reasonCode" to reasonCode,
        )
    }

    data class Unknown(val reasonCode: String) : ArmResult {
        override fun toMap(): Map<String, Any?> = mapOf(
            "type" to "unknown",
            "reasonCode" to reasonCode,
        )
    }
}

sealed interface CancelResult {
    val token: SessionToken

    data class Cancelled(override val token: SessionToken) : CancelResult
    data class AlreadyCancelled(override val token: SessionToken) : CancelResult
    data class TooLate(
        override val token: SessionToken,
        val terminalState: LifecycleState,
    ) : CancelResult
    data class Stale(override val token: SessionToken) : CancelResult
    data class Unknown(
        override val token: SessionToken,
        val reasonCode: String,
    ) : CancelResult

    fun toMap(): Map<String, Any?> {
        val type = when (this) {
            is Cancelled -> "cancelled"
            is AlreadyCancelled -> "alreadyCancelled"
            is TooLate -> "tooLate"
            is Stale -> "stale"
            is Unknown -> "unknown"
        }
        return buildMap {
            put("type", type)
            put("token", token.toMap())
            if (this@CancelResult is TooLate) {
                put("terminalState", terminalState.wireValue)
            }
            if (this@CancelResult is Unknown) {
                put("reasonCode", reasonCode)
            }
        }
    }
}

data class DispatchResult(
    val token: SessionToken,
    val callRequestOutcome: CallRequestOutcome,
    val fallbackOutcome: FallbackOutcome,
    val connectionState: ConnectionState = ConnectionState.UNKNOWN,
    val terminalState: LifecycleState? = null,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "token" to token.toMap(),
        "callRequestOutcome" to callRequestOutcome.wireValue,
        "fallbackOutcome" to fallbackOutcome.wireValue,
        "connectionState" to connectionState.wireValue,
        "terminalState" to terminalState?.wireValue,
    )

    companion object {
        fun notAttempted(token: SessionToken, state: LifecycleState? = null) = DispatchResult(
            token = token,
            callRequestOutcome = CallRequestOutcome.NOT_ATTEMPTED,
            fallbackOutcome = FallbackOutcome.NOT_ATTEMPTED,
            terminalState = state,
        )
    }
}

sealed interface ReadSessionResult {
    fun toMap(): Map<String, Any?>

    data object Absent : ReadSessionResult {
        override fun toMap(): Map<String, Any?> = mapOf("type" to "absent")
    }

    data class Present(val envelope: EmergencySessionEnvelope) : ReadSessionResult {
        override fun toMap(): Map<String, Any?> = mapOf(
            "type" to "present",
            "session" to mapOf(
                "token" to envelope.token.toMap(),
                "lifecycleState" to envelope.lifecycleState.wireValue,
                "mainDeadlineMs" to envelope.mainDeadlineMs,
                "finalDeadlineMs" to envelope.finalDeadlineMs,
                "target" to envelope.target,
                "callRequestOutcome" to envelope.callRequestOutcome.wireValue,
                "fallbackOutcome" to envelope.fallbackOutcome.wireValue,
            ),
        )
    }

    data class Corrupted(val reasonCode: String) : ReadSessionResult {
        override fun toMap(): Map<String, Any?> = mapOf(
            "type" to "corrupted",
            "reasonCode" to reasonCode,
        )
    }
}

enum class WipeStatus(val wireValue: String) {
    COMPLETED("completed"),
    PENDING("pending"),
    TOO_LATE("tooLate"),
    UNKNOWN("unknown"),
}

data class WipeResult(
    val status: WipeStatus,
    val reasonCode: String? = null,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "type" to status.wireValue,
        "reasonCode" to reasonCode,
    )
}

data class AlarmScheduleResult(
    val exactAccepted: Boolean,
    val inexactAccepted: Boolean,
)

interface EmergencySessionStore {
    fun read(slot: SessionSlot): SessionRead
    fun write(envelope: EmergencySessionEnvelope): Boolean
    fun clearAll(): Boolean
}

interface EmergencySessionAlarmScheduler {
    fun schedule(envelope: EmergencySessionEnvelope): AlarmScheduleResult
    fun cancel(token: SessionToken)
}

interface EmergencyFallbackPoster {
    fun post(envelope: EmergencySessionEnvelope): FallbackOutcome

    /** Removes notification and retained PendingIntents for a terminal wipe. */
    fun clear(envelope: EmergencySessionEnvelope) = Unit
}

fun interface EmergencyCallRequester {
    fun requestCall(target: String): CallRequestOutcome
}

fun interface EmergencyCapabilityProvider {
    fun snapshot(request: ArmRequest): CapabilitySnapshot
}
