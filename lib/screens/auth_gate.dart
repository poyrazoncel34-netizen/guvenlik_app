import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/firebase_service.dart';
import '../main.dart' show kFirebaseReady;
import 'main_navigation.dart';
import 'phone_auth_screen.dart';
import 'pin_setup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('>>> AuthGate.build() - firebaseReady=$kFirebaseReady');

    // If Firebase failed, show error instead of crashing
    if (!kFirebaseReady) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.warning),
                const SizedBox(height: 16),
                const Text(
                  "Baglanti kurulamadi",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Firebase servisleri baslatilamadi.\nInternet baglantinizi kontrol edip uygulamayi yeniden baslatin.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Force restart the app
                    WidgetsBinding.instance.reassembleApplication();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Tekrar Dene"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('>>> AuthGate stream: state=${snapshot.connectionState} hasData=${snapshot.hasData} hasError=${snapshot.hasError}');

        if (snapshot.hasError) {
          debugPrint('>>> AuthGate ERROR: ${snapshot.error}');
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.warning),
                  const SizedBox(height: 16),
                  const Text(
                    "Oturum hatasi",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "KoruBeni",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.data == null) {
          debugPrint('>>> AuthGate: no user -> PhoneAuthScreen');
          return const PhoneAuthScreen();
        }

        debugPrint('>>> AuthGate: user found -> PinCheckGate');
        // User is authenticated - update profile & check PIN
        FirebaseService.instance.upsertUserProfile();
        FirebaseService.instance.listenForTokenUpdates();

        return const _PinCheckGate();
      },
    );
  }
}

class _PinCheckGate extends StatefulWidget {
  const _PinCheckGate();

  @override
  State<_PinCheckGate> createState() => _PinCheckGateState();
}

class _PinCheckGateState extends State<_PinCheckGate> {
  bool _checking = true;
  bool _pinSetupDone = false;

  @override
  void initState() {
    super.initState();
    _checkPinSetup();
  }

  Future<void> _checkPinSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(AppConstants.prefPinSetupDone) ?? false;
    if (mounted) {
      setState(() {
        _pinSetupDone = done;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_pinSetupDone) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded, size: 50, color: AppColors.primary),
                ),
                const SizedBox(height: 28),
                const Text(
                  "Hosgeldiniz!",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Guvenliginiz icin bir PIN kodu belirlemeniz gerekiyor.\nBu PIN, acil durumlari iptal etmek icin kullanilacak.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                      );
                      if (result == true && mounted) {
                        setState(() => _pinSetupDone = true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "PIN Belirle",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const MainNavigation();
  }
}
