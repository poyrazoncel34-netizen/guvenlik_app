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
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import 'location_service.dart';
import 'firebase_service.dart';
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
  
  /// Acil durum tetiklendiğinde çağrılır - TÜM zero-fault pattern'leri burada
  Future<EmergencyResult> triggerEmergency({
    required String title,
    String? message,
  }) async {
    debugPrint('🚨 EMERGENCY TRIGGERED: $title');
    
    // 1. Başlangıç context'i oluştur
    final context = await _buildEmergencyContext();
    
    // 2. Crashlytics'e context set et
    await _setCrashlyticsContext(context);
    
    // 3. Pil seviyesi kontrolü - kritik durumda emergency-only mode
    if (context.batteryLevel <= CRITICAL_BATTERY_LEVEL) {
      debugPrint('⚠️ CRITICAL BATTERY: ${context.batteryLevel}%');
      return await _handleCriticalBatteryEmergency(title, message, context);
    }
    
    // 4. Internet kontrolü - offline-first yaklaşım
    if (!context.isOnline) {
      debugPrint('📴 OFFLINE MODE: Queuing emergency');
      return await _handleOfflineEmergency(title, message, context);
    }
    
    // 5. Online - direkt gönder ama hata olursa queue'ya ekle
    return await _handleOnlineEmergency(title, message, context);
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
      FirebaseCrashlytics.instance.recordError(e, stack);
      
      // Fallback context
      return EmergencyContext(
        isOnline: false,
        batteryLevel: 100,
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
    debugPrint('⚠️ Level 5: No location available');
    FirebaseCrashlytics.instance.log('All location methods failed');
    
    return LocationResultWithSource(
      position: null,
      source: LocationSource.none,
    );
  }
  
  /// IP-based location (fallback)
  Future<LatLng?> _getIpBasedLocation() async {
    try {
      // Use ip-api.com for free IP geolocation
      final response = await HttpClient()
          .getUrl(Uri.parse('http://ip-api.com/json'))
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
      return 100; // Fallback: assume full battery
    }
  }
  
  // ============================================================================
  // CRITICAL BATTERY HANDLER - Emergency-Only Mode
  // ============================================================================
  
  Future<EmergencyResult> _handleCriticalBatteryEmergency(
    String title,
    String? message,
    EmergencyContext context,
  ) async {
    debugPrint('⚡ CRITICAL BATTERY MODE: Emergency-only');
    
    try {
      // 1. Sadece kritik veriyi local'e kaydet
      await _saveToLocal(title, message, context);
      
      // 2. Offline queue'ya ekle (minimal data)
      await OfflineQueueService.instance.enqueue(
        OfflineEvent(
          type: 'emergency',
          title: title,
          description: message,
          data: {
            'lat': context.location?.latitude,
            'lng': context.location?.longitude,
            'battery_critical': true,
          },
        ),
      );
      
      // 3. Crashlytics'e raporla
      await FirebaseCrashlytics.instance.recordError(
        Exception('Emergency triggered with critical battery'),
        StackTrace.current,
        reason: 'Critical battery emergency',
        fatal: false,
      );
      
      return EmergencyResult(
        success: true,
        message: 'Emergency queued (critical battery mode)',
        context: context,
      );
    } catch (e, stack) {
      debugPrint('Critical battery emergency failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      
      return EmergencyResult(
        success: false,
        message: 'Failed to queue emergency: $e',
        context: context,
      );
    }
  }
  
  // ============================================================================
  // OFFLINE HANDLER - Queue Pattern
  // ============================================================================
  
  Future<EmergencyResult> _handleOfflineEmergency(
    String title,
    String? message,
    EmergencyContext context,
  ) async {
    debugPrint('📴 OFFLINE: Queuing emergency');
    
    try {
      // 1. Local'e kaydet (anında)
      await _saveToLocal(title, message, context);
      
      // 2. Offline queue'ya ekle
      await OfflineQueueService.instance.enqueue(
        OfflineEvent(
          type: 'emergency',
          title: title,
          description: message,
          data: {
            'lat': context.location?.latitude,
            'lng': context.location?.longitude,
            'location_source': context.locationSource.name,
            'battery_level': context.batteryLevel,
          },
        ),
      );
      
      // 3. Crashlytics'e log
      FirebaseCrashlytics.instance.log('Emergency queued (offline)');
      
      return EmergencyResult(
        success: true,
        message: 'Emergency queued for sync',
        context: context,
      );
    } catch (e, stack) {
      debugPrint('Offline emergency failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      
      return EmergencyResult(
        success: false,
        message: 'Failed to queue emergency: $e',
        context: context,
      );
    }
  }
  
  // ============================================================================
  // ONLINE HANDLER - Direct Send with Fallback
  // ============================================================================
  
  Future<EmergencyResult> _handleOnlineEmergency(
    String title,
    String? message,
    EmergencyContext context,
  ) async {
    debugPrint('🌐 ONLINE: Sending emergency');
    
    try {
      // 1. Önce local'e kaydet (safety)
      await _saveToLocal(title, message, context);
      
      // 2. Firebase'e gönder (10 saniye timeout)
      await FirebaseService.instance.createEmergencyEvent(
        title: title,
        message: message ?? 'Emergency triggered',
        lat: context.location?.latitude,
        lng: context.location?.longitude,
      ).timeout(Duration(seconds: 10));
      
      // 3. Başarılı - local'den sil
      await _deleteFromLocal(title);
      
      // 4. Crashlytics'e log
      FirebaseCrashlytics.instance.log('Emergency sent successfully');
      
      return EmergencyResult(
        success: true,
        message: 'Emergency sent successfully',
        context: context,
      );
    } on TimeoutException catch (e, stack) {
      debugPrint('Timeout: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      
      // Timeout - queue'ya ekle
      return await _fallbackToQueue(title, message, context);
    } on SocketException catch (e, stack) {
      debugPrint('Network error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      
      // Network error - queue'ya ekle
      return await _fallbackToQueue(title, message, context);
    } catch (e, stack) {
      debugPrint('Send failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      
      // Genel hata - queue'ya ekle
      return await _fallbackToQueue(title, message, context);
    }
  }
  
  /// Online gönderim başarısız - queue'ya fallback
  Future<EmergencyResult> _fallbackToQueue(
    String title,
    String? message,
    EmergencyContext context,
  ) async {
    debugPrint('⚠️ FALLBACK: Adding to queue');
    
    try {
      await OfflineQueueService.instance.enqueue(
        OfflineEvent(
          type: 'emergency',
          title: title,
          description: message,
          data: {
            'lat': context.location?.latitude,
            'lng': context.location?.longitude,
            'location_source': context.locationSource.name,
            'battery_level': context.batteryLevel,
            'fallback_reason': 'online_send_failed',
          },
        ),
      );
      
      return EmergencyResult(
        success: true,
        message: 'Emergency queued (send failed)',
        context: context,
      );
    } catch (e, stack) {
      debugPrint('Fallback failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      
      return EmergencyResult(
        success: false,
        message: 'Critical: All methods failed',
        context: context,
      );
    }
  }
  
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
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('emergency_')) {
          final value = prefs.getString(key);
          if (value != null && value.contains(title)) {
            await prefs.remove(key);
            debugPrint('🗑️ Deleted from local: $key');
          }
        }
      }
    } catch (e) {
      debugPrint('Local delete failed: $e');
      // Non-critical - don't throw
    }
  }
  
  // ============================================================================
  // CRASHLYTICS CONTEXT - Full Device State
  // ============================================================================
  
  Future<void> _setCrashlyticsContext(EmergencyContext context) async {
    try {
      await FirebaseCrashlytics.instance.setCustomKey(
        'emergency_timestamp',
        context.timestamp.toIso8601String(),
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'is_online',
        context.isOnline,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'battery_level',
        context.batteryLevel,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'location_source',
        context.locationSource.name,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'has_location',
        context.location != null,
      );
      
      if (context.location != null) {
        await FirebaseCrashlytics.instance.setCustomKey(
          'latitude',
          context.location!.latitude,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'longitude',
          context.location!.longitude,
        );
      }
      
      debugPrint('📊 Crashlytics context set');
    } catch (e) {
      debugPrint('Crashlytics context failed: $e');
      // Non-critical - don't throw
    }
  }
  
  // ============================================================================
  // HEALTH CHECK - System Status
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
      
      // Firebase
      health['firebase'] = FirebaseService.instance != null;
      
      debugPrint('🏥 System health: $health');
      return health;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return health;
    }
  }
}
