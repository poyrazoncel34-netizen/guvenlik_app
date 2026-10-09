package com.poyrazoncel.korubeni.emergency

/**
 * A session read for Dart, with whether exact alarms can be scheduled NOW
 * (Y-14). Revoking the access kills the process and deletes the session's
 * exact alarms; the stored record still says `exactAndInexact`, and only the
 * inexact backups -- 10 to 12 minutes of window on an API 36 emulator -- are
 * left. Read live rather than persisted, so a re-grant is seen at once.
 *
 * A permission query that throws (a system_server restart) must neither fail
 * the read nor claim protection: it reads as not permitted, which Dart shows
 * as the degraded notice.
 */
object SessionReadWire {
    fun of(read: ReadSessionResult, exactAlarmPermitted: () -> Boolean): Map<String, Any?> {
        val permitted = try {
            exactAlarmPermitted()
        } catch (_: RuntimeException) {
            false
        }
        return read.toMap() + ("exactAlarmPermitted" to permitted)
    }
}
