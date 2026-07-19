package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class EmergencyTargetValidatorTest {
    @Test
    fun `normalization keeps ASCII digits and one leading plus`() {
        assertEquals("+905550102030", EmergencyTargetValidator.normalize(" +90 (555) 010-20-30 "))
        assertEquals("905550102030", EmergencyTargetValidator.normalize("90+555+0102030"))
    }

    @Test
    fun `unicode numerals and punctuation cannot become callable`() {
        assertEquals("+", EmergencyTargetValidator.normalize("+٩٠٥٥٥٥٠١٠٢٠٣٠"))
        assertFalse(EmergencyTargetValidator.isCallable("+٩٠٥٥٥٥٠١٠٢٠٣٠"))
        assertFalse(EmergencyTargetValidator.isCallable("() -"))
    }

    @Test
    fun `callable boundary accepts only seven to fifteen digits`() {
        assertTrue(EmergencyTargetValidator.isCallable("+905550102030"))
        assertTrue(EmergencyTargetValidator.isCallable(" (+90) 555-010.20.30 "))
        assertTrue(EmergencyTargetValidator.isCallable("1234567"))
        assertFalse(EmergencyTargetValidator.isCallable("123456"))
        assertFalse(EmergencyTargetValidator.isCallable("1234567890123456"))
    }

    @Test
    fun `URI syntax extensions and control characters are rejected instead of stripped`() {
        val maliciousInputs = listOf(
            "tel:+905550102030",
            "+905550102030?body=999",
            "+905550102030;ext=123",
            "+905550102030,123",
            "+905550102030#123",
            "+905550102030*123",
            "+905550102030\r\n999",
            "javascript:+905550102030",
            "90+5550102030",
        )

        maliciousInputs.forEach { raw ->
            assertFalse("unsafe target became callable: ${raw.toCharArray().contentToString()}", EmergencyTargetValidator.isCallable(raw))
        }
    }

    @Test
    fun `deterministic hostile input fuzz preserves strict target grammar`() {
        val random = Random(0x4B4F5255)
        val safeFormatting = charArrayOf(' ', '-', '(', ')', '.')
        val forbidden = charArrayOf(
            ':', ';', '?', '#', '*', ',', '/', '\\', '@', '=', '&', '%',
            '\n', '\r', '\t', 'x', 'T', '\u0661', '\uFF11', '\u200B',
        )
        val alphabet = "0123456789+".toCharArray() + safeFormatting + forbidden

        repeat(20_000) { trace ->
            val length = random.nextInt(0, 48)
            val raw = buildString(length) {
                repeat(length) { append(alphabet[random.nextInt(alphabet.size)]) }
            }
            val normalized = EmergencyTargetValidator.normalize(raw)

            assertTrue(
                "normalizer escaped ASCII target grammar at trace=$trace",
                normalized.matches(Regex("\\+?[0-9]*")),
            )
            assertEquals(
                "normalizer is not idempotent at trace=$trace",
                normalized,
                EmergencyTargetValidator.normalize(normalized),
            )

            if (raw.any { it in forbidden }) {
                assertFalse(
                    "forbidden syntax became callable at trace=$trace raw=${raw.toCharArray().contentToString()}",
                    EmergencyTargetValidator.isCallable(raw),
                )
            }
        }
    }
}
