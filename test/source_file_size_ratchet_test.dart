import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratchet for the 800-line-per-file project limit.
///
/// Three service files crossed the limit without being recorded as accepted
/// debt, and two known-oversized screens kept growing. Splitting emergency-path
/// services is a deliberate refactor with its own coverage evidence, not a
/// drive-by change — so this test does not demand the split. It freezes the
/// current sizes so the drift cannot continue silently, and forces a conscious
/// decision the next time one of these files needs to grow.
///
/// Rules:
///   * a file not listed below must stay at or under [limit];
///   * a listed file must stay at or under its recorded size;
///   * a listed file that drops to [limit] or below must leave the list, so the
///     ledger records real progress instead of stale permission.
void main() {
  const limit = 800;

  // Baseline recorded 2026-07-23 from the COMMITTED tree (git HEAD), which is
  // what CI checks out. Do not record numbers measured against a dirty working
  // tree: uncommitted work-in-progress can inflate a file well past its
  // committed size, and baking those inflated numbers in here would
  // pre-authorise exactly the growth this ratchet exists to catch.
  //
  // Consequence: while local WIP grows one of these files, this test goes red
  // on the working tree. That is the ratchet reporting real drift, not a bug —
  // trim the file or make updating this ledger a conscious part of the commit.
  const acceptedOversize = <String, int>{
    'lib/screens/home_page.dart': 1276,
    'lib/screens/countdown_screen.dart': 1228,
    'lib/screens/contacts_page.dart': 1185,
    'lib/screens/map_page.dart': 885,
    'lib/core/services/emergency_platform_service.dart': 867,
    'lib/core/services/contact_service.dart': 810,
  };

  int lineCount(File file) => file.readAsLinesSync().length;

  test('no unlisted Dart source file exceeds the 800-line limit', () {
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;
      if (acceptedOversize.containsKey(path)) continue;
      final lines = lineCount(entity);
      if (lines > limit) {
        violations.add('$path ($lines lines)');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Extract logic into lib/core/services/ instead of growing a file past '
          '$limit lines. Adding the file to acceptedOversize is a deliberate '
          'debt decision, not the default fix.',
    );
  });

  test('accepted oversize files do not grow further', () {
    final grown = <String>[];

    for (final entry in acceptedOversize.entries) {
      final file = File(entry.key);
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '${entry.key} is listed as accepted debt but no longer exists; '
            'remove the stale entry.',
      );
      final lines = lineCount(file);
      if (lines > entry.value) {
        grown.add('${entry.key}: ${entry.value} -> $lines');
      }
    }

    expect(
      grown,
      isEmpty,
      reason:
          'These files are already over the project limit and must shrink, not '
          'grow. Move the new logic into a focused service under '
          'lib/core/services/.',
    );
  });

  test('accepted oversize list contains no file that is back under the limit', () {
    final resolved = <String>[];

    for (final entry in acceptedOversize.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) continue;
      final lines = lineCount(file);
      if (lines <= limit) {
        resolved.add('${entry.key} ($lines lines)');
      }
    }

    expect(
      resolved,
      isEmpty,
      reason:
          'These files now satisfy the $limit-line limit. Remove them from '
          'acceptedOversize so the debt ledger stays truthful.',
    );
  });
}
