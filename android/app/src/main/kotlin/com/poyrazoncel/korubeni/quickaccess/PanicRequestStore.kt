package com.poyrazoncel.korubeni.quickaccess

import android.content.Context
import com.poyrazoncel.korubeni.emergency.EmergencyPrefs

/**
 * Durable hand-off for a panic request that arrived from a quick-access surface
 * (home-screen widget, Quick Settings tile) before Flutter was attached.
 *
 * Deliberately NOT EmergencyPrefs.KEY_PENDING_TRIGGER: that key holds at most
 * one payload, and the alarm receivers write it when the event sink is detached.
 * Sharing it would let a widget tap overwrite a pending `checkInExpired` -- an
 * event that means native has ALREADY dispatched -- leaving the Dart projection
 * claiming a session was still running. Two independent producers get two keys.
 *
 * This store carries intent only. It never arms a session, never dials, and
 * never touches a contact: the request is replayed into the one existing arm
 * path (SubscriptionGate -> CountdownScreen -> PanicArmPolicy).
 */
object PanicRequestStore {
    private const val KEY_PENDING = "quick_panic_pending_source"

    /** Quick-access surfaces that may submit a request. */
    const val SOURCE_WIDGET = "widget"
    const val SOURCE_TILE = "tile"

    /**
     * Records a pending request. Uses commit() rather than apply(): the process
     * is about to start an Activity and may be killed before an async write
     * lands, which would drop the user's panic press silently.
     */
    fun submit(context: Context, source: String) {
        EmergencyPrefs.prefs(context).edit().putString(KEY_PENDING, source).commit()
    }

    /**
     * Returns the pending source and clears it, so one press produces at most
     * one countdown even if Flutter asks twice (init plus resume).
     */
    fun consume(context: Context): String? {
        val prefs = EmergencyPrefs.prefs(context)
        val source = prefs.getString(KEY_PENDING, null) ?: return null
        prefs.edit().remove(KEY_PENDING).commit()
        return source
    }
}
