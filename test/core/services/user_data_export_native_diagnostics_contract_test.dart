import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'user-controlled data export includes redacted native safety events',
    () {
      final source = File(
        'lib/core/services/user_data_export_service.dart',
      ).readAsStringSync();

      expect(source, contains("'nativeSafetyDiagnostics'"));
      expect(source, contains('readNativeSafetyDiagnostics()'));
      expect(
        source,
        isNot(contains('readNativeSafetyDiagnosticsRaw')),
        reason: 'Export must use the strict allowlisted platform projection.',
      );
    },
  );
}
