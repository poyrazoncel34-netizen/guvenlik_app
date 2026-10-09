package com.poyrazoncel.korubeni.emergency

import android.provider.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class MonotonicClockSnapshotTest {
    private val context = RuntimeEnvironment.getApplication()

    @Test
    fun `reports elapsed realtime and the boot it belongs to`() {
        Settings.Global.putInt(context.contentResolver, Settings.Global.BOOT_COUNT, 17)

        val snapshot = MonotonicClockSnapshot.of(context) { 123_456L }

        assertEquals(123_456L, snapshot["elapsedRealtimeMs"])
        assertEquals(17, snapshot["bootCount"])
    }

    @Test
    fun `an unreadable boot count is reported as unknown, not guessed`() {
        Settings.Global.putString(context.contentResolver, Settings.Global.BOOT_COUNT, "x")

        val snapshot = MonotonicClockSnapshot.of(context) { 1L }

        assertEquals(UNKNOWN_BOOT_COUNT, snapshot["bootCount"])
    }

    // Review of Y-05: Dart decides "same boot" for the PIN lockout from this
    // snapshot; without the kernel id a device that cannot read BOOT_COUNT
    // fell back to the settable wall clock.
    @Test
    fun `reports the kernel boot id, or null when it cannot be read`() {
        val id = "0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0"
        assertEquals(id, MonotonicClockSnapshot.of(context, bootId = { id }) { 1L }["bootId"])
        assertNull(MonotonicClockSnapshot.of(context, bootId = { null }) { 1L }["bootId"])
    }
}
