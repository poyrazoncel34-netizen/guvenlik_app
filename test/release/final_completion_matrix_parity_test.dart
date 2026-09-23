// The completion matrix is a TRACKING file, and a tracking file that silently
// loses rows is worse than none: a behaviour that vanishes from it looks
// finished instead of unaccounted for.
//
// The 409-row interaction inventory (docs/audit/interaction_inventory_2026-09-22.md)
// is the source. The matrix may add columns, never IDs, and never drop one.
// This test is what makes "409/409 accounted for" a measured statement rather
// than a claim someone typed into a header.
//
// It deliberately does NOT assert any row's status. Status is evidence work;
// pinning it here would turn a red bar into "edit the test" instead of
// "produce the evidence".

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String inventoryPath = 'docs/audit/interaction_inventory_2026-09-22.md';
const String matrixPath = 'docs/release/final_completion_matrix.md';
const int expectedBehaviourCount = 409;

/// Leading cell of a table row, when it is an inventory ID such as `BOOT-01`.
final RegExp _idRow = RegExp(r'^\|\s*([A-ZÇĞİÖŞÜ]{2,8}-\d{2,3})\s*\|');

List<List<String>> _rows(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  final List<List<String>> rows = <List<String>>[];
  for (final String line in file.readAsLinesSync()) {
    if (!_idRow.hasMatch(line)) {
      continue;
    }
    final String body = line.trim().replaceAll(RegExp(r'^\||\|$'), '');
    rows.add(body.split('|').map((String cell) => cell.trim()).toList());
  }
  return rows;
}

Set<String> _ids(List<List<String>> rows) =>
    rows.map((List<String> row) => row.first).toSet();

void main() {
  test('the inventory still carries exactly $expectedBehaviourCount behaviours', () {
    final List<List<String>> rows = _rows(inventoryPath);
    expect(
      rows.length,
      expectedBehaviourCount,
      reason:
          'The baseline inventory must stay at $expectedBehaviourCount rows. '
          'Adding a behaviour means adding it to BOTH files and raising this '
          'number in the same commit.',
    );
    expect(
      _ids(rows).length,
      rows.length,
      reason: 'Duplicate ID in $inventoryPath',
    );
  });

  test('every inventory ID is carried into the completion matrix', () {
    final Set<String> inventory = _ids(_rows(inventoryPath));
    final List<List<String>> matrixRows = _rows(matrixPath);
    final Set<String> matrix = _ids(matrixRows);

    expect(
      matrix.length,
      matrixRows.length,
      reason: 'Duplicate ID in $matrixPath',
    );

    final Set<String> missing = inventory.difference(matrix);
    final Set<String> invented = matrix.difference(inventory);

    expect(
      missing,
      isEmpty,
      reason:
          'These behaviours exist in the inventory but not in the matrix, so '
          'they are being tracked by nobody: ${missing.toList()..sort()}',
    );
    expect(
      invented,
      isEmpty,
      reason:
          'These IDs exist only in the matrix. The matrix does not invent '
          'behaviours; add them to the inventory first: '
          '${invented.toList()..sort()}',
    );
  });

  test('every matrix row is complete and its final status is a known value', () {
    const Set<String> allowedFinalStates = <String>{'KAPANDI', 'ACIK'};
    final List<String> malformed = <String>[];
    final List<String> unknownState = <String>[];

    for (final List<String> row in _rows(matrixPath)) {
      // ID | Yuzey | Mevcut durum | Gereken kanit | Asama | Son kanit | Final
      if (row.length != 7) {
        malformed.add('${row.first} (${row.length} columns)');
        continue;
      }
      if (row.any((String cell) => cell.isEmpty)) {
        malformed.add('${row.first} (empty cell)');
        continue;
      }
      if (!allowedFinalStates.contains(row.last)) {
        unknownState.add('${row.first} -> "${row.last}"');
      }
    }

    expect(malformed, isEmpty, reason: 'Malformed matrix rows: $malformed');
    expect(
      unknownState,
      isEmpty,
      reason:
          'Final status must be one of $allowedFinalStates. A row cannot be '
          'closed by writing a new word into the column: $unknownState',
    );
  });

  test('the matrix header states the count it actually carries', () {
    final String source = File(matrixPath).readAsStringSync();
    final int rows = _rows(matrixPath).length;
    expect(
      source.contains('$rows/$expectedBehaviourCount'),
      isTrue,
      reason:
          'The matrix header must state $rows/$expectedBehaviourCount so the '
          'headline number cannot drift away from the table below it.',
    );
  });
}
