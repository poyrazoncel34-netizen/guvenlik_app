// ============================================================================
// 🗺️ ACİL DURUM HARİTASI
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_colors.dart';
import '../core/di/service_locator.dart';
import '../core/services/location_service.dart';
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
      } else {
        _currentLocation ??= LocationService.defaultLocation;
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
        title: const Text("Acil Durum Haritası"),
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
          _buildMap(),
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
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showSnack(context, "Konum paylaşıldı");
                    },
                    icon: const Icon(Icons.share_location, color: Colors.white),
                    label: const Text(
                      "Konumu Paylaş",
                      style: TextStyle(color: Colors.white),
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
                    label: const Text(
                      "Acil Yardım",
                      style: TextStyle(color: Colors.white),
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
    final center = _currentLocation ?? LocationService.defaultLocation;
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
          userAgentPackageName: 'com.guvendeyim.app',
          maxZoom: 19,
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
