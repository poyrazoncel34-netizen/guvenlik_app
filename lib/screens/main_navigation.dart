// ============================================================================
// ANA NAVİGASYON - MODERN BOTTOM NAVIGATION BAR (PREMIUM)
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupChecks();
    });
  }

  // Firebase services removed (offline-first architecture)

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
            child: SafeArea(bottom: false, child: ConnectivityBanner()),
          ),
        ],
      ),
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
