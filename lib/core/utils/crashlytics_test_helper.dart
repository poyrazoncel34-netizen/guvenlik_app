// ============================================================================
// Crash-reporting SDK removed - offline-first app.
// Compatibility shim for older debug/test call sites; no remote logging occurs.
// ============================================================================

import 'package:flutter/foundation.dart';

class CrashlyticsTestHelper {
  CrashlyticsTestHelper._();

  static Future<void> recordTestError() async {
    if (kReleaseMode) return;
    debugPrint('Crash reporting removed - offline-first app');
  }

  static void forceTestCrash() {
    if (kReleaseMode) return;
    debugPrint('Crash reporting removed - no forced crash');
  }

  static Future<void> logTestEvent() async {
    if (kReleaseMode) return;
    debugPrint('Crash reporting removed - no remote log');
  }
}
