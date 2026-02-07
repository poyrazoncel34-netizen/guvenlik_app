// ============================================================================
// ANA NAVİGASYON - MODERN BOTTOM NAVIGATION BAR
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/services/firebase_service.dart';
import '../core/services/notification_service.dart';
import 'home_page.dart';
import 'contacts_page.dart';
import 'map_page.dart';
import 'settings_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    MapPage(),
    ContactsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _initFirebaseServices();
  }

  Future<void> _initFirebaseServices() async {
    await NotificationService.instance.initialize();
    await FirebaseService.instance.upsertUserProfile();
    FirebaseService.instance.listenForTokenUpdates();
  }

  void _showQuickHelp(BuildContext context) {
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
            const SizedBox(height: 20),
            const Text(
              "Nasıl Yardımcı Olabiliriz?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            _buildHelpOption(
              icon: Icons.local_police_rounded,
              color: AppColors.info,
              title: "Polisi Ara",
              subtitle: "155",
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            _buildHelpOption(
              icon: Icons.medical_services_rounded,
              color: AppColors.emergency,
              title: "Ambulans Çağır",
              subtitle: "112",
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            _buildHelpOption(
              icon: Icons.fire_truck_rounded,
              color: AppColors.warning,
              title: "İtfaiye",
              subtitle: "110",
              onTap: () => Navigator.pop(context),
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
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      // Floating Action Button - Only on Home screen
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showQuickHelp(context);
              },
              backgroundColor: AppColors.emergency,
              elevation: 8,
              icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
              label: const Text(
                "Hızlı Yardım",
                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // Modern Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.surface : AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  iconOff: Icons.home_outlined,
                  iconOn: Icons.home_rounded,
                  label: "Ana Sayfa",
                ),
                _buildNavItem(
                  index: 1,
                  iconOff: Icons.map_outlined,
                  iconOn: Icons.map_rounded,
                  label: "Harita",
                ),
                _buildNavItem(
                  index: 2,
                  iconOff: Icons.people_outline_rounded,
                  iconOn: Icons.people_rounded,
                  label: "Kişiler",
                ),
                _buildNavItem(
                  index: 3,
                  iconOff: Icons.settings_outlined,
                  iconOn: Icons.settings_rounded,
                  label: "Ayarlar",
                ),
              ],
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: isDarkMode ? 0.2 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? iconOn : iconOff,
                  key: ValueKey(isSelected),
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  letterSpacing: -0.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
