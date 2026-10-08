package com.poyrazoncel.korubeni

import android.content.Context
import android.media.AudioManager

/**
 * Durable record of the alarm-stream level the siren raised (audit A-12).
 *
 * The siren forces STREAM_ALARM to its maximum and restores the original level
 * when it stops. Stream volume is system state: if the process dies while the
 * siren plays, nothing restores it, and the user's next alarm clock rang at full
 * volume (measured on an API 35 emulator: 3 -> 7, still 7 after the process was
 * killed and after the app was opened again). The original level is written
 * here BEFORE the volume goes up and erased after a restore; a fresh process
 * finding an entry knows no siren of its own is playing and restores it.
 */
object SirenVolumeJournal {
    private const val PREFS = "korubeni_siren_volume"
    private const val KEY_ORIGINAL = "original_alarm_volume"
    private const val KEY_RAISED_TO = "raised_alarm_volume"

    /** Records [original] unless an earlier, unrestored raise already did. */
    fun rememberBeforeRaise(context: Context, original: Int, raisedTo: Int) {
        val prefs = prefs(context)
        if (prefs.contains(KEY_ORIGINAL)) return
        prefs.edit()
            .putInt(KEY_ORIGINAL, original)
            .putInt(KEY_RAISED_TO, raisedTo)
            .commit()
    }

    /** Forgets the record once the original level is back. */
    fun clear(context: Context) {
        prefs(context).edit().clear().commit()
    }

    /**
     * Restores a level left raised by a process that died mid-siren. Only
     * while the stream is still at the level the siren set: if the user has
     * changed it since, their choice wins. The record is dropped either way.
     */
    fun restoreAfterProcessDeath(context: Context, audioManager: AudioManager) {
        val prefs = prefs(context)
        if (!prefs.contains(KEY_ORIGINAL)) return
        val original = prefs.getInt(KEY_ORIGINAL, -1)
        val raisedTo = prefs.getInt(KEY_RAISED_TO, -1)
        val current = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        if (original >= 0 && current == raisedTo) {
            val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(
                AudioManager.STREAM_ALARM,
                original.coerceIn(0, max),
                0,
            )
        }
        clear(context)
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
