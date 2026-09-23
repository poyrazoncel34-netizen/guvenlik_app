package com.poyrazoncel.korubeni.integrity

import android.content.Context
import android.content.pm.PackageManager
import android.os.SystemClock
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * A-017 device evidence. Runs inside the app process (the app's UID and its
 * package visibility), so what it observes is what production code observes.
 *
 * Not a substitute for the JVM tests; it measures the real device.
 * Results are logged under tag A017_EVIDENCE and recorded in
 * docs/audit/device-verification-2026-09-22-a017-integrity-probe.md.
 */
@RunWith(AndroidJUnit4::class)
class DeviceIntegrityEmulatorProbeTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    /**
     * D1 negative control. Precondition (checked by the operator with
     * `pm list packages`): a package named com.topjohnwu.magisk IS installed.
     * If the app cannot see it, RootBeer's package checks could never have
     * fired in this app.
     */
    @Test
    fun installedRootManagerPackageIsInvisibleToTheApp() {
        val pm = context.packageManager
        // Positive control: the API works for a package the app may see.
        pm.getPackageInfo(context.packageName, 0)

        val visible = try {
            pm.getPackageInfo(MAGISK, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
        Log.i(TAG, "D1 getPackageInfo($MAGISK) visible=$visible")

        // The exact code path safe_device ran: RootBeer 0.1.1, shipped in this APK.
        val rootBeer = Class.forName("com.scottyab.rootbeer.RootBeer")
            .getConstructor(Context::class.java).newInstance(context)
        val managementApps = rootBeer.javaClass.getMethod("detectRootManagementApps")
            .invoke(rootBeer) as Boolean
        val dangerousApps = rootBeer.javaClass.getMethod("detectPotentiallyDangerousApps")
            .invoke(rootBeer) as Boolean
        Log.i(TAG, "D1 RootBeer.detectRootManagementApps=$managementApps " +
            "detectPotentiallyDangerousApps=$dangerousApps")

        assertFalse("package visibility hides the installed package", visible)
        assertFalse("RootBeer package check cannot fire", managementApps)
    }

    /** New probe vs the old safe_device verdict on the same device. */
    @Test
    fun probeOutcomesAndOldVerdictOnThisDevice() {
        val started = SystemClock.elapsedRealtime()
        val probe = DeviceIntegrityProbe()
        val result = probe.run()
        val elapsed = SystemClock.elapsedRealtime() - started
        Log.i(TAG, "PROBE ms=$elapsed result=$result")
        Log.i(TAG, "PROBE failedPaths=${probe.failedPaths()}")
        val reader = DeviceIntegrityProbe.GetpropReader()
        val snapshot = reader.snapshot()
        Log.i(
            TAG,
            "PROPS snapshotSize=${snapshot?.size} " +
                DeviceIntegrityProbe.DANGEROUS_PROPS.joinToString(" ") { (name, _) ->
                    "$name=${snapshot?.get(name) ?: "<missing>"}" +
                        "(areaReadable=${reader.areaReadable(name)})"
                },
        )
        Log.i(TAG, "BUILD type=${android.os.Build.TYPE} tags=${android.os.Build.TAGS}")

        val rooted = Class.forName("com.xamdesign.safe_device.Rooted.RootedCheck")
        val details = rooted.getMethod("getRootDetectionDetails", Context::class.java)
            .invoke(null, context) as Map<*, *>
        Log.i(TAG, "OLD safe_device details=$details")

        assertEquals(8, result.size)
        assertTrue(result.values.all { it in setOf("found", "absent", "error") })
        assertTrue("probe must finish well inside the 3 s Dart timeout", elapsed < 3_000)
    }

    private companion object {
        const val TAG = "A017_EVIDENCE"
        const val MAGISK = "com.topjohnwu.magisk"
    }
}
