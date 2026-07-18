package com.poyrazoncel.korubeni.emergency

/**
 * The only native boundary for normalizing and validating a configured call
 * target. This object performs no side effects and owns no dispatch state.
 */
object EmergencyTargetValidator {
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

    fun isCallable(raw: String): Boolean {
        val normalized = normalize(raw)
        val digits = if (normalized.startsWith('+')) normalized.drop(1) else normalized
        return digits.length in 7..15 && digits.all { it in '0'..'9' }
    }
}
