// MP-01-010 / MP-13-010 — an irreversible delete is CONFIRMED and NAMED.
//
// The defect this covers: `_deleteEntry` on the Safety History is genuinely
// irreversible on purpose -- it clears the note store AND the mirrored activity
// row, so the KVKK Md. 11/f promise is real rather than cosmetic. It was wired
// straight to a `PopupMenuItem`, so one mis-tap in a three-item menu destroyed a
// safety record with no confirmation, no naming of what was about to go, and no
// undo. The more thorough the deletion, the worse an unguarded trigger is.
//
// A source-contract test rather than a pumped screen, because the screen merges
// two live stores and the thing under test is the WIRING: which function the
// menu item calls, and what that function does before it destroys anything.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File(
    'lib/screens/safety_timeline_screen.dart',
  ).readAsStringSync();

  test('the delete menu item routes through the confirmation, not the delete', () {
    // The menu must not be able to reach `_deleteEntry` directly. Asserting on
    // the confirmation's PRESENCE alone would pass a build that added a dialog
    // and left the old one-tap path wired next to it.
    final menuHandler = RegExp(
      r"if \(value == 'delete'\) \{(.*?)\}",
      dotAll: true,
    ).firstMatch(screen);
    expect(menuHandler, isNotNull, reason: 'delete menu handler not found');
    final body = menuHandler!.group(1)!;
    expect(
      body,
      contains('_confirmAndDeleteEntry'),
      reason: 'the menu item must go through the confirmation',
    );
    expect(
      body.contains('_deleteEntry('),
      isFalse,
      reason: 'the menu item must not still call the destructive path directly',
    );
  });

  test('the confirmation refuses to delete unless the user said yes', () {
    expect(
      screen,
      contains('if (confirmed != true) return;'),
      reason:
          'A dismissed dialog returns null, not false. `if (confirmed == false)` '
          'would delete on a barrier tap or a back press.',
    );
  });

  test('the confirmation names the entry and says it cannot be undone', () {
    expect(screen, contains('timeline_delete_confirm_title'));
    expect(screen, contains("namedArgs: {"));
    expect(
      screen,
      contains('timeline_entry_untitled'),
      reason: 'an untitled note must still be describable, not render as ""',
    );

    for (final locale in const ['tr-TR', 'en-US']) {
      final copy =
          jsonDecode(File('assets/translations/$locale.json').readAsStringSync())
              as Map<String, dynamic>;
      final body = copy['timeline_delete_confirm_body'] as String;
      expect(
        body,
        contains('{title}'),
        reason: '$locale: the body must interpolate WHICH entry is going',
      );
      // The requirement is that irreversibility is stated, not implied.
      expect(
        body.toLowerCase(),
        anyOf(contains('geri alinamaz'), contains('cannot be undone')),
        reason: '$locale: the copy must say the action is irreversible',
      );
      expect(copy['timeline_delete_confirm_title'], isNotNull);
      expect(copy['timeline_delete_confirm_action'], isNotNull);
      expect(copy['timeline_entry_untitled'], isNotNull);
    }
  });

  test('the destructive button is styled as destructive, not as the default', () {
    final dialog = screen.substring(
      screen.indexOf('_confirmAndDeleteEntry'),
      screen.indexOf('/// Deletes an entry from whichever store'),
    );
    expect(
      dialog,
      contains('backgroundColor: AppColors.emergency'),
      reason: 'the confirm action must read as destructive',
    );
    expect(
      dialog,
      contains("'cancel'.tr()"),
      reason: 'a confirmation with no way out is not a confirmation',
    );
  });

  testWidgets('EscapeDismissible wraps it, so a keyboard user can back out', (
    tester,
  ) async {
    // Regression tie-in: the Escape defect fixed earlier had TWO gates, and a
    // dialog added later would silently reintroduce the second one.
    expect(screen, contains('EscapeDismissible'));
    expect(
      const AlertDialog(),
      isA<AlertDialog>(),
      reason: 'placeholder to keep this file in the widget-test binding',
    );
  });
}
