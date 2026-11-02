package com.poyrazoncel.korubeni.emergency

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Kotlin half of the shared phone-input boundary table.
 *
 * Contact books store numbers with no-break spaces, bidi marks, '/', tabs and
 * fullwidth digits. The strict validator rejected all of them, so the picker
 * reported "no number" for a real number. The pick and manual-entry boundary
 * now sanitizes first, in Dart AND here.
 *
 * This test and test/core/services/contact_number_input_parity_test.dart read
 * the SAME fixture file, so two green suites mean two identical verdicts.
 */
class ContactNumberInputParityTest {
    private val fixture = SharedFixture.load()

    @Test
    fun `the shared table carries at least 25 uniquely named vectors`() {
        assertTrue("only ${fixture.vectors.size} vectors", fixture.vectors.size >= 25)
        assertEquals(
            "duplicate vector id",
            fixture.vectors.size,
            fixture.vectors.map { it.id }.toSet().size,
        )
    }

    @Test
    fun `sanitizeContactInput matches the sanitized column`() {
        val mismatches = fixture.vectors.mapNotNull { vector ->
            val actual = ContactInputBoundary.sanitizeContactInput(vector.input)
            if (actual == vector.sanitized) null
            else "${vector.id}: want ${show(vector.sanitized)}, got ${show(actual)}"
        }
        assertEquals("sanitized column", emptyList<String>(), mismatches)
    }

    @Test
    fun `the strict dispatch validator is unchanged`() {
        val mismatches = fixture.vectors.mapNotNull { vector ->
            val actual = EmergencyTargetValidator.normalizedCallableOrNull(vector.input)
            if (actual == vector.strict) null
            else "${vector.id}: want ${show(vector.strict)}, got ${show(actual)}"
        }
        assertEquals("strict column", emptyList<String>(), mismatches)
    }

    @Test
    fun `the pick and manual entry boundary matches the boundary column`() {
        val mismatches = fixture.vectors.mapNotNull { vector ->
            val actual = ContactInputBoundary.normalizedContactInputOrNull(vector.input)
            if (actual == vector.boundary) null
            else "${vector.id}: want ${show(vector.boundary)}, got ${show(actual)}"
        }
        assertEquals("boundary column", emptyList<String>(), mismatches)
    }

    @Test
    fun `every BMP code point is sanitized exactly as the rule table says`() {
        val mismatches = mutableListOf<String>()
        for (codePoint in 0..0xFFFF) {
            val actual = ContactInputBoundary.sanitizeContactInput(Char(codePoint).toString())
            val expected = fixture.expectedSanitized(codePoint)
            if (actual != expected) {
                mismatches += "U+${hex(codePoint)}: want ${show(expected)}, got ${show(actual)}"
            }
        }
        assertEquals(
            "${mismatches.size} code points differ from the rule table (first 40 shown)",
            emptyList<String>(),
            mismatches.take(40),
        )
    }

    @Test
    fun `every code point inside a number gets the decision the rules predict at both validators`() {
        // A literal character class, not the code under test: the strict
        // validator accepts digits and these separators inside a number.
        fun strictAccepts(character: String) =
            character.length == 1 && character[0] in "0123456789 ()-."

        val mismatches = mutableListOf<String>()
        for (codePoint in 0..0xFFFF) {
            val character = Char(codePoint).toString()
            val number = "053212345${character}67"

            val strict = EmergencyTargetValidator.normalizedCallableOrNull(number)
            if ((strict != null) != strictAccepts(character)) {
                mismatches += "strict U+${hex(codePoint)}: got ${show(strict)}"
            }

            val mapped = fixture.expectedSanitized(codePoint)
            val boundaryShouldAccept = mapped.isEmpty() || strictAccepts(mapped)
            val boundary = ContactInputBoundary.normalizedContactInputOrNull(number)
            if ((boundary != null) != boundaryShouldAccept) {
                mismatches += "boundary U+${hex(codePoint)}: got ${show(boundary)}"
            }
        }
        assertEquals(
            "${mismatches.size} decisions differ from the rule table (first 40 shown)",
            emptyList<String>(),
            mismatches.take(40),
        )
    }

    @Test
    fun `sanitizing twice changes nothing`() {
        val inputs = fixture.vectors.map { it.input } + (0..0xFFFF).map { Char(it).toString() }
        val unstable = inputs.filter { input ->
            val once = ContactInputBoundary.sanitizeContactInput(input)
            ContactInputBoundary.sanitizeContactInput(once) != once
        }
        assertEquals(emptyList<String>(), unstable.map { show(it) })
    }

    @Test
    fun `a canonical boundary result is a fixed point`() {
        fixture.vectors.forEach { vector ->
            val canonical = vector.boundary ?: return@forEach
            assertEquals(
                vector.id,
                canonical,
                ContactInputBoundary.normalizedContactInputOrNull(canonical),
            )
            assertEquals(
                "${vector.id}: what the boundary stores, dispatch must accept",
                canonical,
                EmergencyTargetValidator.normalizedCallableOrNull(canonical),
            )
        }
    }
}

private data class SharedVector(
    val id: String,
    val input: String,
    val sanitized: String,
    val strict: String?,
    val boundary: String?,
)

private enum class SharedRuleKind { DELETE, SPACE, FOLD }

private data class SharedRule(val kind: SharedRuleKind, val first: Int, val last: Int)

private class SharedFixture(val vectors: List<SharedVector>, val rules: List<SharedRule>) {
    /**
     * What the rule table says [codePoint] becomes, derived from the fixture
     * alone -- never from the sanitizer under test.
     */
    fun expectedSanitized(codePoint: Int): String {
        val rule = rules.firstOrNull { codePoint in it.first..it.last }
            ?: return Char(codePoint).toString()
        return when (rule.kind) {
            SharedRuleKind.DELETE -> ""
            SharedRuleKind.SPACE -> " "
            SharedRuleKind.FOLD -> Char(codePoint - 0xFEE0).toString().let { if (it == "/") " " else it }
        }
    }

    companion object {
        private const val PATH = "test/core/services/contact_number_input_vectors.txt"

        fun load(): SharedFixture {
            val lines = File(repoRoot(), PATH).readLines()
            val vectors = mutableListOf<SharedVector>()
            val rules = mutableListOf<SharedRule>()

            lines.forEachIndexed { index, line ->
                val where = "$PATH:${index + 1}"
                require(line.all { it.code in 0x20..0x7E }) { "$where: fixture must be printable ASCII" }
                val trimmed = line.trim()
                if (trimmed.isEmpty() || trimmed.startsWith("#")) return@forEachIndexed

                if (trimmed.startsWith("@")) {
                    val parts = trimmed.split(Regex("\\s+"))
                    require(parts.size == 2) { "$where: bad rule" }
                    val kind = when (parts[0]) {
                        "@delete" -> SharedRuleKind.DELETE
                        "@space" -> SharedRuleKind.SPACE
                        "@fold" -> SharedRuleKind.FOLD
                        else -> error("$where: unknown rule ${parts[0]}")
                    }
                    val bounds = parts[1].split("-")
                    rules += SharedRule(kind, bounds.first().toInt(16), bounds.last().toInt(16))
                    return@forEachIndexed
                }

                val fields = trimmed.split(" | ").map { it.trim() }
                require(fields.size == 5) { "$where: want 5 fields, got ${fields.size}" }
                vectors += SharedVector(
                    id = fields[0],
                    input = unescape(fields[1], where),
                    sanitized = unescape(fields[2], where),
                    strict = verdict(fields[3], where),
                    boundary = verdict(fields[4], where),
                )
            }
            return SharedFixture(vectors, rules)
        }

        /** The fixture lives in the Flutter tree; walk up to the pubspec. */
        private fun repoRoot(): File {
            var dir: File? = File(System.getProperty("user.dir")).absoluteFile
            while (dir != null) {
                if (File(dir, "pubspec.yaml").isFile) return dir
                dir = dir.parentFile
            }
            error("pubspec.yaml not found above ${System.getProperty("user.dir")}")
        }

        private fun verdict(field: String, where: String): String? =
            if (field == "REJECT") null else unescape(field, where)

        private fun unescape(field: String, where: String): String {
            val out = StringBuilder()
            var index = 0
            while (index < field.length) {
                val character = field[index]
                if (character != '\\') {
                    out.append(character)
                    index++
                    continue
                }
                require(index + 6 <= field.length && field[index + 1] == 'u') {
                    "$where: only \\uXXXX escapes are allowed"
                }
                out.append(Char(field.substring(index + 2, index + 6).toInt(16)))
                index += 6
            }
            return out.toString()
        }
    }
}

private fun hex(value: Int): String = "%04X".format(value)

/**
 * Renders a verdict with every non-printable-ASCII code unit escaped, so a
 * failure message shows the invisible character that caused it.
 */
private fun show(value: String?): String {
    if (value == null) return "REJECT"
    return buildString {
        append('"')
        value.forEach { unit ->
            if (unit.code in 0x20..0x7E) append(unit) else append("\\u%04X".format(unit.code))
        }
        append('"')
    }
}
