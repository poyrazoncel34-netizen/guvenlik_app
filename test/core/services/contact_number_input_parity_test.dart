import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/android_intent_service.dart';
import 'package:guvenlik_app/core/utils/emergency_number_validator.dart';

/// Dart half of the shared phone-input boundary table.
///
/// Contact books store numbers with no-break spaces, bidi marks, '/', tabs
/// and fullwidth digits. The strict dispatch validator rejects all of them,
/// so a perfectly real number was reported as "the contact has no number"
/// and could block onboarding. The fix adds ONE sanitizing step at the pick
/// and manual-entry boundary, implemented twice (Dart and Kotlin).
///
/// Both implementations are checked against the SAME fixture file, so two
/// green suites mean two identical verdicts:
///   android/app/src/test/kotlin/com/poyrazoncel/korubeni/emergency/
///       ContactNumberInputParityTest.kt
void main() {
  final fixture = _Fixture.load();

  group('shared vector table', () {
    test('carries at least 25 uniquely named vectors', () {
      expect(fixture.vectors.length, greaterThanOrEqualTo(25));
      final ids = fixture.vectors.map((vector) => vector.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate vector id');
    });

    test('sanitizeContactInput matches the sanitized column', () {
      final mismatches = <String>[
        for (final vector in fixture.vectors)
          if (AndroidIntentService.sanitizeContactInput(vector.input) !=
              vector.sanitized)
            '${vector.id}: want ${_show(vector.sanitized)}, got '
                '${_show(AndroidIntentService.sanitizeContactInput(vector.input))}',
      ];
      expect(mismatches, isEmpty);
    });

    test('the strict dispatch validator is unchanged', () {
      final mismatches = <String>[
        for (final vector in fixture.vectors)
          if (AndroidIntentService.normalizedCallableOrNull(vector.input) !=
              vector.strict)
            '${vector.id}: want ${_show(vector.strict)}, got '
                '${_show(AndroidIntentService.normalizedCallableOrNull(vector.input))}',
      ];
      expect(mismatches, isEmpty);
    });

    test('the pick + manual-entry boundary matches the boundary column', () {
      final mismatches = <String>[
        for (final vector in fixture.vectors)
          if (EmergencyNumberValidator.normalizedContactInputOrNull(
                vector.input,
              ) !=
              vector.boundary)
            '${vector.id}: want ${_show(vector.boundary)}, got '
                '${_show(EmergencyNumberValidator.normalizedContactInputOrNull(vector.input))}',
      ];
      expect(mismatches, isEmpty);
    });
  });

  group('exhaustive BMP sweep', () {
    test('every code point is sanitized exactly as the rule table says', () {
      final mismatches = <String>[];
      for (var codePoint = 0; codePoint <= 0xFFFF; codePoint++) {
        final input = String.fromCharCode(codePoint);
        final actual = AndroidIntentService.sanitizeContactInput(input);
        final expected = fixture.expectedSanitized(codePoint);
        if (actual != expected) {
          mismatches.add(
            'U+${_hex(codePoint)}: want ${_show(expected)}, got ${_show(actual)}',
          );
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason: '${mismatches.length} code points differ from the rule table',
      );
    });

    test('every code point inside a number gets the decision the rules '
        'predict, at both validators', () {
      // A literal character class, not the code under test: the strict
      // validator accepts digits and these separators inside a number.
      bool strictAccepts(String character) =>
          character.length == 1 && '0123456789 ()-.'.contains(character);

      final mismatches = <String>[];
      for (var codePoint = 0; codePoint <= 0xFFFF; codePoint++) {
        final character = String.fromCharCode(codePoint);
        final number = '053212345${character}67';

        final strict = AndroidIntentService.normalizedCallableOrNull(number);
        if ((strict != null) != strictAccepts(character)) {
          mismatches.add('strict U+${_hex(codePoint)}: got ${_show(strict)}');
        }

        final mapped = fixture.expectedSanitized(codePoint);
        final boundaryShouldAccept = mapped.isEmpty || strictAccepts(mapped);
        final boundary = EmergencyNumberValidator.normalizedContactInputOrNull(
          number,
        );
        if ((boundary != null) != boundaryShouldAccept) {
          mismatches.add(
            'boundary U+${_hex(codePoint)}: got ${_show(boundary)}',
          );
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason: '${mismatches.length} decisions differ from the rule table',
      );
    });
  });

  group('stability', () {
    test('sanitizing twice changes nothing', () {
      final inputs = [
        for (final vector in fixture.vectors) vector.input,
        for (var codePoint = 0; codePoint <= 0xFFFF; codePoint++)
          String.fromCharCode(codePoint),
      ];
      final unstable = <String>[
        for (final input in inputs)
          if (AndroidIntentService.sanitizeContactInput(
                AndroidIntentService.sanitizeContactInput(input),
              ) !=
              AndroidIntentService.sanitizeContactInput(input))
            _show(input),
      ];
      expect(unstable, isEmpty);
    });

    test('a canonical boundary result is a fixed point', () {
      for (final vector in fixture.vectors) {
        final canonical = vector.boundary;
        if (canonical == null) continue;
        expect(
          EmergencyNumberValidator.normalizedContactInputOrNull(canonical),
          canonical,
          reason: vector.id,
        );
        expect(
          AndroidIntentService.normalizedCallableOrNull(canonical),
          canonical,
          reason:
              '${vector.id}: what the boundary stores, dispatch must accept',
        );
      }
    });
  });
}

const String _fixturePath =
    'test/core/services/contact_number_input_vectors.txt';

class _Vector {
  const _Vector(
    this.id,
    this.input,
    this.sanitized,
    this.strict,
    this.boundary,
  );

  final String id;
  final String input;
  final String sanitized;
  final String? strict;
  final String? boundary;
}

enum _RuleKind { delete, space, fold }

class _Rule {
  const _Rule(this.kind, this.first, this.last);

  final _RuleKind kind;
  final int first;
  final int last;
}

class _Fixture {
  const _Fixture(this.vectors, this.rules);

  final List<_Vector> vectors;
  final List<_Rule> rules;

  /// What the rule table says [codePoint] becomes, derived from the fixture
  /// alone -- never from the sanitizer under test.
  String expectedSanitized(int codePoint) {
    for (final rule in rules) {
      if (codePoint < rule.first || codePoint > rule.last) continue;
      switch (rule.kind) {
        case _RuleKind.delete:
          return '';
        case _RuleKind.space:
          return ' ';
        case _RuleKind.fold:
          final ascii = String.fromCharCode(codePoint - 0xFEE0);
          return ascii == '/' ? ' ' : ascii;
      }
    }
    return String.fromCharCode(codePoint);
  }

  static _Fixture load() {
    final root = Directory.current.path.endsWith('test')
        ? Directory.current.parent.path
        : Directory.current.path;
    final lines = File('$root/$_fixturePath').readAsLinesSync();
    final vectors = <_Vector>[];
    final rules = <_Rule>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final where = '$_fixturePath:${index + 1}';
      if (line.codeUnits.any((unit) => unit < 0x20 || unit > 0x7E)) {
        throw StateError('$where: fixture must be printable ASCII');
      }
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (trimmed.startsWith('@')) {
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length != 2) throw StateError('$where: bad rule');
        final kind = switch (parts[0]) {
          '@delete' => _RuleKind.delete,
          '@space' => _RuleKind.space,
          '@fold' => _RuleKind.fold,
          _ => throw StateError('$where: unknown rule ${parts[0]}'),
        };
        final bounds = parts[1].split('-');
        final first = int.parse(bounds.first, radix: 16);
        final last = int.parse(bounds.last, radix: 16);
        rules.add(_Rule(kind, first, last));
        continue;
      }

      final fields = trimmed.split(' | ').map((f) => f.trim()).toList();
      if (fields.length != 5) {
        throw StateError('$where: want 5 fields, got ${fields.length}');
      }
      vectors.add(
        _Vector(
          fields[0],
          _unescape(fields[1], where),
          _unescape(fields[2], where),
          _verdict(fields[3], where),
          _verdict(fields[4], where),
        ),
      );
    }
    return _Fixture(vectors, rules);
  }

  static String? _verdict(String field, String where) =>
      field == 'REJECT' ? null : _unescape(field, where);

  static String _unescape(String field, String where) {
    final out = StringBuffer();
    var index = 0;
    while (index < field.length) {
      final character = field[index];
      if (character != r'\') {
        out.write(character);
        index++;
        continue;
      }
      if (index + 6 > field.length || field[index + 1] != 'u') {
        throw StateError('$where: only \\uXXXX escapes are allowed');
      }
      out.writeCharCode(
        int.parse(field.substring(index + 2, index + 6), radix: 16),
      );
      index += 6;
    }
    return out.toString();
  }
}

String _hex(int value) => value.toRadixString(16).toUpperCase().padLeft(4, '0');

/// Renders a verdict with every non-printable-ASCII code unit escaped, so a
/// failure message shows the invisible character that caused it.
String _show(String? value) {
  if (value == null) return 'REJECT';
  final out = StringBuffer('"');
  for (final unit in value.codeUnits) {
    if (unit >= 0x20 && unit <= 0x7E) {
      out.writeCharCode(unit);
    } else {
      out.write('\\u${_hex(unit)}');
    }
  }
  out.write('"');
  return out.toString();
}
