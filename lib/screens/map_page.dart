// ============================================================================
// HARİTA SAYFASI - OPENSTREETMAP ENTEGRASYONU
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/di/service_locator.dart';
import '../core/widgets/feature_warning_dialog.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/location_service.dart';
import '../core/utils/permission_helper.dart';
import '../core/utils/map_utils.dart';
import '../presentation/providers/home_provider.dart';
import '../domain/repositories/location_repository.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  // Services
  final LocationRepository _locationRepository =
      serviceLocator<LocationRepository>();

  // Map controller
  final MapController _mapController = MapController();

  // State
  LatLng? _currentLocation;
  bool _isLoading = true;
  LocationStatus? _locationStatus;
  bool _usingFallbackLocation = false;

  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Get location on init
    _initLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // First try to get last known location (faster)
    final lastKnown = await _locationRepository.getLastKnownLocation();

    if (!mounted) return;
    if (lastKnown.isSuccess && lastKnown.position != null) {
      setState(() {
        _currentLocation = lastKnown.position;
        _locationStatus = lastKnown.status;
      });
    }

    // Then get current location (more accurate)
    final result = await _locationRepository.getCurrentLocation();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _locationStatus = result.status;

      if (result.isSuccess && result.position != null) {
        _currentLocation = result.position;
        _usingFallbackLocation = false;
      } else {
        _usingFallbackLocation = _currentLocation == null;
      }
    });

    // Animate to location if map is ready
    if (_currentLocation != null) {
      _animateToLocation(_currentLocation!);
    }
  }

  void _animateToLocation(LatLng location, {double zoom = 16.0}) {
    try {
      _mapController.move(location, zoom);
    } catch (e) {
      // Map might not be ready yet
    }
  }

  Future<void> _centerOnMyLocation() async {
    HapticFeedback.lightImpact();

    setState(() => _isLoading = true);

    final result = await _locationRepository.getCurrentLocation();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _locationStatus = result.status;
    });

    if (result.isSuccess && result.position != null) {
      setState(() {
        _currentLocation = result.position;
        _usingFallbackLocation = false;
      });
      _animateToLocation(result.position!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  "map_location_updated".tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted && _currentLocation == null) {
        setState(() => _usingFallbackLocation = true);
      }
      _showPermissionError(result);
    }
  }

  void _showPermissionError(LocationResult result) {
    if (!mounted) return;
    String title;
    String message;
    String buttonText;
    VoidCallback onPressed;

    switch (result.status) {
      case LocationStatus.serviceDisabled:
        title = "map_location_off".tr();
        message = "map_permission_message".tr();
        buttonText = "map_open_settings".tr();
        onPressed = () {
          Navigator.pop(context);
          _locationRepository.openLocationSettings();
        };
        break;
      case LocationStatus.permissionDenied:
        title = "map_permission_required".tr();
        message = "map_permission_message".tr();
        buttonText = "map_grant_permission".tr();
        onPressed = () {
          Navigator.pop(context);
          _initLocation();
        };
        break;
      case LocationStatus.permissionDeniedForever:
        title = "map_permission_denied".tr();
        message = "map_permission_message".tr();
        buttonText = "map_go_settings".tr();
        onPressed = () {
          Navigator.pop(context);
          _locationRepository.openAppSettings();
        };
        break;
      default:
        title = "map_location_failed".tr();
        message = result.errorMessage ?? "map_permission_message".tr();
        buttonText = "map_retry".tr();
        onPressed = () {
          Navigator.pop(context);
          _initLocation();
        };
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 36,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "map_cancel".tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLocationSharing(HomeProvider provider) async {
    HapticFeedback.mediumImpact();
    if (provider.isLocationSharing) {
      provider.stopLocationSharing(manual: true);
      return;
    }
    final ok = await FeatureWarningHelper.showIfNeeded(
      context,
      prefKey: AppConstants.prefWarningLocation,
      featureName: 'location_sharing',
      title: FeatureWarningHelper.locationTitle,
      content: FeatureWarningHelper.locationContent,
    );
    if (!ok || !mounted) return;
    _showLocationShareOptions(provider);
  }

  void _showLocationShareOptions(HomeProvider provider) {
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
            _buildShareOption(provider, "minutes_10".tr(), 10),
            _buildShareOption(provider, "minutes_30".tr(), 30),
            _buildShareOption(provider, "hour_1".tr(), 60),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(HomeProvider provider, String label, int minutes) {
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
        _startLocationSharing(provider, minutes);
      },
    );
  }

  Future<void> _startLocationSharing(HomeProvider provider, int minutes) async {
    final notificationsAllowed =
        await PermissionHelper.requestNotificationPermission(context);
    if (!notificationsAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("notification_session_permission_required".tr()),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }
    await provider.startLocationSharing(minutes);
  }

  bool get _shouldUseOfflineMapFallback {
    return shouldUseOfflineMapFallback(
      isOnline: ConnectivityService.instance.isOnline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "semantics_map_page".tr(),
      hint: "semantics_map_page_hint".tr(),
      child: Scaffold(
        body: Stack(
          children: [
            // Map
            _shouldUseOfflineMapFallback
                ? _buildOfflineMapSurface()
                : _buildMap(),
            if (!_shouldUseOfflineMapFallback)
              Positioned(
                left: 12,
                bottom: 130,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "© OpenStreetMap contributors",
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ),

            // Top gradient for status bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).padding.top + 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // App bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: _buildCustomAppBar(),
            ),

            // Loading overlay
            if (_isLoading) _buildLoadingOverlay(),

            // Fallback location warning
            if (_usingFallbackLocation)
              Positioned(
                bottom: 220,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "map_fallback_location".tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom controls
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _buildBottomControls(),
            ),

            // My location FAB
            Positioned(bottom: 200, right: 16, child: _buildMyLocationFab()),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final center = _currentLocation ?? LocationService.fallbackMapCenter;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15.0,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // OpenStreetMap tile layer — only shown when online
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: kOsmUserAgentPackageName,
          maxZoom: 19,
          errorTileCallback: (tile, error, stack) {
            // Silently ignore individual tile load failures (offline tolerance)
            debugPrint('TileLayer error (ignored): $error');
          },
        ),

        // My location marker
        if (_currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation!,
                width: 120,
                height: 120,
                child: _buildMyLocationMarker(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildOfflineMapSurface() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF102435), Color(0xFF0A1B2A)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_searching_rounded,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "no_internet_connection".tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "offline_mode_warning".tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "location".tr(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_currentLocation != null)
                          Text(
                            "map_location_available".tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          )
                        else
                          Text(
                            "map_location_unavailable".tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                      ],
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

  Widget _buildMyLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse animation (accuracy circle simulation)
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 80 + (_pulseController.value * 30),
              height: 80 + (_pulseController.value * 30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(
                  alpha: 0.15 - (_pulseController.value * 0.1),
                ),
              ),
            );
          },
        ),

        // Inner accuracy circle
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),

        // Location dot
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomAppBar() {
    final provider = context.watch<HomeProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.map_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "map_title".tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Location sharing indicator
          if (provider.isLocationSharing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.share_location,
                    color: AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "map_live".tr(),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              SizedBox(height: 16),
              Text(
                "map_loading_location".tr(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyLocationFab() {
    return FloatingActionButton(
      heroTag: "my_location",
      onPressed: _centerOnMyLocation,
      backgroundColor: AppColors.cardBg,
      elevation: 4,
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : const Icon(Icons.my_location_rounded, color: AppColors.primary),
    );
  }

  Widget _buildBottomControls() {
    final provider = context.watch<HomeProvider>();
    return Column(
      children: [
        // Status card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _locationStatus == LocationStatus.success
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _locationStatus == LocationStatus.success
                      ? Icons.shield_rounded
                      : Icons.location_searching_rounded,
                  color: _locationStatus == LocationStatus.success
                      ? AppColors.success
                      : AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "map_location".tr(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // Sharing toggle
              IconButton(
                onPressed: () => _toggleLocationSharing(provider),
                icon: Icon(
                  provider.isLocationSharing
                      ? Icons.share_location
                      : Icons.location_disabled_outlined,
                  color: provider.isLocationSharing
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
