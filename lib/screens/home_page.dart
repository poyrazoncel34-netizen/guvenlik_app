// ============================================================================
// ANA SAYFA (İSTATİSTİKLER VE YENİ ÖZELLİKLER EKLENDİ)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/services/shake_detector_service.dart';
import '../core/services/audio_recorder_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/analytics_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../presentation/providers/home_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../widgets/panic_button.dart';
import '../widgets/siren_dialog.dart';
import 'fake_call_screen.dart';
import 'contacts_page.dart';
import 'countdown_screen.dart';
import 'safe_walk_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _headerController;
  final ShakeDetectorService _shakeDetector = ShakeDetectorService();
  bool _isRecording = false;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _headerController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().initialize();
      _initShakeDetection();
      _initConnectivity();
    });
    AnalyticsService.logScreenView('home');
  }

  void _initShakeDetection() {
    _shakeDetector.startListening(
      onShakeDetected: () {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        AnalyticsService.logShakeDetected();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CountdownScreen()),
        );
      },
    );
  }

  void _initConnectivity() {
    ConnectivityService.instance.initialize();
    _connectivitySubscription = ConnectivityService.instance.onStatusChange
        .listen((online) {
          if (mounted) {
            setState(() => _isOffline = !online);
            if (!online) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "no_internet_connection".tr(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.warning,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        });
  }

  Future<void> _toggleRecording() async {
    final recorder = AudioRecorderService.instance;
    if (_isRecording) {
      final path = await recorder.stopRecording();
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              path != null ? "recording_saved".tr() : "recording_failed".tr(),
            ),
            backgroundColor: path != null
                ? AppColors.success
                : AppColors.emergency,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } else {
      final started = await recorder.startRecording();
      if (mounted) {
        setState(() => _isRecording = started);
        if (started) {
          AnalyticsService.logAudioRecordingStarted();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("microphone_permission_required".tr()),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _headerController.dispose();
    _shakeDetector.dispose();
    super.dispose();
  }

  void _showMessageTemplates(BuildContext context, HomeProvider provider) {
    final templates = [
      "help_needed_template".tr(),
      "unsafe_template".tr(),
      "emergency_template".tr(),
      "harassment_template".tr(),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.message_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Text("quick_message_dialog_title".tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: templates.map((text) {
            return ListTile(
              title: Text(text, style: const TextStyle(fontSize: 14)),
              trailing: const Icon(
                Icons.send_rounded,
                color: AppColors.primary,
              ),
              onTap: () async {
                Navigator.pop(context);
                final message = await provider.sendQuickMessage(text);
                if (message != null && context.mounted) {
                  _showSnack(message);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            const SizedBox(height: 16),
            Text(
              "notifications".tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            _buildNotificationItem(
              "security_check".tr(),
              "daily_check_complete".tr(),
              Icons.check_circle,
              const Color(0xFF34C759),
            ),
            _buildNotificationItem(
              "location_update".tr(),
              "location_shared".tr(),
              Icons.location_on,
              const Color(0xFF007AFF),
            ),
            _buildNotificationItem(
              "system_notification".tr(),
              "new_features_added".tr(),
              Icons.new_releases,
              const Color(0xFFFF9500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final pendingMessage = provider.takeMessage();
    if (pendingMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnack(pendingMessage);
      });
    }
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final horizontalPadding = size.width > 400 ? 24.0 : (size.width > 340 ? 20.0 : 16.0);
    final shortScreen = size.height < 700;
    final spacing = shortScreen ? 8.0 : 14.0;
    final sectionSpacing = shortScreen ? 12.0 : 20.0;
    final largeSectionSpacing = shortScreen ? 16.0 : 24.0;
    // Space for FAB + bottom nav so content doesn't sit under the button
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
                      if (_isOffline) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                color: AppColors.warning,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "offline_mode_warning".tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: spacing),
                      ],
                      if (_isRecording) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.emergency.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.emergency.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.emergency,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "recording_active".tr(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.emergency,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _toggleRecording,
                                child: Text(
                                  "stop".tr(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.emergency,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: spacing),
                      ],
                      SizedBox(height: shortScreen ? 4 : 6),
                      _buildEmergencyContactChip(provider),
                      SizedBox(height: spacing),
                      _buildReadinessCard(provider),
                      if (!provider.onboardingDismissed) ...[
                        SizedBox(height: shortScreen ? 10 : 16),
                        _buildOnboardingCard(provider),
                      ],
                      SizedBox(height: sectionSpacing),
                      const Center(child: PanicButton()),
                      SizedBox(height: spacing),
                      _buildTestModeButton(),
                      SizedBox(height: largeSectionSpacing),
                      _buildQuickActions(),
                      SizedBox(height: largeSectionSpacing),
                      _buildLocationCard(provider),
                      SizedBox(height: largeSectionSpacing),
                      _buildSafetyTips(),
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
    final settingsProvider = context.watch<SettingsProvider>();
    final displayName = settingsProvider.hasProfile
        ? settingsProvider.profileName
        : 'user'.tr();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "hello".tr(),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _showNotifications(context);
              },
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.emergency,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
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
      onTap: _openContacts,
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
                    hasContact ? "emergency_contact_ready".tr() : "emergency_contact_not_selected".tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasContact ? "$name • $phone" : "tap_to_select_contact".tr(),
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

  Widget _buildReadinessCard(HomeProvider provider) {
    final allReady =
        provider.locationPermissionGranted &&
        provider.contactsPermissionGranted &&
        provider.emergencyContact != null;
    final title = allReady ? "ready".tr() : "setup_incomplete".tr();
    final subtitle = allReady
        ? "system_ready_desc".tr()
        : "setup_incomplete_desc".tr();

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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (allReady ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allReady
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color: allReady ? AppColors.success : AppColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
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
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                label: "location".tr(),
                isOk: provider.locationPermissionGranted,
                onTap: _requestLocationPermission,
              ),
              _buildStatusChip(
                label: "contacts".tr(),
                isOk: provider.contactsPermissionGranted,
                onTap: _requestContactsPermission,
              ),
              _buildStatusChip(
                label: "emergency_contact".tr(),
                isOk: provider.emergencyContact != null,
                onTap: _openContacts,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required bool isOk,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (isOk ? AppColors.success : AppColors.warning).withValues(
            alpha: 0.12,
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (isOk ? AppColors.success : AppColors.warning).withValues(
              alpha: 0.3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 14,
              color: isOk ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isOk ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    final provider = context.read<HomeProvider>();
    final message = await provider.requestLocationPermission(context: context);
    if (message != null && mounted) _showSnack(message);
  }

  Future<void> _requestContactsPermission() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Rehber izni web üzerinde desteklenmiyor."),
        ),
      );
      return;
    }
    final provider = context.read<HomeProvider>();
    final message = await provider.requestContactsPermission();
    if (message != null && context.mounted) {
      _showSnack(message);
    }
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
            onTap: _openContacts,
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

  void _startTestMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CountdownScreen(isTestMode: true),
      ),
    );
  }

  Future<void> _openContacts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactsPage()),
    );
    if (!mounted) return;
    await context.read<HomeProvider>().refreshAfterContactsChanged();
  }

  Widget _buildQuickActions() {
    final provider = context.read<HomeProvider>();
    final shortScreen = MediaQuery.sizeOf(context).height < 700;
    final gap = shortScreen ? 10.0 : 14.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "quick_actions".tr(),
          style: TextStyle(
            fontSize: shortScreen ? 18 : 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                "fake_call".tr(),
                Icons.phone_in_talk_rounded,
                AppColors.primary,
                () {
                  AnalyticsService.logFakeCallUsed();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FakeCallScreen()),
                  );
                },
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildActionCard(
                "siren".tr(),
                Icons.notifications_active_rounded,
                AppColors.warning,
                _activateSiren,
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                "safe_walk".tr(),
                Icons.directions_walk_rounded,
                AppColors.accent,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SafeWalkScreen()),
                  );
                },
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildActionCard(
                _isRecording ? "stop_recording".tr() : "voice_record".tr(),
                _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                _isRecording ? AppColors.emergency : const Color(0xFF9B59B6),
                _toggleRecording,
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                "quick_message".tr(),
                Icons.message_rounded,
                AppColors.success,
                () => _showMessageTemplates(context, provider),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildActionCard(
                "contacts".tr(),
                Icons.people_rounded,
                AppColors.info,
                _openContacts,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final shortScreen = MediaQuery.sizeOf(context).height < 700;
    final padding = shortScreen ? 14.0 : 20.0;
    final iconSize = shortScreen ? 44.0 : 52.0;
    final iconInnerSize = shortScreen ? 22.0 : 26.0;
    final fontSize = shortScreen ? 12.0 : 13.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: padding),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: iconInnerSize),
              ),
              SizedBox(height: shortScreen ? 8 : 12),
              Text(
                title,
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
        ),
      ),
    );
  }

  void _activateSiren() {
    HapticFeedback.heavyImpact();
    AnalyticsService.logSirenActivated();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SirenDialog(),
    );
  }

  Widget _buildLocationCard(HomeProvider provider) {
    final shortScreen = MediaQuery.sizeOf(context).height < 700;
    return Container(
      padding: EdgeInsets.all(shortScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: shortScreen ? 42 : 48,
            height: shortScreen ? 42 : 48,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: AppColors.info,
              size: shortScreen ? 20 : 24,
            ),
          ),
          SizedBox(width: shortScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "location_sharing".tr(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.isLocationSharing
                      ? provider.locationShareEndAt != null
                            ? "${"sharing".tr()} • ${_formatRemaining(provider.locationShareEndAt)}"
                            : "your_location_is_sharing".tr()
                      : "share_location_with_network".tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: provider.isLocationSharing,
              onChanged: (value) {
                if (value) {
                  _showLocationShareOptions();
                } else {
                  provider.stopLocationSharing(manual: true);
                }
              },
              activeThumbColor: AppColors.info,
              activeTrackColor: AppColors.info.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              "location_share_duration".tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildShareOption("minutes_10".tr(), 10),
            _buildShareOption("minutes_30".tr(), 30),
            _buildShareOption("hour_1".tr(), 60),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(String label, int minutes) {
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
      onTap: () {
        Navigator.pop(context);
        _startLocationSharing(minutes);
      },
    );
  }

  Future<void> _startLocationSharing(int minutes) async {
    final provider = context.read<HomeProvider>();
    HapticFeedback.lightImpact();
    final message = await provider.startLocationSharing(minutes);
    if (message != null && context.mounted) {
      provider.stopLocationSharing(manual: true);
      _showSnack(message);
    }
  }

  String _formatRemaining(DateTime? endAt) {
    if (endAt == null) return "";
    final remaining = endAt.difference(DateTime.now());
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    if (minutes <= 0) {
      return "${seconds}s";
    }
    return "${minutes}dk ${seconds}s";
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
