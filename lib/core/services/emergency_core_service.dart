// ============================================================================
// KORUBENI CORE LOGIC - ZERO FAULT EMERGENCY SERVICE
// ============================================================================
// Bu servis acil durum yardımcı fonksiyonlarını barındırır:
// - GPS 5-level fallback
// - Pil seviyesi kontrolü
// - Sistem sağlık kontrolü
//
// NOT: Asıl acil durum tetikleme mantığı CountdownScreen ve
// PinVerificationScreen'de bulunur (dual-action: SMS + Call).
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'connectivity_service.dart';

/// Emergency işlem sonucu
class EmergencyResult {
  final bool success;
  final String message;
  final EmergencyContext context;
  
  EmergencyResult({
    required this.success,
    required this.message,
    required this.context,
  });
}

/// Emergency context - durum bilgisi
class EmergencyContext {
  final bool isOnline;
  final int batteryLevel;
  final LocationSource locationSource;
  final LatLng? location;
  final DateTime timestamp;
  final String? errorDetails;
  
  EmergencyContext({
    required this.isOnline,
    required this.batteryLevel,
    required this.locationSource,
    this.location,
    required this.timestamp,
    this.errorDetails,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'is_online': isOnline,
      'battery_level': batteryLevel,
      'location_source': locationSource.name,
      'has_location': location != null,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'timestamp': timestamp.toIso8601String(),
      'error_details': errorDetails,
    };
  }
}

/// Location source types
enum LocationSource {
  gps,        // Real-time GPS
  cached,     // Last known (in-memory)
  system,     // System last known
  ip,         // IP-based (fallback)
  none,       // No location available
}

/// Location result with source info
class LocationResultWithSource {
  final LatLng? position;
  final LocationSource source;
  final int? ageMinutes;
  
  LocationResultWithSource({
    required this.position,
    required this.source,
    this.ageMinutes,
  });
  
  bool get isAvailable => position != null;
  bool get isReliable => source == LocationSource.gps && ageMinutes == null;
}

/// ============================================================================
/// KORUBENI CORE EMERGENCY SERVICE - ZERO FAULT
/// ============================================================================
class EmergencyCoreService {
  static final EmergencyCoreService _instance = EmergencyCoreService._();
  static EmergencyCoreService get instance => _instance;
  EmergencyCoreService._();
  
  // Battery monitoring
  final Battery _battery = Battery();
  static const int CRITICAL_BATTERY_LEVEL = 10;
  static const int LOW_BATTERY_LEVEL = 20;
  
  // Location caching
  LatLng? _lastKnownPosition;
  DateTime? _lastPositionTime;
  
  // ============================================================================
  // GPS 5-LEVEL FALLBACK - Zero Fault Location
  // ============================================================================
  
  Future<LocationResultWithSource> getLocationWithFallback() async {
    debugPrint('📍 Getting location with 5-level fallback...');
    
    // Level 1: Real-time GPS
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(Duration(seconds: 10));
      
      final latLng = LatLng(position.latitude, position.longitude);
      _lastKnownPosition = latLng;
      _lastPositionTime = DateTime.now();
      
      debugPrint('✅ Level 1: GPS success');
      return LocationResultWithSource(
        position: latLng,
        source: LocationSource.gps,
      );
    } catch (e) {
      debugPrint('❌ Level 1 failed: $e');
    }
    
    // Level 2: Last known (in-memory cache)
    if (_lastKnownPosition != null && _lastPositionTime != null) {
      final age = DateTime.now().difference(_lastPositionTime!);
      if (age.inMinutes < 30) {
        debugPrint('✅ Level 2: Cached (${age.inMinutes}m old)');
        return LocationResultWithSource(
          position: _lastKnownPosition,
          source: LocationSource.cached,
          ageMinutes: age.inMinutes,
        );
      }
    }
    
    // Level 3: System last known
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final latLng = LatLng(lastKnown.latitude, lastKnown.longitude);
        _lastKnownPosition = latLng;
        debugPrint('✅ Level 3: System last known');
        return LocationResultWithSource(
          position: latLng,
          source: LocationSource.system,
        );
      }
    } catch (e) {
      debugPrint('❌ Level 3 failed: $e');
    }
    
    // Level 4 removed: IP-based location requires internet (offline-first app)
    
    // Level 5: No location (ama crash yok!)
    debugPrint('⚠️ Level 5: No location available - all fallback methods exhausted');
    
    return LocationResultWithSource(
      position: null,
      source: LocationSource.none,
    );
  }
  
  // ============================================================================
  // BATTERY LEVEL CHECK - Zero Fault
  // ============================================================================
  
  Future<int> getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      debugPrint('🔋 Battery: $level%');
      return level;
    } catch (e) {
      debugPrint('Battery check failed: $e');
      return 20; // Fallback: safe conservative value (not 100!)
    }
  }
  
  // ============================================================================
  // HEALTH CHECK - System Status (Offline-First)
  // ============================================================================
  
  Future<Map<String, bool>> checkSystemHealth() async {
    final health = <String, bool>{};
    
    try {
      // Network
      health['network'] = ConnectivityService.instance.isOnline;
      
      // GPS
      try {
        health['gps'] = await Geolocator.isLocationServiceEnabled();
      } catch (e) {
        health['gps'] = false;
      }
      
      // Battery
      try {
        final level = await _battery.batteryLevel;
        health['battery_ok'] = level > LOW_BATTERY_LEVEL;
      } catch (e) {
        health['battery_ok'] = true; // Assume OK
      }
      
      // SMS Permission
      try {
        health['sms_permission'] = await Permission.sms.isGranted;
      } catch (e) {
        health['sms_permission'] = false;
      }
      
      // Call Permission
      try {
        health['call_permission'] = await Permission.phone.isGranted;
      } catch (e) {
        health['call_permission'] = false;
      }
      
      debugPrint('🏥 System health: $health');
      return health;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return health;
    }
  }
}
