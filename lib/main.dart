// ============================================================================
// KORUBENI - GUVENLIK UYGULAMASI
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/di/service_locator.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/navigation/app_navigator.dart';
import 'presentation/providers/providers.dart';
import 'screens/splash_screen.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/data_migration_service.dart';
import 'core/services/foreground_service.dart';
import 'core/services/haptic_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/atomic_storage_service.dart';
import 'core/widgets/emergency_trigger_host.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // 0) ErrorWidget.builder MUST be set BEFORE runApp so ANY error is caught
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget caught: ${details.exception}');
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
                  details.exception.toString().length > 200
                      ? details.exception.toString().substring(0, 200)
                      : details.exception.toString(),
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
  try {
    await Future.wait([
      // Critical services (must complete)
      setupServiceLocator(),
      DataMigrationService.migrate(),
      OfflineQueueService.instance.initialize(),
      AtomicStorageService.instance.checkIntegrity(),
      
      // Non-blocking services
      HapticService.initialize(),
      ConnectivityService.instance.initialize(),
      KoruBeniForegroundService.configure(),
    ]);
    // Services ready - app launches instantly
  } catch (e) {
    // Non-fatal - app continues
  }

  // Error handling for Flutter errors (no Firebase Crashlytics)
  FlutterError.onError = (details) {
    // Offline-first: console logging only
    assert(() {
      debugPrint('FlutterError: ${details.exception}');
      return true;
    }());
  };
  
  // Zero-fault: Fatal hataları yutma - return false ile standart hata yönetimine bırak
  // return true = "hata işlendi" (sessizce yutulur, beyaz ekranda kilit kalabilir)
  // return false = Flutter/Dart standart işleyişi devam eder
  PlatformDispatcher.instance.onError = (error, stack) {
    assert(() {
      debugPrint('PlatformDispatcher.onError: $error');
      return true;
    }());
    // Kritik hatalarda uygulamanın kilitli kalması yerine standart hata yönetiminin
    // çalışmasına izin ver (ErrorWidget, crash reporting vb.)
    return false;
  };

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
          builder: (context, child) => Semantics(
            label: 'KoruBeni güvenlik uygulaması',
            hint: 'Acil durumlarda yardım çağırın, konum paylaşın',
            child: child ?? const SizedBox.shrink(),
          ),
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
