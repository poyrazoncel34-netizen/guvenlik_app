import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SILENT-4: _showGraceNotification must have haptic fallback
/// so user is alerted even if notification fails.
void main() {
  test('_showGraceNotification should have HapticFeedback fallback', () {
    final source = File('lib/core/services/check_in_service.dart').readAsStringSync();

    final graceNotifIdx = source.indexOf('_showGraceNotification');
    expect(graceNotifIdx, isNot(-1));

    final methodBody = source.substring(graceNotifIdx, graceNotifIdx + 500);
    expect(methodBody.contains('HapticFeedback'), isTrue,
        reason: 'Must have haptic fallback when notification fails');
  });
}
