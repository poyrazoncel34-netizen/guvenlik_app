package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.os.SystemClock
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs

/** Host-driven, two-stage probes for package/time reconciliation on an emulator. */
@RunWith(AndroidJUnit4::class)
class Stage4ReconciliationInstrumentationTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val args = InstrumentationRegistry.getArguments()

    @Test
    fun seedFutureSession() {
        assumeTrue(mode() == "seed")
        val store = DeviceProtectedEmergencySessionStore(context)
        (store.read(SessionSlot.PANIC) as? SessionRead.Present)?.envelope?.let {
            EmergencySessionRuntime.coordinator(context).cancel(it.token)
        }
        store.clearAll()

        val deadline = System.currentTimeMillis() + 1_200_000L
        val result = EmergencySessionRuntime.coordinator(context).arm(
            ArmRequest(
                protocolVersion = EMERGENCY_PROTOCOL_VERSION,
                randomId = "$PREFIX${System.currentTimeMillis()}",
                kind = SessionKind.PANIC,
                mainDeadlineMs = deadline,
                finalDeadlineMs = deadline,
                target = "0000000",
                entitlementDecision = EntitlementDecision.AUTHORIZED,
                pinConfigured = true,
            ),
        )
        assertTrue("arm failed: ${result.toMap()}", result is ArmResult.Armed)
        val envelope = (store.read(SessionSlot.PANIC) as SessionRead.Present).envelope
        baselinePrefs().edit().putLong(KEY_FINAL_DEADLINE, envelope.finalDeadlineMs).commit()
        Log.i(
            TAG,
            "SEEDED finalDeadlineMs=${envelope.finalDeadlineMs} " +
                "elapsedDeadlineMs=${envelope.elapsedRealtimeDeadlineMs}",
        )
    }

    @Test
    fun verifyFutureSessionAfterSystemEvent() {
        assumeTrue(mode() == "verify")
        val store = DeviceProtectedEmergencySessionStore(context)
        val envelope = (store.read(SessionSlot.PANIC) as SessionRead.Present).envelope
        assertTrue(envelope.token.randomId.startsWith(PREFIX))
        assertEquals(LifecycleState.ARMED, envelope.lifecycleState)
        assertTrue(envelope.elapsedRealtimeDeadlineMs > SystemClock.elapsedRealtime())
        val baseline = baselinePrefs().getLong(KEY_FINAL_DEADLINE, 0L)
        assertTrue("missing baseline", baseline > 0L)
        val driftMs = abs(envelope.finalDeadlineMs - baseline)
        assertTrue("deadline drifted by $driftMs ms", driftMs < 30_000L)
        Log.i(
            TAG,
            "VERIFIED finalDeadlineMs=${envelope.finalDeadlineMs} " +
                "elapsedDeadlineMs=${envelope.elapsedRealtimeDeadlineMs} driftMs=$driftMs",
        )
        if (args.getString(ARG_CLEANUP) == "1") {
            EmergencySessionRuntime.coordinator(context).cancel(envelope.token)
            store.clearAll()
            baselinePrefs().edit().clear().commit()
        }
    }

    private fun mode(): String? = args.getString(ARG_MODE)

    private fun baselinePrefs() = context.createDeviceProtectedStorageContext()
        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private companion object {
        const val TAG = "Stage4ReconcileProbe"
        const val ARG_MODE = "stage4Reconcile"
        const val ARG_CLEANUP = "stage4ReconcileCleanup"
        const val PREFIX = "stage4-reconcile-"
        const val PREFS = "stage4_reconciliation_probe"
        const val KEY_FINAL_DEADLINE = "final_deadline"
    }
}
