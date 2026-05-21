import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S1: EmergencyEventBus must use commit() not apply() for emergency trigger
/// persistence. apply() is async and can lose data if process is killed before
/// disk flush — unacceptable for life-critical emergency triggers.
void main() {
  test(
    'EmergencyEventBus should use commit() instead of apply() for persistence',
    () {
      final source = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyEventBus.kt',
      ).readAsStringSync();

      // .apply() is async and can lose emergency trigger data on process kill
      expect(
        source.contains('.apply()'),
        isFalse,
        reason:
            'EmergencyEventBus must use .commit() for synchronous persistence '
            'of emergency triggers — .apply() risks data loss on crash',
      );

      // Verify commit() is actually used
      expect(
        source.contains('.commit()'),
        isTrue,
        reason:
            'EmergencyEventBus must use .commit() for emergency state persistence',
      );
    },
  );
}
