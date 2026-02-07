// ============================================================================
// KORUBENI - GUVENLIK UYGULAMASI
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/di/service_locator.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'presentation/providers/providers.dart';
import 'screens/auth_gate.dart';
import 'core/services/background_sync_service.dart';

/// Global flag - AuthGate checks this before using FirebaseAuth
bool kFirebaseReady = false;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0) ErrorWidget.builder MUST be set BEFORE runApp so ANY error is caught
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget caught: ${details.exception}');
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0A1B2A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  "Bir sorun olustu",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
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
                const Text(
                  "Uygulamayi yeniden baslatin.",
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // 1) Firebase MUST initialize FIRST
  try {
    await Firebase.initializeApp();
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

  // 3) Background sync
  try {
    await BackgroundSyncService.initialize();
    await BackgroundSyncService.registerPeriodicSync();
  } catch (e) {
    debugPrint('>>> BackgroundSync FAILED: $e');
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
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('>>> Crashlytics setup FAILED: $e');
    }
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A1B2A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  debugPrint('>>> Running app...');
  runApp(const KoruBeniApp());
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
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const AuthGate(),
      ),
    );
  }
}
