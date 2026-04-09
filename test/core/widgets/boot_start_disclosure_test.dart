// Verify that feature warning dialogs disclose that features auto-restart
// after device boot. RECEIVE_BOOT_COMPLETED behavior must be transparent.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Boot auto-restart disclosure', () {
    test('check-in warning mentions auto-restart after reboot', () {
      final content = File('lib/core/widgets/feature_warning_dialog.dart')
          .readAsStringSync();

      // The check-in feature auto-restarts after boot via BootCompletedReceiver
      expect(
        content,
        contains('yeniden başlat'),
        reason:
            'Check-in feature warning must disclose that the timer '
            'auto-restarts after device reboot (RECEIVE_BOOT_COMPLETED)',
      );
    });
  });
}
