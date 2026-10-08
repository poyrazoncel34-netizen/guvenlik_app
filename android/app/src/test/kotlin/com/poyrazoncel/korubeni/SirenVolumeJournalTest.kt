package com.poyrazoncel.korubeni

import android.content.Context
import android.media.AudioManager
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/** Audit A-12: a siren interrupted by process death must not strand the alarm stream. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class SirenVolumeJournalTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val max get() = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)

    @Before
    fun setUp() {
        SirenVolumeJournal.clear(context)
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 3, 0)
    }

    private fun sirenRaisesThenProcessDies() {
        SirenVolumeJournal.rememberBeforeRaise(context, original = 3, raisedTo = max)
        audio.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
        // ...process killed here: dispose() never runs, nothing restores.
    }

    @Test
    fun `the next process restores the level a dead siren left raised`() {
        sirenRaisesThenProcessDies()

        SirenVolumeJournal.restoreAfterProcessDeath(context, audio)

        assertEquals(3, audio.getStreamVolume(AudioManager.STREAM_ALARM))
    }

    @Test
    fun `a level the user changed afterwards is left alone`() {
        sirenRaisesThenProcessDies()
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 5, 0)

        SirenVolumeJournal.restoreAfterProcessDeath(context, audio)

        assertEquals(5, audio.getStreamVolume(AudioManager.STREAM_ALARM))
    }

    @Test
    fun `a normal restore clears the record so nothing is restored twice`() {
        sirenRaisesThenProcessDies()
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 3, 0) // Dart restore
        SirenVolumeJournal.clear(context)
        audio.setStreamVolume(AudioManager.STREAM_ALARM, max, 0) // user's own choice

        SirenVolumeJournal.restoreAfterProcessDeath(context, audio)

        assertEquals(max, audio.getStreamVolume(AudioManager.STREAM_ALARM))
    }

    @Test
    fun `a second raise before any restore keeps the first original`() {
        sirenRaisesThenProcessDies()
        // Already at max: a naive second record would save max as "original".
        SirenVolumeJournal.rememberBeforeRaise(context, original = max, raisedTo = max)

        SirenVolumeJournal.restoreAfterProcessDeath(context, audio)

        assertEquals(3, audio.getStreamVolume(AudioManager.STREAM_ALARM))
    }
}
