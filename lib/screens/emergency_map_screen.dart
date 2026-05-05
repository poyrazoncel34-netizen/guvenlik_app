// ============================================================================
// 🗺️ ACİL DURUM HARİTASI
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/di/service_locator.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/location_service.dart';
import '../core/utils/map_utils.dart';
import '../presentation/providers/home_provider.dart';
import '../domain/repositories/location_repository.dart';
import 'countdown_screen.dart';

class EmergencyMapScreen extends StatefulWidget {
  const EmergencyMapScreen({super.key});

  @override
  State<EmergencyMapScreen> createState() => _EmergencyMapScreenState();
}

class _EmergencyMapScreenState extends State<EmergencyMapScreen> {
  final LocationRepository _locationRepository =
      serviceLocator<LocationRepository>();
  final MapController _mapController = MapController();

  LatLng? _currentLocation;
  bool _isLoading = true;

  bool get _shouldUseOfflineMapFallback {
    return shouldUseOfflineMapFallback(
      isOnline: ConnectivityService.instance.isOnline,
    );
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() => _isLoading = true);
    final lastKnown = await _locationRepository.getLastKnownLocation();
    if (lastKnown.isSuccess && lastKnown.position != null) {
      setState(() => _currentLocation = lastKnown.position);
    }

    final result = await _locationRepository.getCurrentLocation();
    setState(() {
      _isLoading = false;
      if (result.isSuccess && result.position != null) {
        _currentLocation = result.position;
      }
    });

    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("emergency_map_title".tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _initLocation();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _shouldUseOfflineMapFallback
              ? _buildOfflineMapSurface()
              : _buildMap(),
          if (!_shouldUseOfflineMapFallback)
            Positioned(left: 12, bottom: 92, child: _buildOsmAttribution()),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final provider = context.read<HomeProvider>();
                      final started = await provider.startLocationSharing(10);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            started
                                ? "home_location_shared_desc".tr(
                                    namedArgs: const {'minutes': '10'},
                                  )
                                : "location_sharing_start_failed".tr(),
                          ),
                          backgroundColor: started
                              ? AppColors.success
                              : AppColors.warning,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_location, color: Colors.white),
                    label: Text(
                      "emergency_map_share_btn".tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CountdownScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.sos, color: Colors.white),
                    label: Text(
                      "emergency_map_help".tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergency,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final center = _currentLocation ?? LocationService.fallbackMapCenter;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        minZoom: 3,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: kOsmUserAgentPackageName,
          maxZoom: 19,
          errorTileCallback: (tile, error, stack) {
            // Silently ignore individual tile load failures (offline tolerance)
            debugPrint('TileLayer error (ignored): $error');
          },
        ),
        if (_currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation!,
                width: 60,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                ),
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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.emergency.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.gps_not_fixed_rounded,
                      color: AppColors.emergency,
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
                      color: AppColors.emergency.withValues(alpha: 0.08),
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

  Widget _buildOsmAttribution() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        "© OpenStreetMap contributors",
        style: TextStyle(fontSize: 10, color: Colors.white70),
      ),
    );
  }
}
