// ============================================================================
// PIN KURULUM EKRANI - ILK KULLANIM ICIN ZORUNLU
// ============================================================================

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/utils/validators.dart';
import 'settings_legal/legal_settings_screen.dart';

class PinSetupScreen extends StatefulWidget {
  final bool requiredSetup;

  const PinSetupScreen({super.key, this.requiredSetup = false});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = "";
  String _confirmPin = "";
  bool _isConfirming = false;
  String? _errorMessage;

  void _handleInput(String key) {
    HapticFeedback.lightImpact();

    if (key == "DEL") {
      setState(() {
        if (_isConfirming) {
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          }
        } else {
          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        }
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      if (_isConfirming) {
        if (_confirmPin.length < AppConstants.pinLength) {
          _confirmPin += key;
        }
      } else {
        if (_pin.length < AppConstants.pinLength) {
          _pin += key;
        }
      }
    });

    // Check completion
    if (!_isConfirming && _pin.length == AppConstants.pinLength) {
      if (!Validators.isValidPin(_pin)) {
        HapticFeedback.vibrate();
        setState(() {
          _errorMessage = 'pin_weak_error'.tr();
          _pin = '';
        });
        return;
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _isConfirming = true;
            _errorMessage = null;
          });
        }
      });
    } else if (_isConfirming && _confirmPin.length == AppConstants.pinLength) {
      _verifyAndSave();
    }
  }

  Future<void> _verifyAndSave() async {
    if (_pin != _confirmPin) {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = 'pin_mismatch'.tr();
        _confirmPin = "";
        _isConfirming = false;
        _pin = "";
      });
      return;
    }

    // Save PIN
    final secureStorage = serviceLocator<SecureStorage>();
    await secureStorage.write(key: SecureStorageKeys.userPin, value: _pin);

    // Mark PIN setup as done
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefPinSetupDone, true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("pin_setup_success".tr()),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(milliseconds: 1500),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;
    return Semantics(
      label: 'pin_screen_semantics'.tr(),
      hint: 'pin_screen_hint_semantics'.tr(),
      child: PopScope(
        canPop: !widget.requiredSetup,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            automaticallyImplyLeading: !widget.requiredSetup,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalSettingsScreen(),
                  ),
                ),
                tooltip: 'settings_legal_info_tooltip'.tr(),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
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
                    _isConfirming
                        ? 'pin_confirm_title'.tr()
                        : 'pin_setup_title'.tr(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isConfirming
                        ? 'pin_confirm_hint'.tr()
                        : 'pin_setup_hint'.tr(
                            namedArgs: {'count': '${AppConstants.pinLength}'},
                          ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.emergency,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(AppConstants.pinLength, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < currentPin.length
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 40),
                  _buildNumberPad(),
                  const SizedBox(height: 16),
                  // PIN forgot info card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.info,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'pin_forgot_info'.tr(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.15,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) return const SizedBox();
        if (index == 11) {
          return _buildPadButton(
            child: const Icon(Icons.backspace_outlined, size: 26),
            onTap: () => _handleInput("DEL"),
          );
        }
        final value = index == 10 ? "0" : "${index + 1}";
        return _buildPadButton(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          onTap: () => _handleInput(value),
        );
      },
    );
  }

  Widget _buildPadButton({required Widget child, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
