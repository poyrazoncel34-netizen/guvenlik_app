import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guvenlik_app/core/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Platform platform;
  setUp(() {
    platform = _Platform();
    GeolocatorPlatform.instance = platform;
  });

  test('timeout without any measurement does not fabricate coordinates', () async {
    platform.timeout = true;
    final result = await LocationService().getCurrentLocation();
    expect(result.isSuccess, isFalse);
    expect(result.position, isNull);
    expect(result.measuredAt, isNull);
    expect(result.source, LocationSource.none);
  });

  test('timeout retains old measurement but never reports current success', () async {
    final service = LocationService();
    final old = DateTime.utc(2020);
    platform.position = _position(old);
    await service.getLastKnownLocation();
    platform.timeout = true;
    final result = await service.getCurrentLocation();
    expect(result.isSuccess, isFalse);
    expect(result.position, isNotNull);
    expect(result.measuredAt, old);
    expect(result.source, LocationSource.lastKnown);
    expect(result.isCurrent, isFalse);
  });

  test('new measurement carries platform time and source', () async {
    final now = DateTime.now();
    platform.position = _position(now);
    final result = await LocationService().getCurrentLocation();
    expect(result.isSuccess, isTrue);
    expect(result.measuredAt, now);
    expect(result.source, LocationSource.current);
    expect(result.isCurrent, isTrue);
  });

  test('denied or revoked permission never returns cached coordinates', () async {
    platform.position = _position(DateTime.now());
    await LocationService().getCurrentLocation();
    for (final permission in [LocationPermission.denied, LocationPermission.deniedForever]) {
      platform.permission = permission;
      final result = await LocationService().getCurrentLocation();
      expect(result.isSuccess, isFalse);
      expect(result.position, isNull);
    }
  });
}

Position _position(DateTime timestamp) => Position(
  latitude: 40, longitude: 29, timestamp: timestamp,
  accuracy: 5, altitude: 0, altitudeAccuracy: 0,
  heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
);

class _Platform extends GeolocatorPlatform {
  Position? position;
  bool timeout = false;
  LocationPermission permission = LocationPermission.whileInUse;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => position;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (timeout) throw TimeoutException('synthetic');
    return position!;
  }
}
