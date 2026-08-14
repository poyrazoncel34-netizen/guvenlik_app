// ============================================================================
// HARİTA SAYFASI - OPENSTREETMAP ENTEGRASYONU
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/config/app_environment.dart';
import '../core/di/service_locator.dart';
import '../core/network/osm_tile_cache_client.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/location_consent_gate.dart';
import '../core/services/location_service.dart';
import '../core/utils/map_utils.dart';
import '../domain/repositories/location_repository.dart';
import '../core/widgets/escape_dismissible.dart';
import '../core/design_tokens.dart';
import '../core/services/reduced_motion_policy.dart';
import '../core/utils/formatters.dart';

class MapPage extends StatefulWidget {
  final bool isActive;

  const MapPage({super.key, this.isActive = true});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  // Services
  final LocationRepository _locationRepository =
      serviceLocator<LocationRepository>();

  // Map controller
  final MapController _mapController = MapController();
  late final NetworkTileProvider _osmTileProvider;

  // State
  LatLng? _currentLocation;
  bool _isLoading = true;
  LocationStatus? _locationStatus;
  bool _usingFallbackLocation = false;
  DateTime? _fallbackCheckedAt;
  bool _hasRequestedInitialLocation = false;

  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _osmTileProvider = NetworkTileProvider(httpClient: OsmTileCacheClient());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isActive) {
      _initLocation();
    } else {
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive &&
        widget.isActive &&
        !_hasRequestedInitialLocation) {
      _initLocation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: see ReducedMotionPolicy.pulse for why a construction
    // cascade cannot honour a preference it is unable to read yet.
    final reduced = ReducedMotionPolicy.isReduced(context);
    ReducedMotionPolicy.pulse(_pulseController, reduced: reduced);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    unawaited(_osmTileProvider.dispose());
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (!mounted) return;
    _hasRequestedInitialLocation = true;
    setState(() {
      _isLoading = true;
    });

    final permissionGranted = await _ensureLocationPermission();
    if (!permissionGranted) return;

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
        _fallbackCheckedAt = null;
      } else {
        _usingFallbackLocation = true;
        _fallbackCheckedAt = DateTime.now();
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

    final permissionGranted = await _ensureLocationPermission();
    if (!permissionGranted) return;

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
        _fallbackCheckedAt = null;
      });
      _animateToLocation(result.position!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.white, size: IconSizes.action),
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
        setState(() {
          _usingFallbackLocation = true;
          _fallbackCheckedAt = DateTime.now();
        });
      } else if (mounted) {
        setState(() {
          _usingFallbackLocation = true;
          _fallbackCheckedAt = DateTime.now();
        });
      }
      _showPermissionError(result);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final granted = await LocationConsentGate.ensureAllowed(context);
    if (!mounted) return false;
    if (granted) return true;
    setState(() {
      _isLoading = false;
      _locationStatus = LocationStatus.permissionDenied;
      _usingFallbackLocation = _currentLocation == null;
      _fallbackCheckedAt = _currentLocation == null ? DateTime.now() : null;
    });
    return false;
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
      builder: (context) => EscapeDismissible(child: AlertDialog(
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
                size: IconSizes.feature,
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
      )),
    );
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
                child: Semantics(
                  label: 'OpenStreetMap copyright link',
                  button: true,
                  child: GestureDetector(
                    onTap: _openOsmCopyrightPage,
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
                        size: IconSizes.action,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "map_fallback_location".tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_fallbackCheckedAt != null)
                              Text(
                                'map_fallback_location_time'.tr(
                                  namedArgs: {
                                    'time': Formatters.clockHm(_fallbackCheckedAt!),
                                  },
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
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
        // OpenStreetMap tile layer — only shown when online for the viewport
        // the user actively views. Do not bulk download, pre-seed, scrape,
        // archive, or package public OSM tiles from this endpoint.
        TileLayer(
          urlTemplate: AppEnvironment.mapTileUrlTemplate,
          userAgentPackageName: kOsmUserAgentPackageName,
          tileProvider: _osmTileProvider,
          maxZoom: 19,
          errorTileCallback: (tile, error, stack) {
            // Silently ignore individual tile load failures (offline tolerance)
            debugPrint('MAP_TILE_LOAD_FAILED_REDACTED');
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
                boxShadow: Shadows.overlay,
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
          const Icon(Icons.map_rounded, color: AppColors.primary, size: IconSizes.dialog),
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
              const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                "map_loading_location".tr(),
                style: const TextStyle(
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
    final locationText = _currentLocation != null
        ? '${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}'
        : "map_location_unavailable".tr();
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
                  size: IconSizes.dialog,
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
                    const SizedBox(height: 2),
                    Text(
                      locationText,
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
        ),
      ],
    );
  }

  Future<void> _openOsmCopyrightPage() async {
    final uri = Uri.parse('https://www.openstreetmap.org/copyright');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      // Silent fallback — attribution remains visible as static text even
      // if no browser is available to open the copyright page.
    }
  }
}
