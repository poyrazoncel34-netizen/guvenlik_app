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

  // Brute force protection
  int _failedAttempts = 0;
  static const int _maxAttempts = 3;
  static const int _lockoutDurationSeconds = 60;
  DateTime? _lockoutEndTime;
  Timer? _lockoutTimer;
  int _lockoutRemaining = 0;

  late final SecureStorage _secureStorage = serviceLocator<SecureStorage>();

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _loadPin();
    if (mounted) setState(() => _loading = false);
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

  void _startLockout() {
    _lockoutEndTime = DateTime.now().add(
      const Duration(seconds: _lockoutDurationSeconds),
    );
    _lockoutRemaining = _lockoutDurationSeconds;
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _lockoutEndTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _lockoutEndTime = null;
          _lockoutRemaining = 0;
          _failedAttempts = 0;
        });
      } else {
        setState(() => _lockoutRemaining = remaining);
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
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
        _failedAttempts = 0;
        widget.onUnlocked();
      } else {
        HapticFeedback.vibrate();
        _failedAttempts++;
        setState(() => _pin = '');
        if (_failedAttempts >= _maxAttempts) {
          _startLockout();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'brute_force_locked'.tr(
                  namedArgs: {'seconds': '$_lockoutDurationSeconds'},
                ),
              ),
              backgroundColor: AppColors.emergency,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('unlock_wrong_pin'.tr()),
              backgroundColor: AppColors.emergency,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
