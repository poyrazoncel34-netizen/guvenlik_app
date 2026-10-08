package com.poyrazoncel.korubeni.emergency

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BootIdentityTest {
    private fun file(content: String): File =
        Files.createTempFile("boot_id", "").toFile().apply {
            writeText(content)
            deleteOnExit()
        }

    @Test
    fun `a kernel boot id is read and trimmed`() {
        assertEquals(
            "4395e944-c86e-4b2b-8dd2-ac694a99c502",
            BootIdentity.bootId(file("4395e944-c86e-4b2b-8dd2-ac694a99c502\n")),
        )
    }

    @Test
    fun `anything that is not a boot id is unknown, not an identity`() {
        assertNull(BootIdentity.bootId(file("")))
        assertNull(BootIdentity.bootId(file("not-a-uuid")))
        assertNull(BootIdentity.bootId(File("/definitely/missing/boot_id")))
    }
}
