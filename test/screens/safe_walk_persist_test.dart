import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// E3: All calls to _clearPersistedState() in safe_walk_screen must be awaited.
/// Unawaited async calls may not complete before app termination, leaving
/// stale state that causes incorrect behavior on next launch.
void main() {
  test('safe_walk_screen should await all _clearPersistedState calls', () {
    final source = File(
      'lib/screens/safe_walk_screen.dart',
    ).readAsStringSync();

    // Find all _clearPersistedState() call sites (excluding the definition)
    final callPattern = RegExp(r'(\w+\s+)?_clearPersistedState\(\)');
    final matches = callPattern.allMatches(source).toList();

    for (final match in matches) {
      final line = source.substring(
        source.lastIndexOf('\n', match.start) + 1,
        source.indexOf('\n', match.end),
      ).trim();

      // Skip the method definition line
      if (line.contains('Future<void>') || line.contains('async')) continue;

      expect(
        line.startsWith('await') || line.contains('await _clearPersistedState'),
        isTrue,
        reason:
            'All _clearPersistedState() calls must be awaited. '
            'Found unawaited call: "$line"',
      );
    }
  });
}
