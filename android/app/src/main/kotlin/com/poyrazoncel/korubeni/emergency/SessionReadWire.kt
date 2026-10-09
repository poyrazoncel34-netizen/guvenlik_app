package com.poyrazoncel.korubeni.emergency

/**
 * A session read for Dart, with whether exact alarms can be scheduled NOW
 * (Y-14). Revoking the access kills the process and deletes the session's
 * exact alarms; the stored record still says `exactAndInexact`, and only the
 * inexact backups -- 10 to 12 minutes of window on an API 36 emulator -- are
 * left. Read live rather than persisted, so a re-grant is seen at once.
 */
object SessionReadWire {
    fun of(read: ReadSessionResult, exactAlarmPermitted: Boolean): Map<String, Any?> =
        read.toMap() + ("exactAlarmPermitted" to exactAlarmPermitted)
}
