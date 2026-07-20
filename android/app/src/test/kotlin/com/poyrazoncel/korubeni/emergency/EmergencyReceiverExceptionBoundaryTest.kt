package com.poyrazoncel.korubeni.emergency

import android.app.AlarmManager
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class EmergencyReceiverExceptionBoundaryTest {
    private val context = ThrowingDeviceStorageContext(RuntimeEnvironment.getApplication())

    @Test
    fun `locked boot storage failure does not crash receiver process`() {
        BootCompletedReceiver().onReceive(
            context,
            Intent(Intent.ACTION_LOCKED_BOOT_COMPLETED),
        )
    }

    @Test
    fun `clock change storage failure does not crash receiver process`() {
        ClockChangeReceiver().onReceive(
            context,
            Intent(Intent.ACTION_TIME_CHANGED),
        )
    }

    @Test
    fun `exact alarm permission storage failure does not crash receiver process`() {
        ExactAlarmPermissionReceiver().onReceive(
            context,
            Intent(AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED),
        )
    }

    @Test
    fun `panic dispatch storage failure does not crash receiver process`() {
        CountdownAlarmReceiver().onReceive(context, dispatchIntent(SessionKind.PANIC))
    }

    @Test
    fun `long session dispatch storage failure does not crash receiver process`() {
        CheckInAlarmReceiver().onReceive(context, dispatchIntent(SessionKind.CHECK_IN))
    }

    @Test
    fun `fallback cleanup storage failure does not crash receiver process`() {
        val token = SessionToken(
            EMERGENCY_PROTOCOL_VERSION,
            "fallback-cleanup-fault",
            1L,
            SessionKind.PANIC,
        )
        val pendingIntent = EmergencyFallbackCleanupReceiver.pendingIntent(
            RuntimeEnvironment.getApplication(),
            token,
            42591,
            System.currentTimeMillis() + 60_000L,
        )

        EmergencyFallbackCleanupReceiver().onReceive(
            context,
            Shadows.shadowOf(pendingIntent).savedIntent,
        )
    }

    private fun dispatchIntent(kind: SessionKind): Intent = Intent().apply {
        action = AndroidEmergencySessionAlarmScheduler.ACTION_DISPATCH
        putExtra(
            AndroidEmergencySessionAlarmScheduler.EXTRA_PROTOCOL_VERSION,
            EMERGENCY_PROTOCOL_VERSION,
        )
        putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_RANDOM_ID, "receiver-fault-test")
        putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_GENERATION, 1L)
        putExtra(AndroidEmergencySessionAlarmScheduler.EXTRA_KIND, kind.wireValue)
    }

    private class ThrowingDeviceStorageContext(base: Context) : ContextWrapper(base) {
        override fun getApplicationContext(): Context = this

        override fun createDeviceProtectedStorageContext(): Context {
            throw IllegalStateException("injected device-protected storage failure")
        }
    }
}
