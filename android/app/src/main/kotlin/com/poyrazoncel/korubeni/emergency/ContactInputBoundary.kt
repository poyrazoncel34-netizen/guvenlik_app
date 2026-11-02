package com.poyrazoncel.korubeni.emergency

/**
 * The pick and manual-entry boundary for a phone number the user chose.
 *
 * Kept apart from [EmergencyTargetValidator] on purpose: that object guards the
 * dispatch kernel and stays strict, while this one is lenient about
 * contact-book formatting before handing over to it.
 *
 * Mirrors AndroidIntentService.sanitizeContactInput and
 * normalizedContactInputOrNull (Dart); both sides are pinned to
 * test/core/services/contact_number_input_vectors.txt.
 */
object ContactInputBoundary {
    /**
     * Removes the formatting noise contact books carry -- no-break and other
     * Unicode spaces, bidi marks, zero-width characters, '/', tabs, fullwidth
     * forms -- WITHOUT widening what is callable: the result still goes through
     * [EmergencyTargetValidator.normalizedCallableOrNull], which keeps
     * rejecting letters, '*', '#', ',', ';', URIs and extensions.
     */
    fun sanitizeContactInput(raw: String): String {
        val sanitized = StringBuilder(raw.length)
        var index = 0
        while (index < raw.length) {
            val codePoint = raw.codePointAt(index)
            index += Character.charCount(codePoint)
            if (isInvisibleFormatting(codePoint)) continue
            // Fullwidth ASCII only -- deliberately not a general NFKC, which
            // would let a superscript footnote digit join the number.
            val folded = if (codePoint in 0xFF01..0xFF5E) codePoint - 0xFEE0 else codePoint
            if (isSeparatorSpace(folded)) sanitized.append(' ') else sanitized.appendCodePoint(folded)
        }
        return sanitized.toString()
    }

    /** Sanitize, then the unchanged dispatch rule. */
    fun normalizedContactInputOrNull(raw: String): String? =
        EmergencyTargetValidator.normalizedCallableOrNull(sanitizeContactInput(raw))

    /**
     * Which representation of a picked phone row is handed to Dart.
     *
     * The provider's E.164 NORMALIZED_NUMBER is preferred, but only when it
     * denotes the number the user can see: the provider keeps a
     * NORMALIZED_NUMBER supplied by the writing app verbatim and no screen
     * shows it, so an app holding WRITE_CONTACTS could otherwise redirect the
     * emergency call while the picker shows the real number. In every other
     * case the visible NUMBER is returned, sanitized and NOT validated, so
     * Dart decides "no number" versus "a number that cannot be called".
     */
    fun pickedContactNumber(normalizedNumber: String?, number: String?): String {
        val visible = sanitizeContactInput(number.orEmpty())
        val provider = normalizedContactInputOrNull(normalizedNumber.orEmpty())
        return if (provider != null && denotesSameNumber(provider, visible)) provider else visible
    }

    /**
     * True when the E.164 [canonical] is the number [visible] spells: the same
     * digits for an international form ('+' or '00'), allowing one "(0)"
     * trunk digit after the country code; for a national form, a one to three
     * digit country code followed by the national digits minus one trunk '0'.
     *
     * Digits of any script count, because only this comparison reads them --
     * the value dialed is [canonical]. Reading stops at the first letter or
     * dial command, so a pause or extension suffix never blocks a match and a
     * leading command never produces one.
     */
    private fun denotesSameNumber(canonical: String, visible: String): Boolean {
        val target = canonical.removePrefix("+")
        val digits = StringBuilder()
        var international = false
        var index = 0
        while (index < visible.length) {
            val codePoint = visible.codePointAt(index)
            index += Character.charCount(codePoint)
            when {
                Character.isDigit(codePoint) -> digits.append(Character.digit(codePoint, 10))
                codePoint == '+'.code && digits.isEmpty() -> international = true
                Character.isLetter(codePoint) || codePoint in dialCommands -> break
            }
        }
        val dialed = digits.toString()
        return when {
            international -> target == dialed ||
                (1..3).any { cut -> dialed.getOrNull(cut) == '0' && dialed.removeRange(cut, cut + 1) == target }
            dialed.startsWith("00") -> target == dialed.substring(2)
            else -> {
                val national = dialed.removePrefix("0")
                national.length >= 6 && target.endsWith(national) &&
                    target.length - national.length in 1..3
            }
        }
    }

    private val dialCommands = intArrayOf(','.code, ';'.code, '*'.code, '#'.code)

    /**
     * Soft hyphen, Arabic letter mark, Mongolian vowel separator, zero-width
     * characters, LRM/RLM, bidi embeddings/overrides/isolates, word joiner,
     * invisible operators, deprecated format characters and the BOM.
     */
    private fun isInvisibleFormatting(codePoint: Int): Boolean =
        codePoint == 0x00AD || codePoint == 0x061C || codePoint == 0x180E ||
            codePoint in 0x200B..0x200F || codePoint in 0x202A..0x202E ||
            codePoint in 0x2060..0x2064 || codePoint in 0x2066..0x206F ||
            codePoint == 0xFEFF

    /** Tab, '/' and every Unicode space separator (general category Zs). */
    private fun isSeparatorSpace(codePoint: Int): Boolean =
        codePoint == 0x09 || codePoint == 0x2F || codePoint == 0x00A0 ||
            codePoint == 0x1680 || codePoint in 0x2000..0x200A ||
            codePoint == 0x202F || codePoint == 0x205F || codePoint == 0x3000
}
