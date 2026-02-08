// ============================================================================
// CRASHLYTICS TEST HELPER (Sadece debug/test için)
// ============================================================================
// Production build'da bu fonksiyonlar çağrılmamalı.
// Test: Debug menüden veya geliştirme sırasında Crashlytics'in çalıştığını doğrulayın.
// ============================================================================

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashlyticsTestHelper {
  CrashlyticsTestHelper._();

  /// Test exception'ı Crashlytics'e gönderir (force crash YAPMAZ).
  /// Firebase Console > Crashlytics'te "Non-fatal" olarak görünür.
  static Future<void> recordTestError() async {
    if (kReleaseMode) return;
    try {
      throw Exception('Crashlytics test exception - ignore in production');
    } catch (e, stack) {
      await FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
    }
  }

  /// Uygulamayı bilerek çökertir. SADECE DEBUG - production'da çağırılmamalı.
  /// Crashlytics'in crash raporunu yakaladığını doğrulamak için kullanın.
  static void forceTestCrash() {
    if (kReleaseMode) return;
    FirebaseCrashlytics.instance.crash();
  }

  /// Özel log / analytics event testi.
  static Future<void> logTestEvent() async {
    if (kReleaseMode) return;
    await FirebaseCrashlytics.instance.log(
      'Test log from CrashlyticsTestHelper',
    );
  }
}
