package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.provider.Settings

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
}
