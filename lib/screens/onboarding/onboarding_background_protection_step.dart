// ============================================================================
// ONBOARDING - ARKA PLAN KORUMASI ADIMI
// ============================================================================
// Owner decision OD-2 (2026-10-11).
//
// On a clean Android 14+ install, Android's "Alarms & reminders" special access
// is OFF by default. Without it a protected Panic cannot be armed at all --
// `PanicArmPolicy` refuses it and offers the manual "Simdi Ara" path instead
// (Y-11). Before this step the user met that refusal for the first time while
// pressing the panic button, which is the worst possible moment to discover a
// setup gap.
//
// Two rules the owner set, and they pull in opposite directions:
//
//  1. Do NOT throw the user into Android Settings as onboarding opens. Android's
//     own guidance is in-context permission requests, and a special-access
//     screen on first launch reads as a malware prompt.
//  2. Do NOT let the user believe Panic is fully ready when it is not.
//
// So this step is VISIBLE and EXPLAINED but SKIPPABLE: the Next button is never
// disabled here, and skipping leaves readiness `limited`, which the home card
// shows from [SafetyReadinessLevel].
//
// WHAT THE STATUS LINE MAY CLAIM. This step owns exactly ONE Android
// capability: the exact-alarm special access. The home card's "Arka Plan
// Hazırlığı" chip is `backgroundAlertReady`, which ALSO needs the notification
// permission and a high-importance channel -- and in this flow notifications
// are requested AFTER this step. So the status line names the alarm access
// specifically rather than "background protection" in general. Widening the
// signal was the tempting fix and is the wrong one: the CTA opens the
// exact-alarm screen and cannot grant notifications, so the step would show
// red for something it is unable to repair. Narrowing the words is the honest
// half; the card still owns the overall verdict.
// The emergency-contact gate stays the only step that can block completion.
// ============================================================================

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/design_tokens.dart';
import '../../core/services/emergency_platform_service.dart';
import '../../core/services/emergency_readiness_service.dart';
import '../../core/services/safety_readiness_level.dart';
import '../../core/widgets/minimum_tap_target.dart';

class OnboardingBackgroundProtectionStep extends StatefulWidget {
  const OnboardingBackgroundProtectionStep({
    super.key,
    this.platform,
    this.readiness,
  });

  /// Injected in tests; production uses the singletons.
  final EmergencyPlatformService? platform;
  final EmergencyReadinessService? readiness;

  @override
  State<OnboardingBackgroundProtectionStep> createState() =>
      _OnboardingBackgroundProtectionStepState();
}

class _OnboardingBackgroundProtectionStepState
    extends State<OnboardingBackgroundProtectionStep>
    with WidgetsBindingObserver {
  EmergencyPlatformService get _platform =>
      widget.platform ?? EmergencyPlatformService.instance;
  EmergencyReadinessService get _readinessService =>
      widget.readiness ?? EmergencyReadinessService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listening, not just probing. EmergencyReadinessService supersedes an
    // in-flight probe when a newer one starts: the superseded call returns the
    // PREVIOUS state and does not notify. A step that only awaited its own
    // probe could therefore paint a stale status and never hear the newer
    // result -- it happened to work only because the host registers its
    // lifecycle observer before this one, which is ordering, not a guarantee.
    // HomePage listens for the same reason.
    _readinessService.addListener(_onReadinessChanged);
    _refresh();
  }

  @override
  void dispose() {
    _readinessService.removeListener(_onReadinessChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onReadinessChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from Android's special-access screen. The Activity result is
    // NOT consulted: that screen reports nothing useful about the toggle, and
    // the user may also have changed it from the notification shade or from
    // Settings reached another way. `canScheduleExactAlarms()` is the only
    // authority, and it is asked again here.
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _refresh() {
    // EmergencyTriggerHost sits above MaterialApp and already re-probes on
    // resume, so this is a second, deliberately cheap read for the case where
    // this step is shown without that host (tests, and any future embedding).
    unawaited(_readinessService.checkReadiness());
  }

  Future<void> _openSettings() async {
    HapticFeedback.selectionClick();
    // Guarded natively: ExactAlarmSettingsIntent asks canScheduleExactAlarms()
    // first, opens this package's own toggle via a `package:` URI, and falls
    // back to the app details page if the OEM's Settings refuses it. It never
    // drops the user on the generic "Alarms & reminders" list.
    await _platform.requestExactAlarmPermission();
  }

  @override
  Widget build(BuildContext context) {
    final level = _readinessService.lastState.readinessLevel;
    final granted = _readinessService.lastState?.exactAlarmPermission ?? false;

    final String statusKey;
    if (granted) {
      statusKey = 'onboarding_background_status_ready';
    } else if (level == SafetyReadinessLevel.unavailable) {
      statusKey = 'onboarding_background_status_unknown';
    } else {
      statusKey = 'onboarding_background_status_missing';
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  // IconSizes.hero (48), not the 52 the sibling onboarding
                  // pages use. 52 is a documented exception in the token file,
                  // but design_token_ratchet_test pins the NUMBER of off-scale
                  // sites and its rule is that new code lands on the scale.
                  // Visually this is one step down inside the same 110 dp
                  // badge, so no existing page changes.
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    size: IconSizes.hero,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 40),
                Semantics(
                  header: true,
                  child: Text(
                    'onboarding_background_title'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'onboarding_background_body'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    statusKey.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: granted ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (!granted)
                  MinimumTapTarget(
                    onTap: _openSettings,
                    child: OutlinedButton.icon(
                      onPressed: _openSettings,
                      icon: const Icon(
                        Icons.settings_rounded,
                        size: IconSizes.listItem,
                      ),
                      label: Text('onboarding_background_cta'.tr()),
                    ),
                  ),
                if (!granted) ...[
                  const SizedBox(height: 12),
                  Text(
                    'onboarding_background_skip_note'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
