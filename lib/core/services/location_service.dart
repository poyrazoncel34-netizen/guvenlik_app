// ============================================================================
// KONUM SERVİSİ - GPS & İZİN YÖNETİMİ
// ============================================================================

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'resource_monitor_service.dart';

/// Konum servisi sonuç durumları
enum LocationStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

/// Konum sonucu
class LocationResult {
  final LocationStatus status;
  final LatLng? position;
  final String? errorMessage;

  LocationResult({required this.status, this.position, this.errorMessage});

  bool get isSuccess => status == LocationStatus.success && position != null;
}

/// Konum Servisi - Singleton
class LocationService {
  // Singleton instance
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Default location: Istanbul, Turkey
  static const LatLng defaultLocation = LatLng(41.0082, 28.9784);

  // Cache for last known position
  LatLng? _lastKnownPosition;
  LatLng get lastKnownPosition => _lastKnownPosition ?? defaultLocation;

  bool _lowBattery = false;
  StreamSubscription<bool>? _lowBatterySubscription;

  void initBatteryAwareness() {
    _lowBatterySubscription ??= ResourceMonitorService.instance.lowBatteryStream
        .listen((isLow) => _lowBattery = isLow);
  }

  /// Konum servisinin aktif olup olmadığını kontrol eder
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Konum izni durumunu kontrol eder
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Konum izni ister
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// İzinleri kontrol edip gerekirse ister
  Future<LocationResult> _handlePermissions() async {
    // Konum servisi aktif mi?
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult(
        status: LocationStatus.serviceDisabled,
        errorMessage: 'location_error_service_disabled'.tr(),
      );
    }

    // İzin durumunu kontrol et
    LocationPermission permission = await checkPermission();

    if (permission == LocationPermission.denied) {
      // İzin iste
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult(
          status: LocationStatus.permissionDenied,
          errorMessage: 'location_error_permission_denied'.tr(),
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult(
        status: LocationStatus.permissionDeniedForever,
        errorMessage: 'location_error_permission_forever'.tr(),
      );
    }

    // İzin verildi
    return LocationResult(status: LocationStatus.success);
  }

  /// Mevcut konumu alır
  Future<LocationResult> getCurrentLocation({bool highAccuracy = true}) async {
    try {
      // İzinleri kontrol et
      final permissionResult = await _handlePermissions();
      if (!permissionResult.isSuccess &&
          permissionResult.status != LocationStatus.success) {
        return permissionResult;
      }

      // Konum al — pil düşükse doğruluk düşürülür
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: (_lowBattery || !highAccuracy)
              ? LocationAccuracy.medium
              : LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      _lastKnownPosition = latLng;

      return LocationResult(status: LocationStatus.success, position: latLng);
    } on TimeoutException {
      // GPS timeout — fall back to cached position instead of blocking emergency
      if (_lastKnownPosition != null) {
        return LocationResult(
          status: LocationStatus.success,
          position: _lastKnownPosition,
        );
      }
      return LocationResult(
        status: LocationStatus.error,
        errorMessage: 'location_error_failed'.tr(),
      );
    } catch (e) {
      return LocationResult(
        status: LocationStatus.error,
        errorMessage: '${'location_error_failed'.tr()}: ${e.toString()}',
      );
    }
  }

  /// Son bilinen konumu alır (daha hızlı, ama eski olabilir)
  Future<LocationResult> getLastKnownLocation() async {
    try {
      // İzinleri kontrol et
      final permissionResult = await _handlePermissions();
      if (!permissionResult.isSuccess &&
          permissionResult.status != LocationStatus.success) {
        return permissionResult;
      }

      final position = await Geolocator.getLastKnownPosition();

      if (position != null) {
        final latLng = LatLng(position.latitude, position.longitude);
        _lastKnownPosition = latLng;

        return LocationResult(status: LocationStatus.success, position: latLng);
      }

      // Son konum yoksa mevcut konumu al
      return getCurrentLocation();
    } catch (e) {
      return LocationResult(
        status: LocationStatus.error,
        errorMessage: 'Konum alınamadı: ${e.toString()}',
      );
    }
  }

  /// Konum değişikliklerini dinle (stream)
  Stream<Position>? getPositionStream({
    bool highAccuracy = true,
    int distanceFilter = 10, // metre
  }) {
    try {
      return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: highAccuracy
              ? LocationAccuracy.high
              : LocationAccuracy.medium,
          distanceFilter: distanceFilter,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// İki nokta arasındaki mesafeyi hesaplar (metre)
  double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Uygulama ayarlarını aç (izin için)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Konum ayarlarını aç
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
