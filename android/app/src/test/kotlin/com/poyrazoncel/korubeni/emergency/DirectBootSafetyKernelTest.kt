package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.UserManager
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class DirectBootSafetyKernelTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val userManager get() = context.getSystemService(Context.USER_SERVICE) as UserManager

    @Before
    fun setUp() {
        Shadows.shadowOf(userManager).setUserUnlocked(true)
        DeviceProtectedEmergencySessionStore(context).clearAll()
        EmergencyPrefs.prefs(context).edit().clear().commit()
        Shadows.shadowOf(RuntimeEnvironment.getApplication())
            .grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
    }

    @After
    fun tearDown() {
        Shadows.shadowOf(userManager).setUserUnlocked(true)
    }

    @Test
    fun `locked boot expiry uses device store and never writes credential event bus`() {
        val now = System.currentTimeMillis()
        val token = SessionToken(
            EMERGENCY_PROTOCOL_VERSION,
            "locked-boot-session",
            1L,
            SessionKind.CHECK_IN,
        )
        val store = DeviceProtectedEmergencySessionStore(context)
        assertTrue(
            store.write(
                EmergencySessionEnvelope(
                    token = token,
                    lifecycleState = LifecycleState.ARMED,
                    target = "+905001234567",
                    mainDeadlineMs = now - 120_000L,
                    finalDeadlineMs = now - 60_000L,
                    elapsedRealtimeDeadlineMs = 1L,
                    schedulingMode = SchedulingMode.EXACT_AND_INEXACT,
                ),
            ),
        )
        Shadows.shadowOf(userManager).setUserUnlocked(false)

        BootCompletedReceiver().onReceive(
            context,
            Intent(Intent.ACTION_LOCKED_BOOT_COMPLETED),
        )

        val terminal = store.read(SessionSlot.LONG_RUNNING) as SessionRead.Present
        assertEquals(LifecycleState.MANUAL_ACTION_REQUIRED, terminal.envelope.lifecycleState)
        assertEquals(FallbackOutcome.POSTED, terminal.envelope.fallbackOutcome)
        assertNull(
            "Locked-boot path must not touch credential-protected EventBus prefs",
            EmergencyPrefs.prefs(context).getString(EmergencyPrefs.KEY_PENDING_TRIGGER, null),
        )
    }

    @Test
    fun `fallback PendingIntent targets native expiry gate not external dialer directly`() {
        val token = SessionToken(
            EMERGENCY_PROTOCOL_VERSION,
            "expiry-gate-session",
            1L,
            SessionKind.PANIC,
        )

        val pendingIntent = EmergencyFallbackDialActivity.pendingIntent(
            context,
            token,
            EmergencyNotificationHelper.COUNTDOWN_DISPATCH_FAILED_NOTIFICATION_ID,
            System.currentTimeMillis() + FALLBACK_TARGET_RETENTION_MS,
        )
        val saved = Shadows.shadowOf(pendingIntent).savedIntent

        assertEquals(EmergencyFallbackDialActivity::class.java.name, saved.component?.className)
        assertTrue(saved.action != Intent.ACTION_DIAL)
        assertFalse(saved.hasExtra("target"))
    }

    @Test
    fun `stale fallback cleanup cannot cancel a newer generation notification`() {
        val now = System.currentTimeMillis()
        val oldToken = SessionToken(
            EMERGENCY_PROTOCOL_VERSION,
            "fallback-generation",
            1L,
            SessionKind.CHECK_IN,
        )
        val currentToken = oldToken.copy(generation = 2L)
        val notificationId = EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, Notification())
        assertTrue(
            DeviceProtectedEmergencySessionStore(context).write(
                EmergencySessionEnvelope(
                    token = currentToken,
                    lifecycleState = LifecycleState.MANUAL_ACTION_REQUIRED,
                    target = "+905001234567",
                    mainDeadlineMs = now - 120_000L,
                    finalDeadlineMs = now - 60_000L,
                    elapsedRealtimeDeadlineMs = 1L,
                    schedulingMode = SchedulingMode.EXACT_AND_INEXACT,
                    fallbackOutcome = FallbackOutcome.POSTED,
                    fallbackExpiresAtMs = now + 60_000L,
                ),
            ),
        )
        val staleCleanup = EmergencyFallbackCleanupReceiver.pendingIntent(
            context,
            oldToken,
            notificationId,
            now + 60_000L,
        )

        EmergencyFallbackCleanupReceiver().onReceive(
            context,
            Shadows.shadowOf(staleCleanup).savedIntent,
        )

        assertTrue(Shadows.shadowOf(notificationManager).getNotification(notificationId) != null)
    }
}
