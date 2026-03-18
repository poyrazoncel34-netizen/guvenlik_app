// ============================================================================
// ONBOARDING LEGAL FLOW — Ana yasal akış kontrolcüsü
// 3 adım: Kullanım Sözleşmesi → KVKK Aydınlatma → Granüler Rıza
// Tüm adımlar tamamlanmadan devam edilemez.
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/consent_manager.dart';
import '../../core/di/service_locator.dart';
import 'terms_of_service_screen.dart';
import 'kvkk_disclosure_screen.dart';
import 'consent_screen.dart';
import '../onboarding_screen.dart';

class OnboardingLegalFlow extends StatefulWidget {
  const OnboardingLegalFlow({super.key});

  @override
  State<OnboardingLegalFlow> createState() => _OnboardingLegalFlowState();
}

class _OnboardingLegalFlowState extends State<OnboardingLegalFlow> {
  int _currentStep = 0;
  final int _totalSteps = 3;

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _completeFlow();
    }
  }

  Future<void> _completeFlow() async {
    final cm = serviceLocator<ConsentManager>();
    await cm.markLegalVersionsAccepted();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, _) => const OnboardingScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Adım göstergesi
            _buildStepIndicator(),
            // İçerik
            Expanded(child: _buildCurrentStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _stepLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_currentStep + 1} / $_totalSteps',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _stepLabel {
    switch (_currentStep) {
      case 0:
        return 'Kullanım Sözleşmesi';
      case 1:
        return 'KVKK Aydınlatma Metni';
      case 2:
        return 'Açık Rıza';
      default:
        return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return TermsOfServiceScreen(
          isReadOnly: false,
          onAccepted: _nextStep,
        );
      case 1:
        return KvkkDisclosureScreen(
          isReadOnly: false,
          onAccepted: _nextStep,
        );
      case 2:
        return ConsentScreen(
          onCompleted: _nextStep,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
