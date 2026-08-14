// ============================================================================
// ANA SAYFA (PREMIUM UX – STAGGERED ANİMASYONLAR + GLASSMORPHİSM)
// ============================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/consent_gate_service.dart';
import '../core/services/subscription_access_state.dart';
import '../core/services/subscription_gate.dart';
import '../models/consent_record.dart';
// Analytics service removed (offline-first)
import 'package:easy_localization/easy_localization.dart';
import '../presentation/providers/home_provider.dart';
import '../presentation/providers/subscription_provider.dart';
import '../widgets/legal_disclaimer_banner.dart';
import '../widgets/panic_button.dart';
import '../widgets/siren_dialog.dart';
import 'fake_call_screen.dart';
import 'contacts_page.dart';
import 'countdown_screen.dart';
import 'safe_walk_screen.dart';
import 'safety_timeline_screen.dart';
import 'check_in_screen.dart';
import 'battery_optimization_wizard.dart';
import '../core/services/emergency_readiness_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/rehearsal_record_service.dart';
import '../core/widgets/exact_alarm_permission_guard.dart';
import '../core/widgets/readiness_card.dart';
import '../core/utils/permission_helper.dart';
import '../core/widgets/escape_dismissible.dart';
import '../core/design_tokens.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _cardsController;
  StreamSubscription<bool>? _connectivitySubscription;

  // Staggered card animations
  final List<Animation<double>> _cardFadeAnimations = [];
  final List<Animation<Offset>> _cardSlideAnimations = [];
  static const int _totalCards = 7;

  /// Last completed Test Mode rehearsal. `null` until loaded, and `null` also
  /// means "never rehearsed" — the card treats both as "not yet", which is the
  /// honest reading before the async load lands.
  DateTime? _lastRehearsalAt;

  @override
  void initState() {
    super.initState();
    EmergencyReadinessService.instance.addListener(_onReadinessChanged);
    unawaited(_loadLastRehearsal());
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // ── Staggered card animations ──
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    for (int i = 0; i < _totalCards; i++) {
      final start = (i * 0.08).clamp(0.0, 0.7);
      final end = (start + 0.35).clamp(0.0, 1.0);
      _cardFadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _cardsController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
      _cardSlideAnimations.add(
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _cardsController,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
      );
    }

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _cardsController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().initialize();
      _initConnectivity();
      unawaited(_maybeShowBatteryOptimizationWizard());
    });
    // Analytics removed (offline-first)
  }

  Future<void> _maybeShowBatteryOptimizationWizard() async {
    if (kIsWeb || !mounted) return;
    final shouldShow = await BatteryOptimizationWizard.shouldShow();
    if (!mounted || !shouldShow) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BatteryOptimizationWizard(checkFirstLaunch: true),
      ),
    );
  }

  void _initConnectivity() {
    ConnectivityService.instance.initialize();
    // Offline-first: No internet warning UI - app works fully offline
    _connectivitySubscription = ConnectivityService.instance.onStatusChange
        .listen((_) {
          if (mounted) setState(() {});
        });
  }

  void _onReadinessChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLastRehearsal() async {
    final recorded = await RehearsalRecordService.lastRehearsalAt();
    if (!mounted) return;
    setState(() => _lastRehearsalAt = recorded);
  }

  void _openBatteryWizard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BatteryOptimizationWizard()),
    );
  }

  @override
  void dispose() {
    EmergencyReadinessService.instance.removeListener(_onReadinessChanged);
    _connectivitySubscription?.cancel();
    _headerController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final subscriptionAccess = context.watch<SubscriptionProvider>().access;
    final pendingMessage = provider.takeMessage();
    if (pendingMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnack(pendingMessage);
      });
    }
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    // These four numbers were the ad-hoc original that DensityTokens was
    // EXTRACTED FROM, and then nothing consumed the tokens -- so the scale sat
    // beside the literals it was meant to replace and enforced nothing
    // (measured: docs/audit/evidence/design_tokens.json). Every value below is
    // byte-identical to what shipped, so this migration renders no differently.
    final density = DensityTokens.of(size);
    final horizontalPadding = DensityTokens.horizontalPadding(size);
    final shortScreen = Breakpoints.isShort(size);
    final spacing = DensityTokens.gap(density);
    final sectionSpacing = DensityTokens.sectionGap(density);
    final largeSectionSpacing = shortScreen ? Spacing.md : Spacing.xl;
    // Space for bottom nav so content does not sit under navigation.
    final bottomPadding = 72.0 + padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surface],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    shortScreen ? 12 : 20,
                    horizontalPadding,
                    shortScreen ? 8 : 12,
                  ),
                  child: FadeTransition(
                    opacity: _headerController,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.5),
                        end: Offset.zero,
                      ).animate(_headerController),
                      child: _buildHeader(),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Offline-first: No internet warning UI
                      SizedBox(height: shortScreen ? 4 : 6),
                      _buildEmergencyContactChip(provider),
                      SizedBox(height: spacing),
                      ReadinessCard(
                        // Derived from the SAME state that authorizes the
                        // emergency action, so the card cannot claim protection
                        // the gate would refuse (R2-01).
                        subscriptionNotice: subscriptionAccess.noticeFor(),
                        graceHoursRemaining: subscriptionAccess
                            .remainingOfflineGraceHours(),
                        locationGranted: provider.locationPermissionGranted,
                        contactsGranted: provider.contactsPermissionGranted,
                        hasEmergencyContact: provider.emergencyContact != null,
                        readiness:
                            EmergencyReadinessService.instance.lastState,
                        lastRehearsalAt: _lastRehearsalAt,
                        onFixEmergencyContact: _navigateToContacts,
                        onFixCallPermission: _requestCallPhonePermission,
                        onFixBackground: _openBatteryWizard,
                        onFixLocation: _requestLocationPermission,
                        onFixContacts: _requestContactsPermission,
                        onRunRehearsal: _startTestMode,
                      ),
                      if (!provider.onboardingDismissed) ...[
                        SizedBox(height: shortScreen ? 10 : 16),
                        _buildOnboardingCard(provider),
                      ],
                      SizedBox(height: sectionSpacing),
                      const Center(child: PanicButton()),
                      // Free users too: a locked SOS with no way to rehearse
                      // asks for trust the app has not earned yet.
                      SizedBox(height: sectionSpacing),
                      _buildTestModeButton(),
                      SizedBox(height: largeSectionSpacing),
                      _buildQuickActions(subscriptionAccess),
                      SizedBox(height: largeSectionSpacing),
                      _buildSafetyTips(),
                      SizedBox(height: shortScreen ? 10 : 16),
                      const LegalDisclaimerBanner(
                        bannerContext: LegalBannerContext.home,
                      ),
                      SizedBox(height: bottomPadding),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          // Home is the one screen with no AppBar, and AppBar is what supplies
          // `header: true` on every other screen. Without this the screen has no
          // heading at all for a screen reader, so heading navigation lands
          // nowhere (MP-12-017).
          child: Semantics(
            header: true,
            child: Text(
            'welcome_greeting'.tr(),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.8,
              height: 1.1,
            ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContactChip(HomeProvider provider) {
    final name = provider.emergencyContact?.name;
    final phone = provider.emergencyContact?.phone;
    final hasContact = name != null && phone != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _navigateToContacts,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: AppColors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasContact
                        ? "emergency_contact_ready".tr()
                        : "emergency_contact_not_selected".tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasContact
                        ? "$name • $phone"
                        : "tap_to_select_contact".tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    // Consent gate — withdrawing location consent must stop further
    // location processing. Emergency / SOS path is intentionally NOT gated.
    if (!ConsentGateService.requireConsent(
      context,
      ConsentRecord.typeLocation,
    )) {
      return;
    }
    if (!mounted) return;
    // Show rationale dialog before requesting permission
    final proceed = await _showPermissionRationale(
      title: 'perm_rationale_location_title'.tr(),
      body: 'perm_rationale_location_body'.tr(),
    );
    if (!proceed || !mounted) return;

    final provider = context.read<HomeProvider>();
    final message = await provider.requestLocationPermission(context: context);
    if (message != null && mounted) _showSnack(message);
  }

  Future<void> _requestContactsPermission() async {
    final allowed = await SubscriptionGate.ensureAccess(
      context,
      PremiumFeature.contacts,
    );
    if (!allowed || !mounted) return;

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("home_contacts_web_unsupported".tr())),
      );
      return;
    }
    // Show rationale dialog before requesting permission
    final proceed = await _showPermissionRationale(
      title: 'perm_rationale_contacts_title'.tr(),
      body: 'perm_rationale_contacts_body'.tr(),
    );
    if (!proceed || !mounted) return;

    final provider = context.read<HomeProvider>();
    final message = await provider.requestContactsPermission();
    if (message != null && context.mounted) {
      _showSnack(message);
    }
  }

  Future<void> _requestCallPhonePermission() async {
    await PermissionHelper.requestCallPhonePermission(context);
    await EmergencyReadinessService.instance.checkReadiness();
    if (mounted) setState(() {});
  }

  Future<bool> _showPermissionRationale({
    required String title,
    required String body,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => EscapeDismissible(
        child: AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          body,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'perm_rationale_later'.tr(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('perm_rationale_allow'.tr()),
          ),
        ],
      ),
      ),
    );
    return result ?? false;
  }

  void _showFakeCallDelayOptions() {
    if (!ConsentGateService.requireConsent(
      context,
      ConsentRecord.typeFakeCall,
    )) {
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EscapeDismissible(
        child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'fake_call_delay_title'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'fake_call_delay_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildFakeCallOption('fake_call_delay_now'.tr(), Duration.zero),
            _buildFakeCallOption(
              'fake_call_delay_1min'.tr(),
              const Duration(minutes: 1),
            ),
            _buildFakeCallOption(
              'fake_call_delay_3min'.tr(),
              const Duration(minutes: 3),
            ),
            // Longer horizons exist for the everyday reasons people actually
            // reach for this — leaving a meeting, a bad date, a pushy seller.
            // Three minutes is too short to cover any of them.
            _buildFakeCallOption(
              'fake_call_delay_10min'.tr(),
              const Duration(minutes: 10),
            ),
            _buildFakeCallOption(
              'fake_call_delay_15min'.tr(),
              const Duration(minutes: 15),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildFakeCallOption(String label, Duration delay) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
      onTap: () async {
        Navigator.pop(context);
        if (delay == Duration.zero) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FakeCallScreen()),
          );
        } else {
          await _scheduleDelayedFakeCall(delay);
        }
      },
    );
  }

  Future<void> _scheduleDelayedFakeCall(Duration delay) async {
    final permissionStatus = await NotificationService.instance
        .ensureNotificationPermissionForScheduledAction(context);
    if (!mounted) return;

    if (permissionStatus != NotificationPermissionRequestStatus.granted) {
      final content =
          permissionStatus ==
              NotificationPermissionRequestStatus.permanentlyDenied
          ? '${'notification_permission_denied'.tr()} ${'delayed_fake_call_notification_permission_required'.tr()}'
          : 'delayed_fake_call_notification_permission_required'.tr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(content),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action:
              permissionStatus ==
                  NotificationPermissionRequestStatus.permanentlyDenied
              ? SnackBarAction(
                  label: 'open_notification_settings'.tr(),
                  onPressed: () {
                    unawaited(PermissionHelper.openNotificationSettings());
                  },
                )
              : null,
        ),
      );
      return;
    }

    // A delayed fake call is only shown as scheduled when exact-alarm access
    // is currently granted. Returning from Settings requires an explicit retry.
    final exactAlarmGranted = await requireExactAlarmPermission(
      context,
    );
    if (!exactAlarmGranted || !mounted) return;

    final scheduled = await NotificationService.instance.scheduleFakeCall(
      delay: delay,
    );
    if (!mounted) return;

    final snackbar = SnackBar(
      content: Text(
        scheduled
            ? 'fake_call_delay_scheduled'.tr(
                namedArgs: {'seconds': '${delay.inSeconds}'},
              )
            : 'delayed_fake_call_notification_permission_required'.tr(),
      ),
      backgroundColor: scheduled ? AppColors.primary : AppColors.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackbar);
  }

  Widget _buildOnboardingCard(HomeProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "get_ready_in_3_steps".tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: provider.dismissOnboarding,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildOnboardingStep(
            index: "1",
            title: "select_emergency_contact".tr(),
            subtitle: "select_trusted_contact_from_phonebook".tr(),
            onTap: _navigateToContacts,
          ),
          _buildOnboardingStep(
            index: "2",
            title: "allow_location_permission".tr(),
            subtitle: "location_permission_required_desc".tr(),
            onTap: _requestLocationPermission,
          ),
          _buildOnboardingStep(
            index: "3",
            title: "run_test_mode".tr(),
            subtitle: "try_flow_without_real_call".tr(),
            onTap: _startTestMode,
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingStep({
    required String index,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    index,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestModeButton() {
    return OutlinedButton.icon(
      onPressed: _startTestMode,
      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
      label: Text("test_mode_no_real_call".tr()),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _startTestMode() async {
    final allowed = await SubscriptionGate.ensureAccess(
      context,
      PremiumFeature.testMode,
    );
    if (!allowed || !mounted) return;

    // `true` only when the rehearsal countdown actually reached the end. A
    // cancelled test is not evidence the setup works, so it must not be
    // recorded as one.
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CountdownScreen(isTestMode: true),
      ),
    );
    if (completed == true) {
      await RehearsalRecordService.recordCompletedRehearsal();
    }
    if (!mounted) return;
    await _loadLastRehearsal();
  }

  Future<void> _navigateToContacts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactsPage()),
    );
    if (!mounted) return;
    await context.read<HomeProvider>().refreshAfterContactsChanged();
  }

  Widget _buildQuickActions(SubscriptionAccessState access) {
    final shortScreen = Breakpoints.isShort(MediaQuery.sizeOf(context));
    final gap = shortScreen ? 10.0 : Spacing.sm + 2;

    // Define all action cards data
    final actions = [
      _ActionData(
        "fake_call".tr(),
        Icons.phone_in_talk_rounded,
        AppColors.primary,
        PremiumFeature.fakeCall,
        () => _showFakeCallDelayOptions(),
      ),
      _ActionData(
        "siren".tr(),
        Icons.notifications_active_rounded,
        AppColors.warning,
        PremiumFeature.siren,
        _activateSiren,
      ),
      _ActionData(
        "safe_walk".tr(),
        Icons.directions_walk_rounded,
        AppColors.accent,
        PremiumFeature.safeWalk,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SafeWalkScreen()),
          );
        },
      ),
      _ActionData(
        "contacts".tr(),
        Icons.people_rounded,
        AppColors.info,
        PremiumFeature.contacts,
        _navigateToContacts,
      ),
      _ActionData(
        "timeline".tr(),
        Icons.timeline_rounded,
        AppColors.accent,
        PremiumFeature.timeline,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SafetyTimelineScreen()),
          );
        },
      ),
      _ActionData(
        "check_in".tr(),
        Icons.verified_user_rounded,
        AppColors.success,
        PremiumFeature.checkIn,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CheckInScreen()),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading, so heading navigation can jump the grid.
        Semantics(
          header: true,
          child: Text(
            "quick_actions".tr(),
            style: TextStyle(
              fontSize: shortScreen ? 18 : 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(height: gap),
        // Build rows of 2 cards with staggered animations
        for (int row = 0; row < ((actions.length + 1) ~/ 2); row++) ...[
          if (row > 0) SizedBox(height: gap),
          Row(
            children: [
              Expanded(
                child: _buildAnimatedActionCard(
                  actions[row * 2],
                  row * 2,
                  access,
                ),
              ),
              SizedBox(width: gap),
              if (row * 2 + 1 < actions.length)
                Expanded(
                  child: _buildAnimatedActionCard(
                    actions[row * 2 + 1],
                    row * 2 + 1,
                    access,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAnimatedActionCard(
    _ActionData data,
    int index,
    SubscriptionAccessState access,
  ) {
    // Per-feature, via the gate's own rule: safe-walk and check-in follow the
    // unbounded emergency policy while timeline and the rest stay bounded. One
    // `isPro` boolean for the whole grid showed a locked badge over a feature
    // the gate would have allowed, and vice versa (R2-04).
    final isLocked = !SubscriptionGate.isAuthorized(access, data.feature);
    if (index >= _cardFadeAnimations.length) {
      return _buildActionCard(data, isLocked: isLocked);
    }
    return AnimatedBuilder(
      animation: _cardsController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _cardFadeAnimations[index],
          child: SlideTransition(
            position: _cardSlideAnimations[index],
            child: child,
          ),
        );
      },
      child: _buildActionCard(data, isLocked: isLocked),
    );
  }

  Widget _buildActionCard(_ActionData data, {required bool isLocked}) {
    final shortScreen = MediaQuery.sizeOf(context).height < 700;
    final cardPadding = shortScreen ? 14.0 : 20.0;
    final iconSize = shortScreen ? 44.0 : 52.0;
    final iconInnerSize = shortScreen ? 22.0 : 26.0;
    final fontSize = shortScreen ? 12.0 : 13.0;
    return _ScaleTapCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _runGated(data.feature, data.onTap);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: cardPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.cardBg.withValues(alpha: 0.85),
                  AppColors.cardBg.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: data.color.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: data.color.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isLocked)
                  Positioned(
                    top: 8,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: AppColors.primary,
                        size: 14,
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            data.color.withValues(alpha: 0.18),
                            data.color.withValues(alpha: 0.08),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        data.icon,
                        color: data.color,
                        size: iconInnerSize,
                      ),
                    ),
                    SizedBox(height: shortScreen ? 8 : 12),
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _runGated(PremiumFeature feature, VoidCallback action) {
    unawaited(() async {
      final allowed = await SubscriptionGate.ensureAccess(context, feature);
      if (!mounted || !allowed) return;
      action();
    }());
  }

  void _activateSiren() {
    HapticFeedback.heavyImpact();
    // Analytics removed (offline-first)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SirenDialog(),
    );
  }

  void _showSnack(String message, {Color backgroundColor = AppColors.primary}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Widget _buildSafetyTips() {
    final shortScreen = MediaQuery.sizeOf(context).height < 700;
    return Container(
      padding: EdgeInsets.all(shortScreen ? 14 : 20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: shortScreen ? 38 : 44,
            height: shortScreen ? 38 : 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tips_and_updates_rounded,
              color: AppColors.primary,
              size: shortScreen ? 18 : 22,
            ),
          ),
          SizedBox(width: shortScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "security_tip".tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "shake_phone_tip".tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper data class ──
class _ActionData {
  final String title;
  final IconData icon;
  final Color color;
  final PremiumFeature feature;
  final VoidCallback onTap;
  const _ActionData(
    this.title,
    this.icon,
    this.color,
    this.feature,
    this.onTap,
  );
}

// ── Scale-bounce tap card ──
class _ScaleTapCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleTapCard({required this.child, required this.onTap});

  @override
  State<_ScaleTapCard> createState() => _ScaleTapCardState();
}

class _ScaleTapCardState extends State<_ScaleTapCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
