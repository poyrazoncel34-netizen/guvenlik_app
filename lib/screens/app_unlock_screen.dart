// ============================================================================
// UYGULAMA KİLİDİ - Uygulama açılışında PIN ile doğrulama (PIN tek yöntem)
// SECURITY RULE: Biyometrik kimlik doğrulama YASAKTIR (duress riski).
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/services/app_reset_service.dart';
import '../core/services/biometric_service.dart';
import '../core/services/pin_lockout_service.dart';
import 'legal_info_screen.dart';
import 'main_navigation.dart';

class AppUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppUnlockScreen({super.key, required this.onUnlocked});

  @override
  State<AppUnlockScreen> createState() => _AppUnlockScreenState();
}

class _AppUnlockScreenState extends State<AppUnlockScreen> {
  String _pin = '';
  String? _correctPin;
  bool _loading = true;

  DateTime? _lockoutEndTime;
  StreamSubscription<int>? _lockoutSubscription;
  int _lockoutRemaining = 0;

  late final SecureStorage _secureStorage = serviceLocator<SecureStorage>();

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _loadPin();
    await _syncLockoutState();
    if (!mounted) return;
    final available = await BiometricService.instance.isAvailable();
    if (available && mounted) {
      final label = await BiometricService.instance.getBiometricLabel();
      setState(() {
        _biometricAvailable = true;
        _biometricLabel = label;
        _loading = false;
      });
      _tryBiometric();
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPin() async {
    final value = await _secureStorage.read(key: SecureStorageKeys.userPin);
    if (mounted) {
      setState(() {
        _correctPin = value;
      });
    }
  }

  bool get _isLockedOut =>
      _lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!);

  Future<void> _syncLockoutState() async {
    final state = await PinLockoutService.instance.getState();
    if (!mounted) return;
    setState(() {
      _lockoutEndTime = state.lockedUntil;
      _lockoutRemaining = state.remainingSeconds;
    });
    if (state.isLocked) {
      _startLockoutCountdown(state);
    }
  }

  void _startLockoutCountdown(PinLockoutState state) {
    _lockoutSubscription?.cancel();
    _lockoutSubscription = PinLockoutService.instance
        .countdownStream(state)
        .listen((remaining) {
          if (!mounted) {
            return;
          }
          setState(() {
            _lockoutRemaining = remaining;
            if (remaining == 0) {
              _lockoutEndTime = null;
            }
          });
        });
  }

  @override
  void dispose() {
    _lockoutSubscription?.cancel();
    super.dispose();
  }

  void _onPinKey(String key) {
    if (_isLockedOut) return;

    if (key == 'DEL') {
      setState(() {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      });
      return;
    }
    if (_pin.length >= AppConstants.pinLength) return;
    setState(() => _pin += key);

    if (_pin.length == AppConstants.pinLength && _correctPin != null) {
      if (_pin == _correctPin) {
        HapticFeedback.lightImpact();
        PinLockoutService.instance.reset();
        widget.onUnlocked();
      } else {
        HapticFeedback.vibrate();
        setState(() => _pin = '');
        PinLockoutService.instance.registerFailure().then((state) {
          if (!mounted) return;
          setState(() {
            _lockoutEndTime = state.lockedUntil;
            _lockoutRemaining = state.remainingSeconds;
          });
          if (state.isLocked) {
            _startLockoutCountdown(state);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'brute_force_locked'.tr(
                    namedArgs: {'seconds': '${state.remainingSeconds}'},
                  ),
                ),
                backgroundColor: AppColors.emergency,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('unlock_wrong_pin'.tr()),
              backgroundColor: AppColors.emergency,
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'unlock_semantics'.tr(),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalInfoScreen()),
                ),
                tooltip: 'Yasal Bilgiler',
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height
                      - MediaQuery.of(context).padding.top
                      - MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'unlock_title'.tr(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'unlock_subtitle'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        AppConstants.pinLength,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _pin.length
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isLockedOut)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.emergency.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.emergency.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_clock_rounded,
                                color: AppColors.emergency,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'brute_force_locked_short'.tr(
                                  namedArgs: {'seconds': '$_lockoutRemaining'},
                                ),
                                style: const TextStyle(
                                  color: AppColors.emergency,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    _buildNumPad(),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLockedOut ? null : _showForgotPinDialog,
                      child: Text(
                        'Şifremi Unuttum',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPinDialog() async {
    final confirmController = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.emergency, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Şifremi Unuttum',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'KoruBeni tamamen internetsiz çalışır. Güvenliğiniz için şifrenizi '
                  'kurtaramayız. Uygulamaya tekrar erişmek için tüm kayıtlı verilerinizi '
                  '(kişiler, ayarlar) silip uygulamayı sıfırlamanız gerekir. '
                  'Onaylıyor musunuz?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: confirmController,
                  onChanged: (v) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Onaylamak için SIFIRLA yazın',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: confirmController.text == 'SIFIRLA'
                  ? () async {
                      Navigator.pop(ctx);
                      await AppResetService.clearLocalData();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        PageRouteBuilder(
                          pageBuilder: (_, _, _) => const MainNavigation(),
                          transitionsBuilder: (_, a, _, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                        (_) => false,
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergency,
                disabledBackgroundColor: AppColors.emergency.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sıfırla', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    confirmController.dispose();
  }

  Widget _buildNumPad() {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'DEL'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: 12,
      itemBuilder: (context, i) {
        if (keys[i].isEmpty) return const SizedBox();
        return _numKey(keys[i], isIcon: keys[i] == 'DEL');
      },
    );
  }

  Widget _numKey(String key, {bool isIcon = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onPinKey(key),
        customBorder: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: isIcon
                ? const Icon(
                    Icons.backspace_outlined,
                    size: 24,
                    color: AppColors.textPrimary,
                  )
                : Text(
                    key,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
