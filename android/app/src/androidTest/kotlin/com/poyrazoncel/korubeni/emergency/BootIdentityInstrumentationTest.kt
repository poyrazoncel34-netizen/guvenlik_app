package com.poyrazoncel.korubeni.emergency

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Audit A-02r: the kernel boot id is the second boot identity only if the
 * APP'S OWN process may read it under its SELinux domain. `adb shell run-as`
 * runs in a different domain (runas_app), so it proves nothing; this runs in
 * the target app process.
 */
@RunWith(AndroidJUnit4::class)
class BootIdentityInstrumentationTest {
    @Test
    fun bothBootIdentitiesAreReadableFromTheAppProcess() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        assertNotNull("kernel boot id unreadable from the app domain", BootIdentity.bootId())
        assertNotEquals(UNKNOWN_BOOT_COUNT, BootIdentity.current(context))
    }
}
