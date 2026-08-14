// ============================================================================
// ONBOARDING - Parallax efekti + animated dots + pulse glow
// ============================================================================

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/motion.dart';
import '../core/services/onboarding_contact_gate_service.dart';
import 'main_navigation.dart';
import 'onboarding/onboarding_contact_step.dart';

/// Public entry point. It exists only to place [AppRestorationScope] ABOVE
/// the stateful body, because a State cannot supply a restoration scope to
/// itself -- and the scope cannot go on the root MaterialApp without enabling
/// route restoration, which crashes this app on process death. The reason is
/// measured and written up in lib/core/widgets/app_restoration_scope.dart.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onCompleted});

  /// Advances the [AppRoot] shell instead of clearing the route stack.
  /// `pushAndRemoveUntil` destroyed the Navigator's initial route, which is
  /// what made Android state restoration impossible -- see
  /// lib/screens/app_root.dart.
  ///
  /// Null keeps the historical navigation so this screen still works alone.
  final VoidCallback? onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin, RestorationMixin {
  late final PageController _pageController;

  /// RESTORABLE ON PURPOSE, and it is not cosmetic.
  ///
  /// [OnboardingContactStep] restores the half-typed emergency contact, but a
  /// restored draft the user cannot SEE is the same as no restoration: after a
  /// process death the PageView rebuilds at page 0, four swipes away from the
  /// gate page holding their text. Restoring the page index is what makes the
  /// restored draft reachable, so the two belong together.
  final RestorableInt _restoredPage = RestorableInt(0);

  int get _currentPage => _restoredPage.value;
  set _currentPage(int value) => _restoredPage.value = value;

  @override
  String? get restorationId => 'onboarding_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restoredPage, 'page_index');
    // The controller has to be built from the restored index: PageController
    // takes its start page at construction, and jumping afterwards would show
    // page 0 for a frame and animate away from it.
    if (initialRestore) {
      _pageController = PageController(initialPage: _restoredPage.value);
    } else if (_pageController.hasClients) {
      _pageController.jumpToPage(_restoredPage.value);
    }
  }
  bool _contactGateSatisfied = false;
  late AnimationController _iconPulseController;
  late AnimationController _fadeController;

  List<_OnboardingPage> get _pages => [
    // Order is deliberate: the differentiator no competitor can copy (local
    // PIN, no biometrics) comes first, and the Pro mention comes last. Opening
    // on "Pro panic flow" priced the product before it meant anything.
    _OnboardingPage(
      icon: Icons.lock_rounded,
      title: 'onboarding_1_title'.tr(),
      body: 'onboarding_1_body'.tr(),
      color: AppColors.success,
    ),
    _OnboardingPage(
      icon: Icons.call_rounded,
      title: 'onboarding_2_title'.tr(),
      body: 'onboarding_2_body'.tr(),
      color: AppColors.accent,
    ),
    _OnboardingPage(
      icon: Icons.location_on_rounded,
      title: 'onboarding_3_title'.tr(),
      body: 'onboarding_3_body'.tr(),
      color: AppColors.primary,
    ),
    _OnboardingPage(
      icon: Icons.vibration_rounded,
      title: 'onboarding_4_title'.tr(),
      body: 'onboarding_4_body'.tr(),
      color: AppColors.emergency,
    ),
    // Gate page. Kept last so every informational page is still reachable, and
    // so 'Skip' has somewhere to land that is not "done".
    _OnboardingPage(
      icon: Icons.contact_phone_rounded,
      title: 'onboarding_contact_title'.tr(),
      body: 'onboarding_contact_body'.tr(),
      color: AppColors.primary,
      isContactStep: true,
    ),
  ];

  int get _contactStepIndex => _pages.length - 1;

  bool get _isOnContactStep => _currentPage == _contactStepIndex;

  @override
  void initState() {
    super.initState();
    _iconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  /// Jumps to the gate page instead of completing. 'Skip' used to call
  /// [_finish] directly, which is precisely how an install reached the home
  /// screen with no reachable contact.
  void _skipToContactStep() {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      _contactStepIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    // The service refuses to write prefOnboardingDone without a callable
    // primary contact, so a stale _contactGateSatisfied cannot let an
    // unconfigured install through.
    final completed = await OnboardingContactGateService.completeOnboarding();
    if (!mounted) return;
    if (!completed) {
      setState(() => _contactGateSatisfied = false);
      _pageController.jumpToPage(_contactStepIndex);
      return;
    }
    HapticFeedback.mediumImpact();
    final onCompleted = widget.onCompleted;
    if (onCompleted != null) {
      onCompleted();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainNavigation(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Motion.slow,
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _restoredPage.dispose();
    _iconPulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientStart, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeController,
            child: Column(
              children: [
                Semantics(
                  label: 'semantics_onboarding_page'.tr(
                    args: ['${_currentPage + 1}', '${_pages.length}'],
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isOnContactStep ? null : _skipToContactStep,
                      child: Text(
                        _isOnContactStep ? '' : 'btn_skip'.tr(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentPage = i);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, i) {
                      final p = _pages[i];
                      if (p.isContactStep) {
                        // A text form under a parallax transform is unusable;
                        // the gate page renders straight.
                        return OnboardingContactStep(
                          onGateChanged: (satisfied) {
                            if (!mounted || satisfied == _contactGateSatisfied) {
                              return;
                            }
                            setState(
                              () => _contactGateSatisfied = satisfied,
                            );
                          },
                        );
                      }
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          // ── Parallax offset calculation ──
                          double pageOffset = 0.0;
                          if (_pageController.position.haveDimensions) {
                            pageOffset = (_pageController.page ?? 0.0) - i;
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Icon with parallax & glow
                                Transform.translate(
                                  offset: Offset(
                                    pageOffset * -60,
                                    0,
                                  ), // Parallax
                                  child: AnimatedBuilder(
                                    animation: _iconPulseController,
                                    builder: (context, child) {
                                      final pulseVal =
                                          _iconPulseController.value;
                                      return Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          color: p.color.withValues(
                                            alpha: 0.12,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: p.color.withValues(
                                                alpha: 0.1 + pulseVal * 0.15,
                                              ),
                                              blurRadius: 20 + (pulseVal * 20),
                                              spreadRadius: pulseVal * 5,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          p.icon,
                                          size: 52,
                                          color: p.color,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 40),
                                // Title with slight parallax
                                Transform.translate(
                                  offset: Offset(pageOffset * -30, 0),
                                  // Page heading (MP-12-017).
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      p.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Body with different parallax
                                Transform.translate(
                                  offset: Offset(pageOffset * -15, 0),
                                  child: Text(
                                    p.body,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // ── Animated pill dots ──
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: Motion.base,
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? _pages[_currentPage].color
                              : AppColors.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: _currentPage == i
                              ? [
                                  BoxShadow(
                                    color: _pages[_currentPage].color
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Button ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      label: _currentPage < _pages.length - 1
                          ? 'semantics_next_page'.tr()
                          : 'semantics_start_app'.tr(),
                      button: true,
                      child: ElevatedButton(
                        onPressed: _isOnContactStep && !_contactGateSatisfied
                            ? null
                            : () {
                                if (!_isOnContactStep) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutCubic,
                                  );
                                  return;
                                }
                                unawaited(_finish());
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.border,
                          disabledForegroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: _pages[_currentPage].color.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        child: Text(
                          _isOnContactStep ? 'btn_start'.tr() : 'btn_next'.tr(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isOnContactStep && !_contactGateSatisfied)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Text(
                      'onboarding_contact_required_hint'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  /// Marks the page that carries the emergency-contact gate.
  final bool isContactStep;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.isContactStep = false,
  });
}
