import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SILENT-2: EmergencyExecutor must persist a flag to SharedPreferences
/// so Flutter can check if native dispatch was attempted on next resume.
void main() {
  test('EmergencyExecutor should persist dispatch-attempted flag', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyExecutor.kt',
    ).readAsStringSync();

    expect(source.contains('nativeDispatchAttempted'), isTrue,
        reason: 'Must persist dispatch-attempted flag for Flutter to check');
  });
}
