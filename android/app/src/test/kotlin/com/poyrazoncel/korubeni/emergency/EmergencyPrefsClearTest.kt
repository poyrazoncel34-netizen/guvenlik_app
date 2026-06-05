package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * KVKK Md.7 (silme): the "Verilerimi Sil" reset path clears the native
 * korubeni_emergency SharedPreferences via EmergencyPrefs.clear(). This store
 * holds the primary contact number (KEY_CHECK_IN_PRIMARY_NUMBER /
 * KEY_COUNTDOWN_PRIMARY_NUMBER), which must not survive a data deletion.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class EmergencyPrefsClearTest {

    private val context = RuntimeEnvironment.getApplication()

    @Before
    fun setUp() {
        EmergencyPrefs.prefs(context).edit().clear().commit()
    }

    @Test
    fun `clear empties emergency prefs including primary numbers`() {
        EmergencyPrefs.prefs(context).edit()
            .putString(EmergencyPrefs.KEY_CHECK_IN_PRIMARY_NUMBER, "+905001234567")
            .putString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, "+905009998877")
            .putBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, true)
            .commit()

        EmergencyPrefs.clear(context)

        val prefs = EmergencyPrefs.prefs(context)
        assertTrue("emergency prefs must be empty after clear", prefs.all.isEmpty())
        assertNull(prefs.getString(EmergencyPrefs.KEY_CHECK_IN_PRIMARY_NUMBER, null))
        assertNull(prefs.getString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, null))
    }
}
