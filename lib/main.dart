// ============================================================================
// KORUBENI - GUVENLIK UYGULAMASI
// ============================================================================

import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/navigation/app_navigator.dart';
import 'presentation/providers/providers.dart';
import 'screens/app_root.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/crash_log_service.dart';
import 'core/services/medical_data_cleanup_service.dart';
import 'core/services/foreground_service.dart';
import 'core/services/haptic_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/atomic_storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/widgets/emergency_trigger_host.dart';
import 'core/design_tokens.dart';
import 'core/widgets/app_privacy_shield.dart';
import 'core/services/local_logger_service.dart';
import 'core/services/sensitive_temp_file_service.dart';
import 'core/services/app_bootstrap_service.dart';
import 'core/constants/feature_access_matrix.dart';
import 'core/config/app_environment.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release log hygiene: silence app-level debugPrint so logs never reach
  // logcat. Local diagnostics below persist allowlisted event codes only.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

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
                  size: IconSizes.hero,
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

  final criticalBootstrap = await AppBootstrapService.production()
      .initializeCritical();
  if (!criticalBootstrap.isReady) {
    runApp(
      ErrorWidget.builder(
        FlutterErrorDetails(
          exception: StateError(
            'CRITICAL_BOOTSTRAP_${criticalBootstrap.reasonCode}',
          ),
        ),
      ),
    );
    return;
  }

  // Best-effort services cannot change the critical bootstrap decision.
  // Web skips platform notification plugins.
  try {
    FeatureAccessMatrix.debugPrintMatrix();

    final services = <Future<void>>[
      // KVKK Md.7 — purge orphaned medical-profile data from removed feature.
      // Best-effort (internally try/catch); runs concurrently so it never
      // blocks the emergency / notification startup path.
      MedicalDataCleanupService.purgeIfNeeded(),
      OfflineQueueService.instance.initialize(),
      AtomicStorageService.instance.checkIntegrity(),
      HapticService.initialize(),
      ConnectivityService.instance.initialize(),
      LocalLoggerService.instance.initialize(),
      SensitiveTempFileService.purgeStaleExports(),
    ];
    if (!kIsWeb) {
      services.add(NotificationService.instance.initialize());
      services.add(KoruBeniForegroundService.configure());
    }
    await Future.wait(services);
  } catch (_) {
    // Non-critical initialization failures remain degraded local features.
  }

  // Error handling for Flutter errors — local device-only crash log.
  FlutterError.onError = (details) {
    CrashLogService.instance.record(LocalErrorCode.flutterFrameworkUnhandled);
    LocalLoggerService.instance.errorCode(
      LocalErrorCode.flutterFrameworkUnhandled,
    );
    assert(() {
      debugPrint('FlutterError: ${details.exception}');
      return true;
    }());
    // Framework exception text/stacks can contain PII. Keep raw presentation
    // in debug builds only; release diagnostics use the structured code above.
    if (!kReleaseMode) {
      FlutterError.presentError(details);
    }
  };

  // Zero-fault: Fatal hataları yutma - return false ile standart hata yönetimine bırak
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashLogService.instance.record(LocalErrorCode.platformDispatcherUnhandled);
    LocalLoggerService.instance.errorCode(
      LocalErrorCode.platformDispatcherUnhandled,
    );
    assert(() {
      debugPrint('PlatformDispatcher.onError: $error');
      return true;
    }());
    // Returning false causes the engine to print the raw exception/stack.
    // Release handles it locally to preserve logcat privacy; debug retains the
    // default crash visibility for developers.
    return kReleaseMode;
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
      // First production market/runtime is intentionally Turkish-only. Keep
      // the English catalog as an internal parity reference until that runtime
      // path has its own device and Play evidence.
      supportedLocales: const [Locale('tr', 'TR')],
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

/// Preserves Android accessibility scaling through the release acceptance
/// boundary of 200%. Larger values are bounded until every screen has passed
/// the corresponding reflow matrix on physical devices.
TextScaler appTextScaler(TextScaler systemScaler) =>
    systemScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 2.0);

class KoruBeniApp extends StatelessWidget {
  const KoruBeniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: EmergencyTriggerHost(
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          // Enables Android state restoration for the whole app: without a
          // root bucket every `RestorationMixin` below is inert,
          // `registerForRestoration` silently keeps its default value, and a
          // half-typed emergency contact is lost to any OS-initiated process
          // death. Measured on an API 36 emulator: before this line the drafts
          // were gone after `adb shell am kill`; after it they came back.
          //
          // THIS LINE HAS A PRECONDITION, and it is not obvious. `WidgetsApp`
          // gives its Navigator `restorationScopeId: 'nav'` unconditionally, so
          // turning restoration on ALSO turns on route-history restoration. If
          // the app destroys its initial route, the restored history comes back
          // empty and `assert(_history.isNotEmpty)` in navigator.dart bricks the
          // app on every resume. Startup used to do exactly that, four times
          // over, with `pushReplacement`/`pushAndRemoveUntil`; that is why
          // `home:` is now the [AppRoot] shell, which swaps destinations as
          // STATE and never touches the route stack. Do not reintroduce a
          // top-level route replacement without re-reading
          // lib/screens/app_root.dart and
          // test/screens/state_restoration_navigator_precondition_test.dart.
          restorationScopeId: 'korubeni',
          debugShowCheckedModeBanner: false,
          title: 'KoruBeni',
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: appTextScaler(mediaQuery.textScaler),
              ),
              // ZLayer.shield: nothing may render above the privacy shield or
              // the PIN gate. The token named that invariant and had no
              // consumer, so nothing held it. This is the consumer.
              child: AppPrivacyShield(
                layer: ZLayer.shield,
                child: Semantics(
                  label: 'app_semantics_label'.tr(),
                  hint: 'app_semantics_hint'.tr(),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const AppRoot(),
        ),
      ),
    );
  }
}
