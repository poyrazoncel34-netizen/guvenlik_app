// ============================================================================
// UYGULAMA KİLİDİ - Uygulama açılışında biyometrik veya PIN ile doğrulama
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/services/biometric_service.dart';

class AppUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppUnlockScreen({super.key, required this.onUnlocked});

  @override
  State<AppUnlockScreen> createState() => _AppUnlockScreenState();
}

class _AppUnlockScreenState extends State<AppUnlockScreen> {
  String _pin = '';
  String? _correctPin;
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biometric'; // Updated by _loadAndCheckBiometric()
  bool _loading = true;

  late final SecureStorage _secureStorage = serviceLocator<SecureStorage>();

  @override
  void initState() {
    super.initState();
    _loadAndCheckBiometric();
  }

  Future<void> _loadAndCheckBiometric() async {
    await _loadPin();
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

  Future<void> _tryBiometric() async {
    final success = await BiometricService.instance.authenticate(
      reason: 'unlock_biometric_reason'.tr(),
    );
    if (success && mounted) {
      widget.onUnlocked();
    }
  }

  void _onPinKey(String key) {
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
        widget.onUnlocked();
      } else {
        HapticFeedback.vibrate();
        setState(() => _pin = '');
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'unlock_semantics'.tr(),
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ] else ...[
                  if (_biometricAvailable) ...[
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: _tryBiometric,
                      icon: Icon(
                        _biometricLabel.contains('Face')
                            ? Icons.face_rounded
                            : Icons.fingerprint_rounded,
                        size: 24,
                      ),
                      label: Text('unlock_biometric_btn'.tr(namedArgs: {'label': _biometricLabel})),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
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
                  _buildNumPad(),
                ],
              ],
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
                ? const Icon(Icons.backspace_outlined, size: 24, color: AppColors.textPrimary)
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
