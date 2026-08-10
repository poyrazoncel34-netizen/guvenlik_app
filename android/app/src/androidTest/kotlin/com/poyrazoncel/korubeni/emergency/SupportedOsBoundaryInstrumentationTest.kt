package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Installability and supportability must be the same set.
 *
 * The manifest declares a floor (minSdk) and no ceiling, so Play will install
 * this APK on every OS above it -- including ones released after this build.
 * The capability snapshot, however, carries its own hard-coded range. When the
 * two disagree the app installs, launches, looks healthy, and then refuses
 * every Panic / Check-In / Safe Walk arm with "unsupportedOs".
 *
 * That failure is invisible to unit tests: Build.VERSION.SDK_INT is whatever
 * the host fakes. It is only observable on a device running the newer OS, which
 * is what this test is for. Run it on the newest system image available, not
 * only on the one that matches targetSdk.
 */
@RunWith(AndroidJUnit4::class)
class SupportedOsBoundaryInstrumentationTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    private fun request() = ArmRequest(
        protocolVersion = EMERGENCY_PROTOCOL_VERSION,
        randomId = "supported-os-probe",
        kind = SessionKind.PANIC,
        mainDeadlineMs = System.currentTimeMillis() + 600_000L,
        finalDeadlineMs = System.currentTimeMillis() + 600_000L,
        target = "0000000",
        entitlementDecision = EntitlementDecision.AUTHORIZED,
        pinConfigured = true,
    )

    @Test
    fun theRuntimeSupportsEveryOsThisApkCanBeInstalledOn() {
        val snapshot = AndroidEmergencyCapabilityProvider(context).snapshot(request())

        assertTrue(
            "This APK installed on API ${Build.VERSION.SDK_INT} (Android " +
                "${Build.VERSION.RELEASE}) but the safety runtime marks the OS " +
                "unsupported. Every safety session will be refused on this device.",
            snapshot.supportedOs,
        )
    }

    @Test
    fun armIsNeverRefusedForTheOsAlone() {
        val snapshot = AndroidEmergencyCapabilityProvider(context).snapshot(request())

        // Other rejection reasons are legitimate here (an emulator has no
        // telephony, notifications may be off). Only the OS verdict is the
        // app's own decision rather than the device's state.
        assertNotEquals(
            "Arm refused solely because of the OS version on API " +
                "${Build.VERSION.SDK_INT}.",
            "unsupportedOs",
            snapshot.rejectionReason(),
        )
    }
}
