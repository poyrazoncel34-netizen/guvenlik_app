import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Finding 3 (HIGH): paid Safety History was a notes-only timeline that
/// silently missed real safety events (panic, fake call, siren, safe walk,
/// check-in). This contract test enforces that the unified timeline reads
/// from ActivityService and that the empty state copy is honest.
void main() {
  test('SafetyTimelineScreen merges ActivityService events with notes', () {
    final source = File(
      'lib/screens/safety_timeline_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('ActivityService.getEvents'),
      isTrue,
      reason:
          'safety_timeline_screen.dart must read real safety events from '
          'ActivityService so paid Safety History is truthful.',
    );
  });

  test('timeline empty-state copy is honest about activity (not notes)', () {
    final tr = File('assets/translations/tr-TR.json').readAsStringSync();
    final en = File('assets/translations/en-US.json').readAsStringSync();
    expect(
      tr.contains('Henüz güvenlik etkinliği yok'),
      isTrue,
      reason:
          'TR timeline_empty must read "Henüz güvenlik etkinliği yok." per '
          'Finding 3 spec.',
    );
    expect(
      en.contains('No safety activity yet'),
      isTrue,
      reason:
          'EN timeline_empty must read "No safety activity yet." per '
          'Finding 3 spec.',
    );
  });
}
