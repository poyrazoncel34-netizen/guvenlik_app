import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The reset dialog's PIN prompt used to read the stored PIN record and compare
/// it to the four digits the user typed. What is on disk is a salted PBKDF2
/// hash, so the correct PIN was always rejected and the in-app "delete my data"
/// path was unreachable for every user whose PIN was written by a current build.
///
/// The same helper also migrated a legacy plaintext PIN into secure storage
/// WITHOUT hashing it, which then made PinHasher.matches reject that record on
/// the main unlock screen too -- a full lockout, not just a broken dialog.
///
/// These are source assertions, not behaviour: they cannot prove verification
/// succeeds, only that the helper no longer owns a second PIN-reading path.
/// The behavioural guarantee lives in PinVerificationService's own tests.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/core/utils/app_reset_helper.dart').readAsStringSync();
  });

  test('verification is delegated to PinVerificationService', () {
    expect(
      source,
      contains('PinVerificationService.instance.verify('),
      reason:
          'Only PinVerificationService knows the stored record format. A local '
          'comparison against the typed digits can never match a PBKDF2 hash.',
    );
  });

  test('the helper never reads or writes the PIN record itself', () {
    expect(
      source.contains('SecureStorageKeys.userPin'),
      isFalse,
      reason:
          'A second read path is how the literal comparison appeared. The '
          'helper must ask the service for a decision, not for the record.',
    );
    expect(
      source.contains('SharedPreferences'),
      isFalse,
      reason:
          'The legacy-plaintext migration lived here and wrote the raw PIN '
          'into secure storage unhashed. Migration belongs to the service.',
    );
  });

  test('an unreadable PIN fails closed instead of allowing the wipe', () {
    expect(
      source,
      contains('PinState.absent'),
      reason: 'Only a genuinely absent PIN may skip verification.',
    );
    expect(
      source,
      contains('if (pinState != PinState.configured) {'),
      reason:
          'readFailed must not be treated as "no PIN configured": that would '
          'let a keystore fault open a destructive wipe.',
    );
  });
}
