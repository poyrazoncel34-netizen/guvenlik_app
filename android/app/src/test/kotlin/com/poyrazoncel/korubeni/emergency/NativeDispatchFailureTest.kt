package com.poyrazoncel.korubeni.emergency

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

/**
 * FRESH_AUDIT_2026-06-10 F1: a failed native dispatch (ACTION_CALL and
 * ACTION_DIAL both unopenable) must NOT be silently swallowed.
 *
 * Contract under test:
 *  - The alarm-fired dedup flag is written ONLY after a successful dispatch,
 *    so a frozen-then-resumed Dart isolate retries (failover + fail-safe)
 *    instead of being suppressed by a flag that lied about a call going out.
 *  - On failure a high-priority "call manually" notification containing the
 *    primary number is posted, covering the process-killed case where no
 *    Dart isolate will ever resume.
 *
 * Literal pref keys / notification ids are used on purpose so this suite
 * compiles against the current code and fails at RUNTIME (genuine RED).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class NativeDispatchFailureTest {

    private val context = RuntimeEnvironment.getApplication()
    private val shadowApp get() = Shadows.shadowOf(RuntimeEnvironment.getApplication())

    private val notificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val primaryNumber = "+905001234567"
    private val dispatchId = "dispatch-test-1"

    // Mirrors CheckInScheduler.keyFor(SESSION_CHECK_IN, base) == base.
    private val keyCheckInFired = "check_in_alarm_fired"
    private val keyCheckInPrimary = "check_in_primary_number"

    // Countdown failure alert id (new constant the fix must introduce).
    private val countdownDispatchFailedId = 7304

    @Before
    fun setUp() {
        ShadowLog.setupLogging()
        EmergencyPrefs.prefs(context).edit().clear().commit()
        shadowApp.grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
    }

    /** Context whose startActivity ALWAYS fails — total dispatch failure. */
    private fun failingContext(): Context = object : ContextWrapper(context) {
        override fun startActivity(intent: Intent) {
            throw ActivityNotFoundException("no telephony/dialer app")
        }
    }

    private fun bodyOf(notification: Notification): String =
        notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

    // ── Countdown ────────────────────────────────────────────────────────────

    private fun armCountdown() {
        EmergencyPrefs.prefs(context).edit()
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE, true)
            .putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, false)
            .putString(EmergencyPrefs.KEY_COUNTDOWN_PRIMARY_NUMBER, primaryNumber)
            .putString(EmergencyPrefs.KEY_COUNTDOWN_DISPATCH_ID, dispatchId)
            .commit()
    }

    private fun fireCountdownReceiver(receiverContext: Context) {
        val intent = Intent(context, CountdownAlarmReceiver::class.java)
            .putExtra(CountdownAlarmScheduler.EXTRA_DISPATCH_ID, dispatchId)
        CountdownAlarmReceiver().onReceive(receiverContext, intent)
        Thread.sleep(300)
    }

    @Test
    fun countdownDispatchFailureLeavesFiredFlagFalse() {
        armCountdown()
        fireCountdownReceiver(failingContext())

        val prefs = EmergencyPrefs.prefs(context)
        assertFalse(
            "Failed dispatch must NOT set the fired dedup flag — a resumed Dart " +
                "isolate must be able to retry with failover + fail-safe",
            prefs.getBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, false),
        )
        assertFalse(
            "Session must still be deactivated so stale alarms are rejected",
            prefs.getBoolean(EmergencyPrefs.KEY_COUNTDOWN_ACTIVE, false),
        )
    }

    @Test
    fun countdownDispatchFailurePostsManualCallNotification() {
        armCountdown()
        fireCountdownReceiver(failingContext())

        val posted = Shadows.shadowOf(notificationManager)
            .getNotification(countdownDispatchFailedId)
        assertNotNull(
            "Failed countdown dispatch must post a manual-call notification",
            posted,
        )
        assertTrue(
            "Manual-call notification must contain the primary number",
            bodyOf(posted!!).contains(primaryNumber),
        )
    }

    @Test
    fun countdownDispatchSuccessStillSetsFiredFlag() {
        // Robolectric startActivity succeeds; no CALL_PHONE -> ACTION_DIAL path.
        armCountdown()
        fireCountdownReceiver(context)

        assertTrue(
            "Successful dispatch must keep setting the fired dedup flag",
            EmergencyPrefs.prefs(context)
                .getBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, false),
        )
        val started = shadowApp.nextStartedActivity
        assertNotNull("Successful path must still dispatch the call intent", started)
        assertEquals(Intent.ACTION_DIAL, started!!.action)
    }

    @Test
    fun countdownFailureNotificationOpensDialerPrefilled() {
        armCountdown()
        fireCountdownReceiver(failingContext())

        val posted = Shadows.shadowOf(notificationManager)
            .getNotification(countdownDispatchFailedId)
        assertNotNull("Manual-call notification must be posted", posted)
        val tapIntent = Shadows.shadowOf(posted!!.contentIntent).savedIntent
        assertEquals(
            "Tap must open the dialer directly — the in-app PIN gate must " +
                "never stand between a failed call and the manual fail-safe",
            Intent.ACTION_DIAL,
            tapIntent.action,
        )
        // Uri.fromParts stores the ssp raw; toString() encodes '+' as %2B but
        // the dialer reads getSchemeSpecificPart() (decoded) — assert the
        // semantic value, not the encoded string form.
        assertEquals("tel", tapIntent.data?.scheme)
        assertEquals(
            "Dialer must be pre-filled with the persisted primary number",
            primaryNumber,
            tapIntent.data?.schemeSpecificPart,
        )
    }

    // ── Check-in / safe-walk ─────────────────────────────────────────────────

    private fun armCheckInGraceExpiry() {
        EmergencyPrefs.prefs(context).edit()
            .putBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, true)
            .putString(EmergencyPrefs.KEY_CHECK_IN_PHASE, CheckInScheduler.PHASE_GRACE)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_GRACE_MS, 0L)
            .putString(keyCheckInPrimary, primaryNumber)
            .commit()
    }

    private fun fireCheckInReceiver(receiverContext: Context) {
        val intent = Intent(context, CheckInAlarmReceiver::class.java)
            .putExtra("sessionId", CheckInScheduler.SESSION_CHECK_IN)
        CheckInAlarmReceiver().onReceive(receiverContext, intent)
        Thread.sleep(300)
    }

    @Test
    fun checkInDispatchFailureLeavesFiredFlagFalse() {
        armCheckInGraceExpiry()
        fireCheckInReceiver(failingContext())

        val prefs = EmergencyPrefs.prefs(context)
        assertFalse(
            "Failed check-in escalation must NOT set the fired dedup flag",
            prefs.getBoolean(keyCheckInFired, false),
        )
        assertFalse(
            "Session must still be deactivated so a duplicate alarm is rejected",
            prefs.getBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, false),
        )
    }

    @Test
    fun checkInDispatchFailureNotifiesManualCallWithNumber() {
        armCheckInGraceExpiry()
        fireCheckInReceiver(failingContext())

        val posted = Shadows.shadowOf(notificationManager)
            .getNotification(EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID)
        assertNotNull("Failed escalation must still notify the user", posted)
        assertTrue(
            "Failure notification must carry the manual-call number, not the " +
                "misleading 'timer ended' success copy",
            bodyOf(posted!!).contains(primaryNumber),
        )
    }

    @Test
    fun checkInDispatchFailureStillPersistsExpiredEventForDartReconcile() {
        armCheckInGraceExpiry()
        fireCheckInReceiver(failingContext())

        val pending = EmergencyPrefs.prefs(context)
            .getString(EmergencyPrefs.KEY_PENDING_TRIGGER, null)
        assertNotNull("checkInExpired must still reach the Dart side", pending)
        assertTrue(pending!!.contains("checkInExpired"))
    }

    // keyFor(SESSION_SAFE_WALK, base) == "${'$'}{base}_safe_walk" (literal on purpose).
    private fun armSafeWalkGraceExpiry() {
        EmergencyPrefs.prefs(context).edit()
            .putBoolean("check_in_active_safe_walk", true)
            .putString("check_in_phase_safe_walk", CheckInScheduler.PHASE_GRACE)
            .putLong("check_in_grace_ms_safe_walk", 0L)
            .putString("check_in_primary_number_safe_walk", primaryNumber)
            .commit()
    }

    @Test
    fun overlappingSessionFailuresDoNotClobberEachOthersNotification() {
        // Both sessions can be active at once; their failure alerts must land
        // on distinct ids (check_in 7303, safe_walk 7305) so the second
        // notify() never erases the first session's manual-call fail-safe.
        armCheckInGraceExpiry()
        fireCheckInReceiver(failingContext())

        armSafeWalkGraceExpiry()
        val intent = Intent(context, CheckInAlarmReceiver::class.java)
            .putExtra("sessionId", CheckInScheduler.SESSION_SAFE_WALK)
        CheckInAlarmReceiver().onReceive(failingContext(), intent)
        Thread.sleep(300)

        val shadowNm = Shadows.shadowOf(notificationManager)
        assertNotNull(
            "check_in failure must stay on its own id (7303) — not clobbered",
            shadowNm.getNotification(EmergencyNotificationHelper.CHECK_IN_NOTIFICATION_ID),
        )
        assertNotNull(
            "safe_walk failure must use its own id (7305)",
            shadowNm.getNotification(7305),
        )
    }

    @Test
    fun bootRestoreDispatchFailureLeavesFiredFlagFalse() {
        val now = System.currentTimeMillis()
        EmergencyPrefs.prefs(context).edit()
            .putBoolean(EmergencyPrefs.KEY_CHECK_IN_ACTIVE, true)
            .putString(EmergencyPrefs.KEY_CHECK_IN_PHASE, CheckInScheduler.PHASE_GRACE)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_DEADLINE, now - 1_000L)
            .putLong(EmergencyPrefs.KEY_CHECK_IN_GRACE_MS, 0L)
            .putString(keyCheckInPrimary, primaryNumber)
            .commit()

        CheckInScheduler.restoreAfterBoot(failingContext())
        Thread.sleep(300)

        assertFalse(
            "Boot-restore escalation failure must NOT set the fired dedup flag",
            EmergencyPrefs.prefs(context).getBoolean(keyCheckInFired, false),
        )
    }
}
