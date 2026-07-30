package com.poyrazoncel.korubeni.quickaccess

import android.content.Intent
import com.poyrazoncel.korubeni.MainActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class PanicLaunchTest {

    private val context = RuntimeEnvironment.getApplication()

    @Test
    fun `intent targets the launcher activity, not a dial or a service`() {
        val intent = PanicLaunch.intent(context, PanicRequestStore.SOURCE_TILE)

        assertEquals(MainActivity::class.java.name, intent.component?.className)
        // A quick-access surface opens the app; it never places a call itself.
        assertEquals(Intent.ACTION_MAIN, intent.action)
    }

    @Test
    fun `intent reuses the existing task instead of stacking a new instance`() {
        val intent = PanicLaunch.intent(context, PanicRequestStore.SOURCE_WIDGET)

        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_CLEAR_TOP != 0)
    }

    @Test
    fun `intent carries a source label and nothing else`() {
        val intent = PanicLaunch.intent(context, PanicRequestStore.SOURCE_WIDGET)

        assertEquals(
            PanicRequestStore.SOURCE_WIDGET,
            intent.getStringExtra(PanicLaunch.EXTRA_PANIC_SOURCE),
        )
        assertEquals(1, intent.extras?.size())
    }
}
