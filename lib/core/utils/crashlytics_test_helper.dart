// ============================================================================
// Crashlytics removed - offline-first app. Stub for backward compatibility.
// ============================================================================

import 'package:flutter/foundation.dart';

class CrashlyticsTestHelper {
  CrashlyticsTestHelper._();

  static Future<void> recordTestError() async {
    if (kReleaseMode) return;
    debugPrint('Crashlytics removed - offline app');
  }

  static void forceTestCrash() {
    if (kReleaseMode) return;
    debugPrint('Crashlytics removed - no crash');
  }

  static Future<void> logTestEvent() async {
    if (kReleaseMode) return;
    debugPrint('Crashlytics removed - no log');
  }
}
