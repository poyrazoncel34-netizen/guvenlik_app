package com.poyrazoncel.korubeni.integrity

import android.os.Build
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Root-detection probe that replaces the safe_device plugin at runtime
 * (audit A-017).
 *
 * safe_device, and the RootBeer 0.1.1 library under it, answer "not rooted"
 * whenever a check fails: `File.exists()` is false for EACCES as well as
 * ENOENT, a failed `exec` is "no su", a null `mount` output is "nothing
 * mounted rw". Here every check has three outcomes, and only a check that
 * actually observed absence may say [Outcome.ABSENT]. Anything else --
 * exception, permission error, timeout, unparseable output -- is
 * [Outcome.ERROR], and the Dart side never turns an error into "clean".
 *
 * Coverage is a superset of what safe_device's `isJailBroken` ran; the
 * line-by-line comparison lives in
 * docs/audit/device-verification-2026-09-22-a017-integrity-probe.md.
 * Deliberately NOT carried over: RootBeer's package-name checks (invisible
 * to this app under targetSdk >= 30 without <queries>, so they could only
 * ever answer "not installed") and its JNI su scan (same paths as
 * [SU_DIRS], covered here by lstat).
 */
class DeviceIntegrityProbe(
    private val fs: FileSystem = OsFileSystem,
    private val props: PropertyReader = GetpropReader(),
    private val mounts: MountSource = ProcMounts,
    private val build: BuildInfo = DeviceBuildInfo,
    private val pathEnv: () -> String? = { System.getenv("PATH") },
) {
    enum class Outcome(val wire: String) { FOUND("found"), ABSENT("absent"), ERROR("error") }

    sealed interface Stat {
        object Exists : Stat
        object Missing : Stat
        data class Failed(val errno: Int) : Stat
    }

    fun interface FileSystem {
        fun lstat(path: String): Stat
    }

    /**
     * A property snapshot. `getprop` silently OMITS properties this process
     * may not read, and returns "" for them when asked one by one, so neither
     * a missing key nor a blank value is by itself proof that a property is
     * unset -- see [areaReadable].
     */
    interface PropertyReader {
        /** Every property the process can read, or null when the snapshot failed. */
        fun snapshot(): Map<String, String>?

        /**
         * True only when the property area that would hold [name] is
         * readable by this process -- then a key missing from the snapshot
         * is genuinely unset. False when that cannot be established.
         */
        fun areaReadable(name: String): Boolean
    }

    fun interface MountSource {
        /** Raw mount table lines, or null when the table could not be read. */
        fun lines(): List<String>?
    }

    interface BuildInfo {
        val type: String?
        val tags: String?
    }

    fun run(): Map<String, String> = linkedMapOf(
        CHECK_SU to anyPresent(SU_DIRS.map { it + "su" }),
        CHECK_MAGISK to anyPresent(SU_DIRS.map { it + "magisk" }),
        CHECK_ARTIFACTS to anyPresent(SUPERUSER_ARTIFACTS),
        CHECK_PATH_SU to pathSu(),
        CHECK_RW to rwSystemMounts(),
        CHECK_TEST_KEYS to testKeys(),
        CHECK_PROPS to dangerousProps(),
        CHECK_DEV_ENV to developmentEnvironment(),
    ).mapValues { it.value.wire }

    /** Paths whose lstat failed with something other than ENOENT/ENOTDIR (diagnostics only). */
    fun failedPaths(): List<String> =
        (SU_DIRS.flatMap { listOf(it + "su", it + "magisk") } + SUPERUSER_ARTIFACTS)
            .filter { safeLstat(it) is Stat.Failed }

    private fun anyPresent(paths: List<String>): Outcome {
        var failed = false
        for (path in paths) {
            when (safeLstat(path)) {
                Stat.Exists -> return Outcome.FOUND
                Stat.Missing -> Unit
                is Stat.Failed -> failed = true
            }
        }
        return if (failed) Outcome.ERROR else Outcome.ABSENT
    }

    private fun safeLstat(path: String): Stat = try {
        fs.lstat(path)
    } catch (_: Exception) {
        Stat.Failed(-1)
    }

    /** `which su` / `su --version` in the old code: an `su` anywhere on PATH. */
    private fun pathSu(): Outcome {
        val path = try {
            pathEnv()
        } catch (_: Exception) {
            null
        }
        if (path.isNullOrBlank()) return Outcome.ERROR
        val dirs = path.split(':').filter { it.isNotBlank() }
        if (dirs.isEmpty()) return Outcome.ERROR
        return anyPresent(dirs.map { it.trimEnd('/') + "/su" })
    }

    /** RootBeer `checkForRWPaths`: a system mount point mounted read-write. */
    private fun rwSystemMounts(): Outcome {
        val lines = try {
            mounts.lines()
        } catch (_: Exception) {
            null
        } ?: return Outcome.ERROR
        val entries = lines.filter { it.isNotBlank() }
        if (entries.isEmpty()) return Outcome.ERROR
        for (line in entries) {
            val fields = line.trim().split(WHITESPACE)
            if (fields.size < 4) return Outcome.ERROR
            if (fields[1] in RW_SENSITIVE_MOUNTS && "rw" in fields[3].split(',')) {
                return Outcome.FOUND
            }
        }
        return Outcome.ABSENT
    }

    private fun testKeys(): Outcome {
        val tags = try {
            build.tags
        } catch (_: Exception) {
            null
        } ?: return Outcome.ERROR
        return if ("test-keys" in tags) Outcome.FOUND else Outcome.ABSENT
    }

    /** ro.debuggable=1, ro.secure=0, service.adb.root=1 (RootBeer + safe_device). */
    private fun dangerousProps(): Outcome {
        val snapshot = propertySnapshot ?: return Outcome.ERROR
        var failed = false
        for ((name, dangerous) in DANGEROUS_PROPS) {
            when (snapshot[name]) {
                null, "" -> {
                    // Mandatory properties exist on every build: missing means unreadable.
                    // Optional ones are "absent" only if their area is provably readable.
                    if (name in MANDATORY_PROPS || !safeAreaReadable(name)) failed = true
                }
                dangerous -> return Outcome.FOUND
                else -> Unit
            }
        }
        return if (failed) Outcome.ERROR else Outcome.ABSENT
    }

    /**
     * safe_device's `isDevelopmentEnvironment`. On such builds it ignored the
     * property and test-keys signals (every eng/userdebug image has them);
     * the Dart side keeps that leniency, and ONLY when this reads FOUND.
     */
    private fun developmentEnvironment(): Outcome {
        val type = try {
            build.type
        } catch (_: Exception) {
            null
        }
        val tags = try {
            build.tags
        } catch (_: Exception) {
            null
        }
        if (type == "eng" || type == "userdebug") return Outcome.FOUND
        if (tags != null && ("dev-keys" in tags || "test-keys" in tags)) return Outcome.FOUND
        val debuggable = propertySnapshot?.get("ro.debuggable")
        if (debuggable == "1") return Outcome.FOUND
        if (type == null || tags == null || debuggable.isNullOrEmpty()) return Outcome.ERROR
        return Outcome.ABSENT
    }

    /** Read once per run; null when the snapshot itself failed. */
    private val propertySnapshot: Map<String, String>? by lazy {
        try {
            props.snapshot()
        } catch (_: Exception) {
            null
        }
    }

    private fun safeAreaReadable(name: String): Boolean = try {
        props.areaReadable(name)
    } catch (_: Exception) {
        false
    }

    object OsFileSystem : FileSystem {
        override fun lstat(path: String): Stat = try {
            Os.lstat(path)
            Stat.Exists
        } catch (e: ErrnoException) {
            // ENOTDIR: a parent is a regular file, so the path cannot exist.
            if (e.errno == OsConstants.ENOENT || e.errno == OsConstants.ENOTDIR) {
                Stat.Missing
            } else {
                Stat.Failed(e.errno)
            }
        }
    }

    /**
     * `getprop` (one process, hard deadline, no hidden-API reflection).
     * The output must be non-empty and every line must parse, or the whole
     * snapshot is rejected.
     */
    class GetpropReader(private val timeoutMs: Long = 1_500) : PropertyReader {
        override fun snapshot(): Map<String, String>? =
            exec(listOf(GETPROP))?.let(::parseSnapshot)

        override fun areaReadable(name: String): Boolean {
            val context = exec(listOf(GETPROP, "-Z", name))?.trim().orEmpty()
            if (!CONTEXT.matches(context)) return false
            return try {
                Os.access("/dev/__properties__/$context", OsConstants.R_OK)
            } catch (_: ErrnoException) {
                false
            }
        }

        private fun exec(command: List<String>): String? {
            var process: Process? = null
            return try {
                val started = ProcessBuilder(command).redirectErrorStream(true).start()
                process = started
                // Drain on a separate thread: a full property dump can exceed the
                // pipe buffer, and waiting first would turn that into a timeout.
                var output: String? = null
                val reader = Thread {
                    output = try {
                        started.inputStream.bufferedReader().use { it.readText() }
                    } catch (_: Exception) {
                        null
                    }
                }.apply {
                    isDaemon = true
                    start()
                }
                val finished = started.waitFor(timeoutMs, TimeUnit.MILLISECONDS)
                if (!finished || started.exitValue() != 0) return null
                reader.join(timeoutMs)
                if (reader.isAlive) null else output
            } catch (_: Exception) {
                null
            } finally {
                // SIGKILL, then a short reap so a stuck getprop never lingers as a zombie.
                process?.let {
                    it.destroyForcibly()
                    try {
                        it.waitFor(REAP_TIMEOUT_MS, TimeUnit.MILLISECONDS)
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                    }
                }
            }
        }
    }

    object ProcMounts : MountSource {
        override fun lines(): List<String>? = try {
            File("/proc/self/mounts").readLines()
        } catch (_: Exception) {
            null
        }
    }

    object DeviceBuildInfo : BuildInfo {
        override val type: String? get() = Build.TYPE
        override val tags: String? get() = Build.TAGS
    }

    companion object {
        const val CHECK_SU = "suBinary"
        const val CHECK_MAGISK = "magiskBinary"
        const val CHECK_ARTIFACTS = "superuserArtifacts"
        const val CHECK_PATH_SU = "pathSuBinary"
        const val CHECK_RW = "rwSystemMounts"
        const val CHECK_TEST_KEYS = "testKeys"
        const val CHECK_PROPS = "dangerousProps"
        const val CHECK_DEV_ENV = "developmentEnvironment"

        /**
         * RootBeer 0.1.1 `Const.suPaths` (its Java `checkForBinary` and its
         * JNI `checkForRoot` both scan exactly these); safe_device's own su
         * paths are all inside this list.
         */
        val SU_DIRS = listOf(
            "/data/local/",
            "/data/local/bin/",
            "/data/local/xbin/",
            "/sbin/",
            "/su/bin/",
            "/system/bin/",
            "/system/bin/.ext/",
            "/system/bin/failsafe/",
            "/system/sd/xbin/",
            "/system/usr/we-need-root/",
            "/system/xbin/",
            "/cache/",
            "/data/",
            "/dev/",
        )

        /** safe_device `hasObviousRootSigns` + `checkEmulatorRootFiles` non-su entries. */
        val SUPERUSER_ARTIFACTS = listOf(
            "/system/app/Superuser.apk",
            "/system/app/SuperSU.apk",
            "/system/priv-app/SuperSU/SuperSU.apk",
            "/system/xbin/daemonsu",
            "/system/etc/init.d/99SuperSUDaemon",
            "/data/local/tmp/supersu",
            "/dev/com.koushikdutta.superuser.daemon",
        )

        /** RootBeer 0.1.1 `Const.pathsThatShouldNotBeWritable`. */
        val RW_SENSITIVE_MOUNTS = setOf(
            "/system",
            "/system/bin",
            "/system/sbin",
            "/system/xbin",
            "/vendor/bin",
            "/sbin",
            "/etc",
        )

        val DANGEROUS_PROPS = listOf(
            "ro.debuggable" to "1",
            "ro.secure" to "0",
            "service.adb.root" to "1",
        )

        /** Present with a non-blank value on every Android build. */
        val MANDATORY_PROPS = setOf("ro.debuggable", "ro.secure")

        private const val GETPROP = "/system/bin/getprop"
        private val LINE = Regex("^\\[([^\\]]+)]: \\[(.*)]$")
        // MLS categories (":s0:c512,c768") are accepted; anything else fails closed.
        private val CONTEXT = Regex("^u:object_r:[a-z0-9_]+:s0(:c[0-9]+(,c[0-9]+)*)?$")
        private const val REAP_TIMEOUT_MS = 200L

        /** Null when empty or when any line is malformed. */
        fun parseSnapshot(output: String): Map<String, String>? {
            val lines = output.lines().filter { it.isNotBlank() }
            if (lines.isEmpty()) return null
            val result = HashMap<String, String>(lines.size)
            for (line in lines) {
                val match = LINE.matchEntire(line.trimEnd()) ?: return null
                result[match.groupValues[1]] = match.groupValues[2]
            }
            return result
        }

        private val WHITESPACE = Regex("\\s+")
    }
}
