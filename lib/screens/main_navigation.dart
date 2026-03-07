// ============================================================================
// ANA NAVİGASYON - MODERN BOTTOM NAVIGATION BAR (PREMIUM)
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/utils/permission_helper.dart';
// Firebase and notification services removed (offline-first)
import '../widgets/connectivity_banner.dart';
import 'home_page.dart';
import 'contacts_page.dart';
import 'map_page.dart';
import 'pin_setup_screen.dart';
import 'settings_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fabController;
  late Animation<double> _fabScale;
  bool _pinPromptVisible = false;
  bool _notificationPromptVisible = false;

  final List<Widget> _pages = const [
    HomePage(),
    MapPage(),
    ContactsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Firebase services removed (offline-first)

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );
    // Delay FAB entrance
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fabController.forward();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupChecks();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  // Firebase services removed (offline-first architecture)

  Future<void> _makeCall(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $uri: $e');
    }
  }

  Future<void> _ensurePinSetup() async {
    if (!mounted || _pinPromptVisible) return;

    final hasPin = await _hasConfiguredPin();
    if (!mounted || hasPin) return;

    _pinPromptVisible = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PinSetupScreen(requiredSetup: true),
      ),
    );
    _pinPromptVisible = false;
  }

  Future<void> _runStartupChecks() async {
    await _ensurePinSetup();
    await _ensureNotificationPermission();
  }

  Future<bool> _hasConfiguredPin() async {
    final secureStorage = serviceLocator<SecureStorage>();
    final securePin = await secureStorage.read(key: SecureStorageKeys.userPin);
    if (securePin != null && securePin.isNotEmpty) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyPin = prefs.getString(SecureStorageKeys.userPin);
    if (legacyPin == null || legacyPin.isEmpty) {
      return false;
    }

    await secureStorage.write(key: SecureStorageKeys.userPin, value: legacyPin);
    await prefs.remove(SecureStorageKeys.userPin);
    await prefs.setBool(AppConstants.prefPinSetupDone, true);
    return true;
  }

  Future<void> _ensureNotificationPermission() async {
    if (!mounted || _notificationPromptVisible) return;

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool(AppConstants.prefNotifications) ?? true;
    if (!notificationsEnabled) return;

    final alreadyPrompted =
        prefs.getBool(AppConstants.prefNotificationPermissionPrompted) ?? false;
    final alreadyGranted = await PermissionHelper.hasNotificationPermission();
    if (alreadyGranted) {
      await prefs.setBool(
        AppConstants.prefNotificationPermissionPrompted,
        true,
      );
      return;
    }
    if (alreadyPrompted) return;

    _notificationPromptVisible = true;
    try {
      if (!mounted) return;
      await PermissionHelper.requestNotificationPermission(context);
      await prefs.setBool(
        AppConstants.prefNotificationPermissionPrompted,
        true,
      );
    } finally {
      _notificationPromptVisible = false;
    }
  }

  void _showQuickHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
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
            const SizedBox(height: 20),
            Text(
              "how_can_we_help".tr(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _buildHelpOption(
              icon: Icons.local_police_rounded,
              color: AppColors.info,
              title: "call_police".tr(),
              subtitle: AppConstants.turkeyEmergencyNumber,
              onTap: () {
                Navigator.pop(context);
                _makeCall(AppConstants.turkeyEmergencyNumber);
              },
            ),
            const SizedBox(height: 12),
            _buildHelpOption(
              icon: Icons.medical_services_rounded,
              color: AppColors.emergency,
              title: "call_ambulance".tr(),
              subtitle: AppConstants.turkeyEmergencyNumber,
              onTap: () {
                Navigator.pop(context);
                _makeCall(AppConstants.turkeyEmergencyNumber);
              },
            ),
            const SizedBox(height: 12),
            _buildHelpOption(
              icon: Icons.fire_truck_rounded,
              color: AppColors.warning,
              title: "call_fire".tr(),
              subtitle: AppConstants.turkeyEmergencyNumber,
              onTap: () {
                Navigator.pop(context);
                _makeCall(AppConstants.turkeyEmergencyNumber);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(
                  Icons.call_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: _pages),
          // Offline mode banner at top
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: ConnectivityBanner(),
            ),
          ),
        ],
      ),
      // Floating Action Button - Only on Home screen
      floatingActionButton: _selectedIndex == 0
          ? ScaleTransition(
              scale: _fabScale,
              child: FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _showQuickHelp(context);
                },
                backgroundColor: AppColors.emergency,
                elevation: 8,
                icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                label: Text(
                  "quick_help".tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // ── Modern Frosted Glass Bottom Navigation Bar ──
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: AppColors.glassBorder.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      index: 0,
                      iconOff: Icons.home_outlined,
                      iconOn: Icons.home_rounded,
                      label: "nav_home".tr(),
                    ),
                    _buildNavItem(
                      index: 1,
                      iconOff: Icons.map_outlined,
                      iconOn: Icons.map_rounded,
                      label: "nav_map".tr(),
                    ),
                    _buildNavItem(
                      index: 2,
                      iconOff: Icons.people_outline_rounded,
                      iconOn: Icons.people_rounded,
                      label: "nav_contacts".tr(),
                    ),
                    _buildNavItem(
                      index: 3,
                      iconOff: Icons.settings_outlined,
                      iconOn: Icons.settings_rounded,
                      label: "nav_settings".tr(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData iconOff,
    required IconData iconOn,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Animated icon with scale ──
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    isSelected ? iconOn : iconOff,
                    key: ValueKey('${index}_$isSelected'),
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // ── Animated text ──
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: isSelected ? 12.5 : 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  letterSpacing: -0.2,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 3),
              // ── Animated pill indicator ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: isSelected ? 20 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
