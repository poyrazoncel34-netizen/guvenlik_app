package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.provider.Settings
import java.io.File

/**
 * Which boot the device is in, so an elapsed-realtime deadline can be tied to
 * the boot that wrote it (audit A-02).
 *
 * `Settings.Global.BOOT_COUNT` is platform-maintained and readable without a
 * permission, including in direct-boot mode. Any failure reads as
 * [UNKNOWN_BOOT_COUNT], which keeps the coordinator's historical same-boot
 * assumption instead of guessing.
 */
object BootIdentity {
    fun current(context: Context): Int = try {
        Settings.Global.getInt(
            context.contentResolver,
            Settings.Global.BOOT_COUNT,
            UNKNOWN_BOOT_COUNT,
        )
    } catch (_: RuntimeException) {
        UNKNOWN_BOOT_COUNT
    }

    /**
     * The kernel's per-boot UUID, a second identity that does not depend on
     * Settings (audit A-02r). Null on any failure -- an unreadable id is not
     * evidence of anything.
     */
    fun bootId(source: File = File(BOOT_ID_PATH)): String? = try {
        source.readText().trim().takeIf { BOOT_ID.matches(it) }
    } catch (_: Exception) {
        null
    }

    private const val BOOT_ID_PATH = "/proc/sys/kernel/random/boot_id"
    private val BOOT_ID = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
}
