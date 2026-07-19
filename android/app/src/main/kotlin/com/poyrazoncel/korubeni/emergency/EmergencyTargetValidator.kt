package com.poyrazoncel.korubeni.emergency

/**
 * The only native boundary for normalizing and validating a configured call
 * target. This object performs no side effects and owns no dispatch state.
 */
object EmergencyTargetValidator {
    private val safeFormattingCharacters = setOf(' ', '-', '(', ')', '.')

    fun normalize(raw: String): String {
        // Kotlin Char.isDigit() accepts Unicode numerals. Telecom targets are
        // deliberately restricted to ASCII digits plus one leading '+'.
        val stripped = raw.trim().filter { it in '0'..'9' || it == '+' }
        if (stripped.isEmpty()) return ""
        return if (stripped.first() == '+') {
            "+" + stripped.drop(1).filter { it in '0'..'9' }
        } else {
            stripped.filter { it in '0'..'9' }
        }
    }

    fun normalizedCallableOrNull(raw: String): String? {
        if (!hasSafeConfiguredTargetSyntax(raw)) return null
        val normalized = normalize(raw)
        val digits = if (normalized.startsWith('+')) normalized.drop(1) else normalized
        return normalized.takeIf {
            digits.length in 7..15 && digits.all { digit -> digit in '0'..'9' }
        }
    }

    fun isCallable(raw: String): Boolean = normalizedCallableOrNull(raw) != null

    /**
     * Accept only a configured phone number, never a URI, dial-string command,
     * extension, pause/wait sequence, or control-character-bearing payload.
     *
     * Formatting characters are accepted for contact-book compatibility. A
     * single '+' is accepted only before the first ASCII digit. Normalization
     * remains a presentation/storage operation; it must not turn hostile input
     * into an otherwise-callable number.
     */
    private fun hasSafeConfiguredTargetSyntax(raw: String): Boolean {
        var sawDigit = false
        var sawPlus = false

        raw.forEach { character ->
            when {
                character in '0'..'9' -> sawDigit = true
                character == '+' -> {
                    if (sawDigit || sawPlus) return false
                    sawPlus = true
                }
                character in safeFormattingCharacters -> Unit
                else -> return false
            }
        }
        return true
    }
}
