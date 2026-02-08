// ============================================================================
// KONUM SERVİSİ - GPS & İZİN YÖNETİMİ
// ============================================================================

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
        errorMessage: 'Konum servisi kapalı. Lütfen ayarlardan açın.',
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
          errorMessage: 'Konum izni reddedildi.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult(
        status: LocationStatus.permissionDeniedForever,
        errorMessage:
            'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.',
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

      // Konum al
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: highAccuracy
              ? LocationAccuracy.high
              : LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      _lastKnownPosition = latLng;

      return LocationResult(status: LocationStatus.success, position: latLng);
    } catch (e) {
      return LocationResult(
        status: LocationStatus.error,
        errorMessage: 'Konum alınamadı: ${e.toString()}',
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
