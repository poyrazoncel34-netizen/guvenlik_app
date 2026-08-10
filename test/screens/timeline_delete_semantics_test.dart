import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A delete action that leaves the data readable is not deletion.
///
/// The Safety History merges two stores: user notes in SharedPreferences and
/// recorded safety events in sqflite. Its delete action only reached the notes,
/// so "Sil" on a recorded event removed nothing and the row reappeared on the
/// next reload.
///
/// Two things make that a defect rather than a preference:
///   * Silme Yonetmeligi Md. 8/1 defines silme as making the data "hicbir
///     sekilde erisilemez ve tekrar kullanilamaz" for the relevant users.
///   * legal_texts.dart names a veri sorumlusu and promises the KVKK Md. 11/f
///     deletion right. The app's own policy is the binding statement.
///
/// Deleting is also the low-liability direction: no Turkish rule obliges a
/// private app developer to retain a user's own safety log, while a delete
/// button that does not delete contradicts a published policy.
void main() {
  test('deleting a recorded event reaches the database', () {
    final screen = File(
      'lib/screens/safety_timeline_screen.dart',
    ).readAsStringSync();
    final service = File(
      'lib/core/services/activity_service.dart',
    ).readAsStringSync();

    expect(
      service,
      contains('static Future<void> deleteEvent(String id) async'),
      reason: 'A targeted delete must exist; clearAll() is not a per-entry '
          'deletion path.',
    );
    expect(
      service,
      contains("where: 'id = ?'"),
      reason: 'Parameterised query only (project rule: never interpolate SQL).',
    );
    expect(
      screen,
      contains('ActivityService.deleteEvent(id)'),
      reason: 'The screen must clear the store that actually holds the row.',
    );
  });

  test('the delete menu passes the entry kind so it can route', () {
    final screen = File(
      'lib/screens/safety_timeline_screen.dart',
    ).readAsStringSync();
    expect(
      screen,
      contains("kind: entry['_kind']"),
      reason:
          'Notes and recorded events live in different stores; without the '
          'kind the screen cannot know which one to clear.',
    );
  });

  test('the policy still promises the deletion right it now honours', () {
    final legal = File('lib/constants/legal_texts.dart').readAsStringSync();
    expect(
      legal,
      contains('KVKK Madde 11'),
      reason:
          'If this promise is ever removed, revisit the delete semantics '
          'above rather than letting the two drift apart.',
    );
  });
}
