package com.poyrazoncel.korubeni.emergency

import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.Locale

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class NativeNotificationTextTest {

    private val context = RuntimeEnvironment.getApplication()

    @Before
    fun setUp() {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        Locale.setDefault(Locale.US)
    }

    @Test
    fun `persisted English locale returns English notification text`() {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString("flutter.locale", "en_US")
            .commit()

        val copy = NativeNotificationText.graceStarted(
            context,
            CheckInScheduler.SESSION_CHECK_IN,
        )

        assertEquals("Check-in expired", copy.title)
        assertEquals("Please confirm that you are safe.", copy.body)
    }

    @Test
    fun `persisted Turkish locale returns Turkish notification text`() {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString("flutter.locale", "tr_TR")
            .commit()

        val copy = NativeNotificationText.graceStarted(
            context,
            CheckInScheduler.SESSION_CHECK_IN,
        )

        assertEquals("Check-in süresi doldu", copy.title)
        assertEquals("Lütfen güvende olduğunuzu onaylayın.", copy.body)
    }

    @Test
    fun `unknown persisted locale falls back to Turkish (TR-locked product)`() {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString("flutter.locale", "zz_ZZ")
            .commit()

        assertEquals(
            "Acil Bildirimler",
            NativeNotificationText.channelName(
                context,
                EmergencyNotificationHelper.CHANNEL_ALERTS,
            ),
        )
    }

    @Test
    fun `no persisted locale defaults to Turkish even on an EN system`() {
        // Audit F8: the product UI is TR-locked (startLocale tr_TR, non-TR
        // persisted locale wiped at startup) — the lock-screen emergency copy
        // must match it. System locale (Locale.US in setUp) must NOT pull the
        // notification into English.
        val copy = NativeNotificationText.graceStarted(
            context,
            CheckInScheduler.SESSION_CHECK_IN,
        )

        assertEquals("Check-in süresi doldu", copy.title)
        assertEquals("Lütfen güvende olduğunuzu onaylayın.", copy.body)
    }
}
