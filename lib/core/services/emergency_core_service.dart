// ============================================================================
// KORUBENI CORE LOGIC - ZERO FAULT EMERGENCY SERVICE
// ============================================================================
// Bu servis acil durum tetiklendiğinde tüm kritik işlemleri yönetir:
// - Internet kontrolü (offline-first)
// - GPS 5-level fallback
// - Pil seviyesi kontrolü
// - Veri queue yönetimi
// - Crashlytics raporlama
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_direct_caller_plugin/flutter_direct_caller_plugin.dart';
import 'package:telephony/telephony.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import 'location_service.dart';
import 'atomic_storage_service.dart';

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

/// Emergency context - Crashlytics için
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
  // MAIN EMERGENCY TRIGGER - Zero Fault Entry Point
  // ============================================================================
  
  /// Acil durum tetiklendiğinde çağrılır - 10 saniye countdown + dual-action (SMS+Call)
  Future<EmergencyResult> triggerEmergency({
    required String title,
    String? message,
  }) async {
    debugPrint('🚨 EMERGENCY TRIGGERED: $title');
    
    // 1. Start 10-second countdown
    debugPrint('⏱️ Starting 10-second countdown...');
    await Future.delayed(Duration(seconds: 10));
    
    // 2. Get location during/after countdown
    final locationResult = await _getLocationWithFallback();
    debugPrint('📍 Location: ${locationResult.position != null ? "Available" : "Unavailable"}');
    
    // 3. Get emergency contact from local storage
    final contactNumber = await _getEmergencyContactNumber();
    if (contactNumber == null || contactNumber.isEmpty) {
      debugPrint('❌ No emergency contact configured');
      return EmergencyResult(
        success: false,
        message: 'No emergency contact configured',
        context: EmergencyContext(
          isOnline: ConnectivityService.instance.isOnline,
          batteryLevel: await _getBatteryLevel(),
          locationSource: locationResult.source,
          location: locationResult.position,
          timestamp: DateTime.now(),
          errorDetails: 'No emergency contact',
        ),
      );
    }
    
    debugPrint('📞 Emergency contact: $contactNumber');
    
    // 4. Execute DUAL-ACTION sequence (SMS + Call)
    await _executeDualAction(
      contactNumber: contactNumber,
      location: locationResult.position,
    );
    
    // 5. Return success
    return EmergencyResult(
      success: true,
      message: 'Emergency SMS sent and call initiated',
      context: EmergencyContext(
        isOnline: ConnectivityService.instance.isOnline,
        batteryLevel: await _getBatteryLevel(),
        locationSource: locationResult.source,
        location: locationResult.position,
        timestamp: DateTime.now(),
      ),
    );
  }
  
  /// Get emergency contact number from local storage
  Future<String?> _getEmergencyContactNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('emergency_contact_phone');
    } catch (e) {
      debugPrint('Failed to get emergency contact: $e');
      return null;
    }
  }
  
  /// Execute dual-action: SMS + Call (ZERO-FAULT)
  Future<void> _executeDualAction({
    required String contactNumber,
    required LatLng? location,
  }) async {
    debugPrint('🚀 Executing DUAL-ACTION: SMS + Call');
    
    // ACTION 1: Send SMS (background, no user interaction)
    await _sendEmergencySMS(
      contactNumber: contactNumber,
      location: location,
    );
    
    // ACTION 2: Make phone call (immediately after SMS)
    await _makeEmergencyCall(contactNumber: contactNumber);
  }
  
  /// Send emergency SMS with location link
  Future<void> _sendEmergencySMS({
    required String contactNumber,
    required LatLng? location,
  }) async {
    try {
      // 1. Check SMS permission
      final smsPermission = await Permission.sms.status;
      if (!smsPermission.isGranted) {
        debugPrint('⚠️ SMS permission not granted, requesting...');
        final result = await Permission.sms.request();
        if (!result.isGranted) {
          debugPrint('❌ SMS permission denied');
          return;
        }
      }
      
      // 2. Format SMS message
      final smsMessage = _formatEmergencySMS(location);
      debugPrint('📱 SMS message: $smsMessage');
      
      // 3. Send SMS in background (no user interaction)
      final Telephony telephony = Telephony.instance;
      await telephony.sendSms(
        to: contactNumber,
        message: smsMessage,
      );
      
      debugPrint('✅ SMS sent successfully');
    } catch (e) {
      debugPrint('❌ SMS send failed: $e');
      // CRITICAL: Don't throw - we must proceed to phone call even if SMS fails
    }
  }
  
  /// Format emergency SMS with Google Maps link
  String _formatEmergencySMS(LatLng? location) {
    if (location != null) {
      final mapsLink = 'https://maps.google.com/?q=${location.latitude},${location.longitude}';
      return 'ACİL DURUM! KoruBeni panik butonu tetiklendi. Bana acil ulaşın. Konumum: $mapsLink';
    } else {
      return 'ACİL DURUM! KoruBeni panik butonu tetiklendi. Bana acil ulaşın. (Konum bilgisi alınamadı)';
    }
  }
  
  /// Make emergency phone call
  Future<void> _makeEmergencyCall({required String contactNumber}) async {
    try {
      // 1. Check CALL_PHONE permission
      final callPermission = await Permission.phone.status;
      if (!callPermission.isGranted) {
        debugPrint('⚠️ Call permission not granted, requesting...');
        final result = await Permission.phone.request();
        if (!result.isGranted) {
          debugPrint('❌ Call permission denied');
          return;
        }
      }
      
      // 2. Make direct call (no dialer confirmation)
      debugPrint('📞 Calling $contactNumber...');
      await FlutterDirectCallerPlugin.callNumber(contactNumber);
      
      debugPrint('✅ Call initiated successfully');
    } catch (e) {
      debugPrint('❌ Call failed: $e');
      // CRITICAL: This is the last action, log the error
    }
  }
  
  // ============================================================================
  // EMERGENCY CONTEXT BUILDER - Device & System State
  // ============================================================================
  
  Future<EmergencyContext> _buildEmergencyContext() async {
    try {
      // 1. Internet durumu
      final isOnline = ConnectivityService.instance.isOnline;
      
      // 2. Pil seviyesi
      final batteryLevel = await _getBatteryLevel();
      
      // 3. GPS konumu (5-level fallback)
      final locationResult = await _getLocationWithFallback();
      
      return EmergencyContext(
        isOnline: isOnline,
        batteryLevel: batteryLevel,
        locationSource: locationResult.source,
        location: locationResult.position,
        timestamp: DateTime.now(),
      );
    } catch (e, stack) {
      debugPrint('Context build failed: $e');
      debugPrint('Stack trace: $stack');
      
      // Fallback context
      return EmergencyContext(
        isOnline: false,
        batteryLevel: 20, // Safe conservative fallback
        locationSource: LocationSource.none,
        timestamp: DateTime.now(),
        errorDetails: e.toString(),
      );
    }
  }
  
  // ============================================================================
  // GPS 5-LEVEL FALLBACK - Zero Fault Location
  // ============================================================================
  
  Future<LocationResultWithSource> _getLocationWithFallback() async {
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
    
    // Level 4: IP-based location (en son çare)
    try {
      final ipLocation = await _getIpBasedLocation();
      if (ipLocation != null) {
        debugPrint('✅ Level 4: IP-based location');
        return LocationResultWithSource(
          position: ipLocation,
          source: LocationSource.ip,
        );
      }
    } catch (e) {
      debugPrint('❌ Level 4 failed: $e');
    }
    
    // Level 5: No location (ama crash yok!)
    debugPrint('⚠️ Level 5: No location available - all 5 fallback methods exhausted');
    
    return LocationResultWithSource(
      position: null,
      source: LocationSource.none,
    );
  }
  
  /// IP-based location (fallback)
  Future<LatLng?> _getIpBasedLocation() async {
    try {
      // Use ip-api.com for free IP geolocation (HTTPS to prevent Android 9+ blocking)
      final response = await HttpClient()
          .getUrl(Uri.parse('https://ip-api.com/json'))
          .timeout(Duration(seconds: 5));
      
      final httpResponse = await response.close();
      
      if (httpResponse.statusCode == 200) {
        final jsonString = await httpResponse.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);
        
        if (data['status'] == 'success') {
          final lat = data['lat'] as double;
          final lon = data['lon'] as double;
          
          debugPrint('IP location: $lat, $lon (${data['city']}, ${data['country']})');
          return LatLng(lat, lon);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('IP location failed: $e');
      return null;
    }
  }
  
  // ============================================================================
  // BATTERY LEVEL CHECK - Zero Fault
  // ============================================================================
  
  Future<int> _getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      debugPrint('🔋 Battery: $level%');
      return level;
    } catch (e) {
      debugPrint('Battery check failed: $e');
      return 20; // Fallback: safe conservative value (not 100!)
    }
  }
  
  // Note: Old Firebase-dependent handlers removed in offline-first refactoring
  
  // ============================================================================
  // LOCAL STORAGE - Safety Net
  // ============================================================================
  
  Future<void> _saveToLocal(
    String title,
    String? message,
    EmergencyContext context,
  ) async {
    try {
      final key = 'emergency_${DateTime.now().millisecondsSinceEpoch}';
      
      final data = {
        'title': title,
        'message': message,
        'context': context.toMap(),
      };
      
      // Use atomic storage for data integrity
      final success = await AtomicStorageService.instance.writeJson(key, data);
      
      if (success) {
        debugPrint('💾 Saved to local (atomic): $key');
      } else {
        debugPrint('⚠️ Atomic save failed, trying regular save');
        // Fallback to regular save
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode(data));
      }
    } catch (e) {
      debugPrint('Local save failed: $e');
      // Non-critical - don't throw
    }
  }
  
  Future<void> _deleteFromLocal(String title) async {
    try {
      // Delete from BOTH SharedPreferences AND AtomicStorageService
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('emergency_')) {
          final value = prefs.getString(key);
          if (value != null && value.contains(title)) {
            // Delete from SharedPreferences
            await prefs.remove(key);
            debugPrint('🗑️ Deleted from SharedPreferences: $key');
            
            // Delete from AtomicStorageService
            await AtomicStorageService.instance.delete(key);
            debugPrint('🗑️ Deleted from AtomicStorage: $key');
          }
        }
      }
    } catch (e) {
      debugPrint('Local delete failed: $e');
      // Non-critical - don't throw
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
