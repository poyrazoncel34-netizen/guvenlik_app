// ============================================================================
// KORUBENI - GUVENLIK UYGULAMASI
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/di/service_locator.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'presentation/providers/providers.dart';
import 'screens/splash_screen.dart';
import 'core/services/background_sync_service.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/data_migration_service.dart';
import 'package:easy_localization/easy_localization.dart';

/// Global flag - AuthGate checks this before using FirebaseAuth
bool kFirebaseReady = false;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // 0) ErrorWidget.builder MUST be set BEFORE runApp so ANY error is caught
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget caught: ${details.exception}');
    // Use tr() for localized error text (locale from EasyLocalization.ensureInitialized)
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

  // 1) Firebase MUST initialize FIRST (platform-specific options for Web support)
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    kFirebaseReady = true;
    debugPrint('>>> Firebase OK');
  } catch (e) {
    debugPrint('>>> Firebase FAILED: $e');
  }

  // 2) ServiceLocator
  try {
    await setupServiceLocator();
    debugPrint('>>> ServiceLocator OK');
  } catch (e) {
    debugPrint('>>> ServiceLocator FAILED: $e');
  }

  // 2b) Data migration
  try {
    await DataMigrationService.migrate();
    debugPrint('>>> DataMigration OK');
  } catch (e) {
    debugPrint('>>> DataMigration FAILED: $e');
  }

  // 3) Background sync
  try {
    await BackgroundSyncService.initialize();
    await BackgroundSyncService.registerPeriodicSync();
  } catch (e) {
    debugPrint('>>> BackgroundSync FAILED: $e');
  }

  // 4b) Offline queue
  try {
    await OfflineQueueService.instance.initialize();
    debugPrint('>>> OfflineQueue OK');
  } catch (e) {
    debugPrint('>>> OfflineQueue FAILED: $e');
  }

  // 4) Crashlytics (only if Firebase ready)
  if (kFirebaseReady) {
    try {
      FlutterError.onError = (details) {
        debugPrint('FlutterError: ${details.exception}');
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('PlatformError: $error');
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (e) {
      debugPrint('>>> Crashlytics setup FAILED: $e');
    }
  }

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

  debugPrint('>>> Running app...');
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
    debugPrint('>>> KoruBeniApp.build()');
    return MultiProvider(
      providers: AppProviders.providers,
      child: MaterialApp(
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
    );
  }
}
