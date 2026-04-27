// Verify that feature warning dialogs disclose that features auto-restart
// after device boot. RECEIVE_BOOT_COMPLETED behavior must be transparent.
//
// The disclosure copy lives in `assets/translations/tr-TR.json` under the
// `feature_warning_checkin_content` key (the dialog now pulls localized
// strings via easy_localization). The test reads the JSON directly so the
// boot-restart guarantee is enforced regardless of which Dart file consumes
// the key.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Boot auto-restart disclosure', () {
    test('check-in warning mentions auto-restart after reboot (TR)', () {
      final json =
          jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
              as Map<String, dynamic>;
      final content = json['feature_warning_checkin_content'] as String?;

      expect(
        content,
        isNotNull,
        reason:
            'feature_warning_checkin_content key must exist in tr-TR.json '
            '— the check-in dialog reads this value at runtime.',
      );
      expect(
        content,
        contains('yeniden başlat'),
        reason:
            'Check-in feature warning must disclose that the timer '
            'auto-restarts after device reboot (RECEIVE_BOOT_COMPLETED).',
      );
    });
  });
}
