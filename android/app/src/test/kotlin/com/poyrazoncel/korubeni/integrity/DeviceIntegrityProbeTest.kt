package com.poyrazoncel.korubeni.integrity

import com.poyrazoncel.korubeni.integrity.DeviceIntegrityProbe.Companion.CHECK_ARTIFACTS
import com.poyrazoncel.korubeni.integrity.DeviceIntegrityProbe.Companion.CHECK_DEV_ENV
import com.poyrazoncel.korubeni.integrity.DeviceIntegrityProbe.Companion.CHECK_MAGISK
import com.poyrazoncel.korubeni.integrity.DeviceIntegrityProbe.Companion.CHECK_PATH_SU
import com.poyrazoncel.korubeni.integrity.DeviceIntegrityProbe.Companion.CHECK_PROPS
import com.poyrazoncel.korubeni.integrity.DeviceIntegrityProbe.Companion.CHECK_RW
import com.poyrazoncel.korubeni.integrity.DeviceIntegrityProbe.Companion.CHECK_SU
import com.poyrazoncel.korubeni.integrity.DeviceIntegrityProbe.Companion.CHECK_TEST_KEYS
import com.poyrazoncel.korubeni.integrity.DeviceIntegrityProbe.Stat
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Three-valued contract of the A-017 probe, and its coverage against what
 * safe_device 1.3.10 + RootBeer 0.1.1 ran before. The old path lists below are
 * copied from those libraries (Java source / javap of the shipped AAR) as
 * literals on purpose: they are the baseline the probe must not shrink.
 */
class DeviceIntegrityProbeTest {
    private val cleanMounts = listOf(
        "/dev/block/dm-0 / ext4 ro,seclabel,relatime 0 0",
        "tmpfs /dev tmpfs rw,seclabel,nosuid 0 0",
        "/dev/block/dm-1 /vendor ext4 ro,seclabel 0 0",
    )

    /** A user build: service.adb.root is genuinely unset (missing from the snapshot). */
    private val userProps = mapOf("ro.debuggable" to "0", "ro.secure" to "1", "ro.build.type" to "user")

    private class FakeBuild(override val type: String?, override val tags: String?) :
        DeviceIntegrityProbe.BuildInfo

    private fun probe(
        present: Set<String> = emptySet(),
        failing: Map<String, Int> = emptyMap(),
        props: Map<String, String>? = userProps,
        readableAreas: Set<String> = setOf("service.adb.root"),
        snapshotThrows: Boolean = false,
        mounts: List<String>? = cleanMounts,
        build: DeviceIntegrityProbe.BuildInfo = FakeBuild("user", "release-keys"),
        path: String? = "/product/bin:/apex/com.android.runtime/bin:/system/bin:/system/xbin",
        fsThrows: Boolean = false,
    ) = DeviceIntegrityProbe(
        fs = { p ->
            if (fsThrows) throw SecurityException("denied")
            when {
                p in present -> Stat.Exists
                p in failing -> Stat.Failed(failing.getValue(p))
                else -> Stat.Missing
            }
        },
        props = object : DeviceIntegrityProbe.PropertyReader {
            override fun snapshot(): Map<String, String>? {
                if (snapshotThrows) throw IllegalStateException("getprop")
                return props
            }
            override fun areaReadable(name: String) = name in readableAreas
        },
        mounts = { mounts },
        build = build,
        pathEnv = { path },
    )

    @Test
    fun `stock user build observes absence everywhere`() {
        val result = probe().run()
        assertEquals(
            mapOf(
                CHECK_SU to "absent", CHECK_MAGISK to "absent", CHECK_ARTIFACTS to "absent",
                CHECK_PATH_SU to "absent", CHECK_RW to "absent", CHECK_TEST_KEYS to "absent",
                CHECK_PROPS to "absent", CHECK_DEV_ENV to "absent",
            ),
            result,
        )
    }

    @Test
    fun `EACCES on any scanned path is error, never absent`() {
        val eacces = 13
        for (path in DeviceIntegrityProbe.SU_DIRS.map { it + "su" }) {
            assertEquals(path, "error", probe(failing = mapOf(path to eacces)).run()[CHECK_SU])
        }
        assertEquals(
            "error",
            probe(failing = mapOf("/system/app/Superuser.apk" to eacces)).run()[CHECK_ARTIFACTS],
        )
    }

    @Test
    fun `a filesystem exception is error, never absent`() {
        val result = probe(fsThrows = true).run()
        listOf(CHECK_SU, CHECK_MAGISK, CHECK_ARTIFACTS, CHECK_PATH_SU).forEach {
            assertEquals(it, "error", result[it])
        }
    }

    @Test
    fun `found wins over an error in the same check`() {
        val result = probe(
            present = setOf("/system/xbin/su"),
            failing = mapOf("/cache/su" to 13),
        ).run()
        assertEquals("found", result[CHECK_SU])
    }

    @Test
    fun `unreadable, empty or malformed mount table is error`() {
        assertEquals("error", probe(mounts = null).run()[CHECK_RW])
        assertEquals("error", probe(mounts = emptyList()).run()[CHECK_RW])
        assertEquals("error", probe(mounts = listOf("", "  ")).run()[CHECK_RW])
        assertEquals("error", probe(mounts = cleanMounts + "garbage line").run()[CHECK_RW])
        val throwing = DeviceIntegrityProbe(
            fs = { Stat.Missing },
            props = object : DeviceIntegrityProbe.PropertyReader {
                override fun snapshot() = userProps
                override fun areaReadable(name: String) = true
            },
            mounts = { throw IllegalStateException("io") },
            build = FakeBuild("user", "release-keys"),
            pathEnv = { "/system/bin" },
        )
        assertEquals("error", throwing.run()[CHECK_RW])
    }

    @Test
    fun `every RootBeer non-writable path mounted rw is found`() {
        val rootBeerPathsThatShouldNotBeWritable = listOf(
            "/system", "/system/bin", "/system/sbin", "/system/xbin", "/vendor/bin", "/sbin", "/etc",
        )
        for (mountPoint in rootBeerPathsThatShouldNotBeWritable) {
            val rw = cleanMounts + "/dev/block/x $mountPoint ext4 rw,seclabel 0 0"
            assertEquals(mountPoint, "found", probe(mounts = rw).run()[CHECK_RW])
            val ro = cleanMounts + "/dev/block/x $mountPoint ext4 ro,seclabel 0 0"
            assertEquals(mountPoint, "absent", probe(mounts = ro).run()[CHECK_RW])
        }
        // "rw" must be a whole option, as in RootBeer's split on ','.
        val lookalike = cleanMounts + "/dev/block/x /system ext4 ro,rwx 0 0"
        assertEquals("absent", probe(mounts = lookalike).run()[CHECK_RW])
    }

    @Test
    fun `failed, empty or throwing snapshot is error, never absent`() {
        assertEquals("error", probe(props = null).run()[CHECK_PROPS])
        assertEquals("error", probe(props = emptyMap()).run()[CHECK_PROPS])
        assertEquals("error", probe(snapshotThrows = true).run()[CHECK_PROPS])
    }

    @Test
    fun `mandatory property missing or blank is error`() {
        for (name in listOf("ro.debuggable", "ro.secure")) {
            assertEquals(name, "error", probe(props = userProps - name).run()[CHECK_PROPS])
            assertEquals(name, "error", probe(props = userProps + (name to "")).run()[CHECK_PROPS])
            // Even a readable area does not excuse a mandatory property.
            val everything = setOf("ro.debuggable", "ro.secure", "service.adb.root")
            assertEquals(
                name,
                "error",
                probe(props = userProps - name, readableAreas = everything).run()[CHECK_PROPS],
            )
        }
    }

    @Test
    fun `service_adb_root missing is absent only when its area is provably readable`() {
        assertEquals("absent", probe(readableAreas = setOf("service.adb.root")).run()[CHECK_PROPS])
        assertEquals("error", probe(readableAreas = emptySet()).run()[CHECK_PROPS])
        assertEquals(
            "error",
            probe(props = userProps + ("service.adb.root" to ""), readableAreas = emptySet()).run()[CHECK_PROPS],
        )
    }

    @Test
    fun `each dangerous property value is found`() {
        assertEquals("found", probe(props = userProps + ("ro.debuggable" to "1")).run()[CHECK_PROPS])
        assertEquals("found", probe(props = userProps + ("ro.secure" to "0")).run()[CHECK_PROPS])
        assertEquals("found", probe(props = userProps + ("service.adb.root" to "1")).run()[CHECK_PROPS])
        // FOUND wins over another property's failure.
        assertEquals(
            "found",
            probe(props = userProps - "ro.secure" + ("ro.debuggable" to "1")).run()[CHECK_PROPS],
        )
    }

    @Test
    fun `snapshot parser rejects empty and malformed output`() {
        assertEquals(null, DeviceIntegrityProbe.parseSnapshot(""))
        assertEquals(null, DeviceIntegrityProbe.parseSnapshot("\n  \n"))
        assertEquals(null, DeviceIntegrityProbe.parseSnapshot("[ro.secure]: [1]\ngarbage"))
        assertEquals(null, DeviceIntegrityProbe.parseSnapshot("ro.secure=1"))
        assertEquals(
            mapOf("ro.secure" to "1", "service.adb.root" to ""),
            DeviceIntegrityProbe.parseSnapshot("[ro.secure]: [1]\n[service.adb.root]: []\n"),
        )
    }

    @Test
    fun `null build tags are error for test-keys and dev-environment`() {
        val result = probe(build = FakeBuild("user", null)).run()
        assertEquals("error", result[CHECK_TEST_KEYS])
        assertEquals("error", result[CHECK_DEV_ENV])
    }

    @Test
    fun `dev environment detection mirrors safe_device isDevelopmentEnvironment`() {
        assertEquals("found", probe(build = FakeBuild("userdebug", "release-keys")).run()[CHECK_DEV_ENV])
        assertEquals("found", probe(build = FakeBuild("eng", "release-keys")).run()[CHECK_DEV_ENV])
        assertEquals("found", probe(build = FakeBuild("user", "test-keys")).run()[CHECK_DEV_ENV])
        assertEquals("found", probe(build = FakeBuild("user", "dev-keys")).run()[CHECK_DEV_ENV])
        assertEquals("found", probe(props = userProps + ("ro.debuggable" to "1")).run()[CHECK_DEV_ENV])
        assertEquals("error", probe(props = userProps - "ro.debuggable").run()[CHECK_DEV_ENV])
        assertEquals("error", probe(props = null).run()[CHECK_DEV_ENV])
    }

    @Test
    fun `missing or empty PATH is error, never absent`() {
        assertEquals("error", probe(path = null).run()[CHECK_PATH_SU])
        assertEquals("error", probe(path = "").run()[CHECK_PATH_SU])
        assertEquals("error", probe(path = ":::").run()[CHECK_PATH_SU])
        assertEquals("found", probe(path = "/odd/dir/", present = setOf("/odd/dir/su")).run()[CHECK_PATH_SU])
    }

    // ---- Coverage against the old implementation (D2 + A1 parity) ----

    /** RootBeer 0.1.1 `Const.suPaths`: scanned by `checkForBinary` AND the JNI `checkForRoot`. */
    private val rootBeerSuPaths = listOf(
        "/data/local/", "/data/local/bin/", "/data/local/xbin/", "/sbin/", "/su/bin/",
        "/system/bin/", "/system/bin/.ext/", "/system/bin/failsafe/", "/system/sd/xbin/",
        "/system/usr/we-need-root/", "/system/xbin/", "/cache/", "/data/", "/dev/",
    )

    /** safe_device 1.3.10: checkSuBinary, checkRootMethod1, hasObviousRootSigns, checkEmulatorRootFiles. */
    private val safeDevicePaths = listOf(
        "/sbin/su", "/system/bin/su", "/system/xbin/su", "/data/local/xbin/su", "/data/local/bin/su",
        "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su", "/su/bin/su",
        "/system/app/Superuser.apk", "/system/app/SuperSU.apk", "/system/priv-app/SuperSU/SuperSU.apk",
        "/system/xbin/daemonsu", "/data/local/tmp/supersu", "/dev/com.koushikdutta.superuser.daemon",
        "/system/etc/init.d/99SuperSUDaemon",
    )

    private fun detects(path: String): Boolean =
        probe(present = setOf(path)).run().values.contains("found")

    @Test
    fun `every su path the RootBeer native library scanned is detected`() {
        for (dir in rootBeerSuPaths) assertTrue(dir + "su", detects(dir + "su"))
    }

    @Test
    fun `every su and magisk binary RootBeer Java scanned is detected`() {
        for (dir in rootBeerSuPaths) {
            assertTrue(dir + "su", detects(dir + "su"))
            assertTrue(dir + "magisk", detects(dir + "magisk"))
        }
    }

    @Test
    fun `native and Java PATH-derived entries are detected`() {
        // Const.getPaths() appends every PATH directory to suPaths.
        val probe = probe(path = "/apex/x/bin:/product/bin", present = setOf("/product/bin/su"))
        assertEquals("found", probe.run()[CHECK_PATH_SU])
    }

    @Test
    fun `every safe_device path is detected`() {
        for (path in safeDevicePaths) assertTrue(path, detects(path))
    }
}
