// ============================================================================
// ANA NAVİGASYON - MODERN BOTTOM NAVIGATION BAR (PREMIUM)
// ============================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/motion.dart';
import '../core/services/reduced_motion_policy.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/permission_helper.dart';
// Firebase and notification services removed (offline-first)
import '../widgets/connectivity_banner.dart';
import 'home_page.dart';
import 'contacts_page.dart';
import 'map_page.dart';
import 'pin_setup_screen.dart';
import 'settings_page.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/emergency_session_contract.dart';
import '../core/services/pin_verification_service.dart';
import '../core/navigation/deep_link_channel.dart';
import '../core/navigation/destination_router.dart';
import '../core/navigation/pending_destination_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with
        SingleTickerProviderStateMixin,
        RestorationMixin,
        WidgetsBindingObserver {
  /// RESTORABLE ON PURPOSE: this is navigation state, and losing it is not
  /// cosmetic. A process death while the user is on Map (a live location
  /// share), Contacts (mid-edit) or Profile silently returns them to Home,
  /// which reads as "the app forgot what I was doing" at exactly the moment a
  /// safety app must not.
  ///
  /// Restoring the INDEX is safe in a way restoring ROUTES is not: the tab set
  /// lives inside [MainNavigation], which SplashScreen only builds after the
  /// PIN gate has been satisfied. Restored widget state cannot make a widget
  /// appear, so it cannot put anything above the unlock screen.
  final RestorableInt _restoredIndex = RestorableInt(0);

  int get _selectedIndex => _restoredIndex.value;
  set _selectedIndex(int value) => _restoredIndex.value = value;

  @override
  String? get restorationId => 'main_navigation';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restoredIndex, 'tab_index');
  }

  /// Tab requested but not yet shown: the swap happens at the fade trough, so
  /// the old page is never seen dissolving into the new one.
  int? _pendingIndex;

  bool _pinPromptVisible = false;
  bool _notificationPromptVisible = false;

  /// Drives one whole tab change across [Motion.base].
  late final AnimationController _tabFadeController;

  /// V-shaped: full opacity -> 0 at the midpoint -> full opacity. Tabs used to
  /// snap with no transition at all, which is the cheapest-feeling moment in
  /// the app. A fade-through is the Material answer and, unlike a slide, it
  /// implies no spatial relationship between four unrelated destinations.
  late final Animation<double> _tabFade;

  /// Whether the offline banner is currently occupying the top of the shell.
  ///
  /// Read from the SAME source the banner itself listens to
  /// ([ConnectivityService.instance]) rather than plumbed down from it: two
  /// widgets deriving one fact from one stream cannot disagree, whereas a
  /// callback from the banner to its parent could arrive a frame late and
  /// reintroduce exactly the overlap this reservation exists to remove.
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _isOffline = !ConnectivityService.instance.isOnline;
    _connectivitySubscription = ConnectivityService.instance.onStatusChange
        .listen((bool isOnline) {
          if (!mounted || isOnline == !_isOffline) return;
          setState(() => _isOffline = !isOnline);
        });
    _tabFadeController = AnimationController(
      vsync: this,
      duration: Motion.base,
      value: 1,
    );
    _tabFade = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Motion.exit)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Motion.enter)),
        weight: 1,
      ),
    ]).animate(_tabFadeController);
    _tabFadeController.addListener(_swapAtTrough);
    // Deep links are consumed HERE and nowhere earlier. This widget only exists
    // once SplashScreen has cleared consent, onboarding and the PIN gate, so
    // "a link cannot skip a gate" is a property of construction order rather
    // than of a conditional someone has to remember to write (MP-26-008).
    WidgetsBinding.instance.addObserver(this);
    PendingDestinationService.instance.addListener(_onPendingDestination);
    // Firebase services removed (offline-first)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupChecks();
      _collectAndRouteExternalEntry();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A link that arrives while the app is already running reaches
    // MainActivity.onNewIntent, which parks it natively; this is where it is
    // collected. Resume is also when a return from the PIN re-auth lock lands,
    // so a link received while locked is routed only now.
    if (state == AppLifecycleState.resumed) {
      unawaited(_collectAndRouteExternalEntry());
    }
  }

  void _onPendingDestination() {
    if (!mounted || !PendingDestinationService.instance.hasPending) return;
    unawaited(_routePending());
  }

  /// Asks the platform for a parked link, then routes whatever is pending.
  Future<void> _collectAndRouteExternalEntry() async {
    final uri = await DeepLinkChannel.consume();
    if (uri != null) {
      PendingDestinationService.instance.submitUri(uri);
    }
    await _routePending();
  }

  /// Single-consume: fifty rapid links leave one destination, and it fires once.
  bool _routing = false;

  Future<void> _routePending() async {
    if (_routing || !mounted) return;
    _routing = true;
    try {
      final accepted = PendingDestinationService.instance.consume();
      if (accepted == null || !mounted) return;
      await DestinationRouter.route(
        context,
        accepted.destination,
        selectTab: _selectTab,
      );
    } finally {
      _routing = false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PendingDestinationService.instance.removeListener(_onPendingDestination);
    _tabFadeController.removeListener(_swapAtTrough);
    _tabFadeController.dispose();
    _restoredIndex.dispose();
    super.dispose();
  }

  void _swapAtTrough() {
    final pending = _pendingIndex;
    if (pending == null || _tabFadeController.value < 0.5) return;
    _pendingIndex = null;
    setState(() => _selectedIndex = pending);
  }

  void _selectTab(int index) {
    if (index == _selectedIndex || _pendingIndex != null) return;
    HapticFeedback.lightImpact();
    // Reduce-motion gets the instant swap, which is what this used to be for
    // everyone. The haptic above is unaffected.
    if (ReducedMotionPolicy.isReduced(context)) {
      setState(() => _selectedIndex = index);
      return;
    }
    _pendingIndex = index;
    _tabFadeController.forward(from: 0);
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

  /// Same single verification path as SplashScreen: one owner for the legacy
  /// migration and the hashed storage format, and one meaning for a read
  /// failure (locked, not absent).
  Future<bool> _hasConfiguredPin() async {
    final state = await PinVerificationService.instance.loadState();
    if (state == PinState.configured) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefPinSetupDone, true);
      return true;
    }
    return state != PinState.absent;
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
          // The banner below is a Positioned OVERLAY, so it occupies no layout
          // space. Measured on an API 36 emulator 2026-08-16: with the banner
          // visible the top ~42 dp of every tab was covered -- on Home that hid
          // more than half of the "Hos Geldiniz" heading, and the same heading
          // rendered fully the moment the banner went away. The pages have to
          // reserve the space the overlay takes, and the reservation comes from
          // the banner's own constants so the two cannot drift apart.
          AnimatedPadding(
            duration: Motion.base,
            padding: EdgeInsets.only(
              top: _isOffline ? ConnectivityBanner.reservedHeight : 0,
            ),
            // IndexedStack is kept on purpose: every page stays in the tree, so
            // the crossfade costs no page state and MapPage's isActive contract
            // is unchanged -- it still flips exactly once per tab change, now at
            // the trough instead of on the tap.
            child: FadeTransition(
              opacity: _tabFade,
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  const HomePage(),
                  MapPage(isActive: _selectedIndex == 1),
                  const ContactsPage(),
                  const SettingsPage(),
                ],
              ),
            ),
          ),
          // Offline mode banner at top
          // No SafeArea: it was measuring a zero top inset here (an ancestor
          // had already consumed `padding`) and therefore did nothing, which
          // is how the banner ended up entirely under the status bar. The
          // banner now reads the unconsumed `viewPadding` itself.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ConnectivityBanner(),
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
      child: Semantics(
        button: true,
        label: label,
        selected: isSelected,
        container: true,
        child: GestureDetector(
          onTap: () => _selectTab(index),
          behavior: HitTestBehavior.opaque,
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: Motion.base,
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
                    duration: Motion.base,
                    curve: Motion.enter,
                    child: AnimatedSwitcher(
                      duration: Motion.base,
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
                    duration: Motion.base,
                    style: TextStyle(
                      fontSize: isSelected ? 12.5 : 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
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
                    duration: Motion.base,
                    curve: Curves.easeOutCubic,
                    width: isSelected ? 20 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
