// ============================================================================
// KORUBENI - GUVENLIK UYGULAMASI
// ============================================================================

import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/di/service_locator.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/navigation/app_navigator.dart';
import 'presentation/providers/providers.dart';
import 'screens/splash_screen.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/crash_log_service.dart';
import 'core/services/data_migration_service.dart';
import 'core/services/foreground_service.dart';
import 'core/services/haptic_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/atomic_storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/widgets/emergency_trigger_host.dart';
import 'core/widgets/app_privacy_shield.dart';
import 'core/services/local_logger_service.dart';
import 'core/widgets/offline_banner.dart';
import 'core/services/revenue_cat_service.dart';
import 'core/constants/feature_access_matrix.dart';
import 'core/config/app_environment.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment.validateReleaseConfiguration(isReleaseMode: kReleaseMode);
  await EasyLocalization.ensureInitialized();

  // Dil seçimi kaldırıldı — eski persisted non-Turkish locale'i temizle
  // böylece startLocale: tr_TR her zaman geçerli olur.
  final prefs = await SharedPreferences.getInstance();
  final storedLocale = prefs.getString('locale');
  if (storedLocale != null && storedLocale != 'tr_TR') {
    await prefs.remove('locale');
  }

  // 0) ErrorWidget.builder MUST be set BEFORE runApp so ANY error is caught
  ErrorWidget.builder = (FlutterErrorDetails details) {
    assert(() {
      debugPrint('ErrorWidget caught: ${details.exception}');
      return true;
    }());
    final errorTitle = 'error_title'.tr();
    final errorRestart = 'error_restart'.tr();
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0A1B2A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                Text(
                  errorTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  kReleaseMode
                      ? 'app_error_fallback_body'.tr()
                      : (details.exception.toString().length > 200
                            ? details.exception.toString().substring(0, 200)
                            : details.exception.toString()),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(
                  errorRestart,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // OPTIMIZED COLD START: Run independent services in parallel
  // Web: Skip NotificationService & ForegroundService (platform plugins don't support web)
  try {
    await setupServiceLocator();
    FeatureAccessMatrix.debugPrintMatrix();

    final services = <Future<void>>[
      DataMigrationService.migrate(),
      OfflineQueueService.instance.initialize(),
      AtomicStorageService.instance.checkIntegrity(),
      HapticService.initialize(),
      ConnectivityService.instance.initialize(),
      LocalLoggerService.instance.initialize(),
    ];
    if (!kIsWeb) {
      services.add(NotificationService.instance.initialize());
      services.add(KoruBeniForegroundService.configure());
      services.add(serviceLocator<RevenueCatService>().initialize());
    }
    await Future.wait(services);
  } catch (e) {
    // Non-fatal - app continues
  }

  // Error handling for Flutter errors — local device-only crash log.
  FlutterError.onError = (details) {
    CrashLogService.instance.record(
      source: 'flutter_error',
      error: details.exception,
      stackTrace: details.stack,
    );
    LocalLoggerService.instance.error(
      'FlutterError',
      details.exception,
      details.stack,
    );
    assert(() {
      debugPrint('FlutterError: ${details.exception}');
      return true;
    }());
    // Forward to the framework's default presenter so the error is
    // also written to Logcat / stderr in release builds. This is
    // required for Google Play Pre-launch Report to surface Flutter
    // framework errors (build/widget exceptions); without it, only
    // native crashes appear in the report and Dart-side bugs stay
    // invisible to automated QA crawlers.
    FlutterError.presentError(details);
  };

  // Zero-fault: Fatal hataları yutma - return false ile standart hata yönetimine bırak
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashLogService.instance.record(
      source: 'platform_dispatcher',
      error: error,
      stackTrace: stack,
    );
    LocalLoggerService.instance.error('PlatformDispatcher', error, stack);
    assert(() {
      debugPrint('PlatformDispatcher.onError: $error');
      return true;
    }());
    return false;
  };

  // Android 15 (API 35) enforces edge-to-edge for any app targeting SDK 35
  // or higher. Opt in explicitly so the engine never falls back to the
  // legacy inset behavior, and so transparent status/nav bars are applied
  // before the first frame paints. Per-Scaffold SafeArea remains required.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A1B2A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      path: 'assets/translations',
      startLocale: const Locale('tr', 'TR'),
      fallbackLocale: const Locale('tr', 'TR'),
      child: const KoruBeniApp(),
    ),
  );
}

// ============================================================================
// ANA UYGULAMA
// ============================================================================

class KoruBeniApp extends StatelessWidget {
  const KoruBeniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: EmergencyTriggerHost(
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'KoruBeni',
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            // Clamp text scale factor for accessibility & layout stability
            final mediaQuery = MediaQuery.of(context);
            final clampedTextScaler = mediaQuery.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.4,
            );
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: clampedTextScaler),
              child: OfflineBanner(
                child: AppPrivacyShield(
                  child: Semantics(
                    label: 'app_semantics_label'.tr(),
                    hint: 'app_semantics_hint'.tr(),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
