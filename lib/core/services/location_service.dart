import 'package:flutter/foundation.dart';
// ============================================================================
// KONUM SERVİSİ - GPS & İZİN YÖNETİMİ
// ============================================================================

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Konum servisi sonuç durumları
enum LocationStatus {
  success,
  stale,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

enum LocationSource { current, lastKnown, none }

/// Konum sonucu
class LocationResult {
  final LocationStatus status;
  final LatLng? position;
  final String? errorMessage;
  final DateTime? measuredAt;
  final LocationSource source;
  bool get isCurrent => isSuccess && source == LocationSource.current;

  LocationResult({
    required this.status,
    this.position,
    this.errorMessage,
    this.measuredAt,
    this.source = LocationSource.none,
  });

  bool get isSuccess => status == LocationStatus.success && position != null;
}

/// Konum Servisi - Singleton
class LocationService {
  // Singleton instance
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// An isolated in-memory cache for deterministic platform-boundary tests.
  @visibleForTesting
  LocationService.forTesting();

  // Neutral map viewport center. This is never presented as the user's location.
  static const LatLng fallbackMapCenter = LatLng(39.0, 35.0);

  // Cache for last known position
  LatLng? _lastKnownPosition;
  DateTime? _lastMeasuredAt;
  LatLng? get lastKnownPosition => _lastKnownPosition;

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
          accuracy: highAccuracy
              ? LocationAccuracy.high
              : LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      _lastKnownPosition = latLng;
      _lastMeasuredAt = position.timestamp;

      return LocationResult(
        status: LocationStatus.success,
        position: latLng,
        measuredAt: position.timestamp,
        source: LocationSource.current,
      );
    } on TimeoutException catch (e) {
      if (_lastKnownPosition != null) {
        return LocationResult(
          status: LocationStatus.stale,
          position: _lastKnownPosition,
          measuredAt: _lastMeasuredAt,
          source: LocationSource.lastKnown,
        );
      }
      return LocationResult(
        status: LocationStatus.error,
        errorMessage: '${'location_error_failed'.tr()}: ${e.runtimeType}',
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
        _lastMeasuredAt = position.timestamp;

        return LocationResult(
          status: LocationStatus.stale,
          position: latLng,
          measuredAt: position.timestamp,
          source: LocationSource.lastKnown,
        );
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
