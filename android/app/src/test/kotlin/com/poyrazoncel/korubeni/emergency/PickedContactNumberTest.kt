package com.poyrazoncel.korubeni.emergency

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Which representation of a picked phone row MainActivity hands to Dart.
 *
 * The picker used to read only Phone.NUMBER, the string exactly as the
 * contact book stores it. It now prefers the provider's E.164
 * NORMALIZED_NUMBER -- but only when that denotes the number the user can
 * see. The provider keeps a NORMALIZED_NUMBER supplied by the writing app
 * verbatim and no screen shows it, so trusting it blindly would let any app
 * holding WRITE_CONTACTS redirect the emergency call while the picker shows
 * the real number.
 */
class PickedContactNumberTest {
    @Test
    fun `the provider E164 number wins when it is the visible number`() {
        assertEquals(
            "+905321234567",
            ContactInputBoundary.pickedContactNumber("+905321234567", "0532 123 45 67"),
        )
    }

    @Test
    fun `without a normalized number the visible number is sanitized`() {
        assertEquals(
            "0532 123 45 67",
            ContactInputBoundary.pickedContactNumber(null, "0532\u00A0123\u00A045\u00A067"),
        )
        assertEquals(
            "+90 532 123 45 67",
            ContactInputBoundary.pickedContactNumber("", "\u202A+90 532 123 45 67\u202C"),
        )
    }

    @Test
    fun `an unusable normalized value does not shadow a callable visible number`() {
        assertEquals(
            "0532 123 45 67",
            ContactInputBoundary.pickedContactNumber("12", "0532 123 45 67"),
        )
    }

    @Test
    fun `a hidden normalized number that is not the visible one is ignored`() {
        // The redirect: NUMBER (what the picker and the Contacts app show)
        // is the real contact, NORMALIZED_NUMBER was written by another app.
        assertEquals(
            "0532 123 45 67",
            ContactInputBoundary.pickedContactNumber("+905550001122", "0532 123 45 67"),
        )
    }

    @Test
    fun `an international visible number must match digit for digit`() {
        assertEquals(
            "+90 532 123 45 67",
            ContactInputBoundary.pickedContactNumber("+495321234567", "+90 532 123 45 67"),
        )
        assertEquals(
            "+905321234567",
            ContactInputBoundary.pickedContactNumber("+905321234567", "0090 532 123 45 67"),
        )
        // "(0)" after the country code is a trunk digit, not part of the number.
        assertEquals(
            "+905321234567",
            ContactInputBoundary.pickedContactNumber("+905321234567", "+90 (0532) 123 45 67"),
        )
    }

    @Test
    fun `a normalized number may only add a one to three digit country code`() {
        assertEquals(
            "0532 123 45 67",
            ContactInputBoundary.pickedContactNumber("+12345321234567", "0532 123 45 67"),
        )
    }

    @Test
    fun `visible digits in any script and look-alike dashes still match`() {
        assertEquals(
            "+905321234567",
            ContactInputBoundary.pickedContactNumber(
                "+905321234567",
                "\u0660\u0665\u0663\u0662 \u0661\u0662\u0663 \u0664\u0665 \u0666\u0667",
            ),
        )
        assertEquals(
            "+905321234567",
            ContactInputBoundary.pickedContactNumber("+905321234567", "0532\u2011123\u201145\u201167"),
        )
    }

    @Test
    fun `a visible number that starts with a dial command is never replaced`() {
        assertEquals(
            "*31#0532 123 45 67",
            ContactInputBoundary.pickedContactNumber("+905321234567", "*31#0532 123 45 67"),
        )
    }

    @Test
    fun `a stored dial string reaches Dart so it is reported as invalid not missing`() {
        assertEquals(
            "*31#05321234567",
            ContactInputBoundary.pickedContactNumber(null, "*31#05321234567"),
        )
    }

    @Test
    fun `a normalized value without a visible number is ignored`() {
        assertEquals("", ContactInputBoundary.pickedContactNumber("+905321234567", null))
        assertEquals("", ContactInputBoundary.pickedContactNumber("abc", ""))
    }

    @Test
    fun `a blank visible number is passed through for Dart to classify`() {
        // Kotlin and Dart disagree on what whitespace is (U+001C..001F,
        // U+0085), so emptiness is decided once, on the Dart side.
        assertEquals(" ", ContactInputBoundary.pickedContactNumber("abc", "\u00A0"))
        assertEquals("\u0085", ContactInputBoundary.pickedContactNumber("abc", "\u0085"))
    }

    @Test
    fun `a row without any number yields an empty string`() {
        assertEquals("", ContactInputBoundary.pickedContactNumber(null, null))
        assertEquals("", ContactInputBoundary.pickedContactNumber("", "\u200E\u202C"))
    }

    @Test
    fun `provider normalization drops a stored pause suffix`() {
        // Documented trade-off of preferring NORMALIZED_NUMBER: the provider's
        // E.164 form carries no pause/extension, so the main line is dialed.
        assertEquals(
            "+902124440000",
            ContactInputBoundary.pickedContactNumber("+902124440000", "0212 444 00 00,,105"),
        )
    }
}
