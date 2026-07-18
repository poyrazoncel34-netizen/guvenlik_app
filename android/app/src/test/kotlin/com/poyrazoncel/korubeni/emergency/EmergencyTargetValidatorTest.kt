package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

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
        assertTrue(EmergencyTargetValidator.isCallable("1234567"))
        assertFalse(EmergencyTargetValidator.isCallable("123456"))
        assertFalse(EmergencyTargetValidator.isCallable("1234567890123456"))
    }
}
