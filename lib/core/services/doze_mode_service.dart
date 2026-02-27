// ============================================================================
// DOZE MODE BYPASS SERVICE - Android Deep Sleep Protection
// ============================================================================
// Ensures emergency signals can be sent even when phone is in Doze Mode.
// Uses Android's whitelist mechanism for critical apps.
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Doze Mode bypass service for Android
/// 
/// Critical for emergency apps - ensures operation during deep sleep
class DozeModeService {
  static final DozeModeService _instance = DozeModeService._();
  static DozeModeService get instance => _instance;
  DozeModeService._();
  
  static const String _prefKeyWhitelisted = 'doze_whitelisted';
  static const String _prefKeyAsked = 'doze_asked';
  
  static const MethodChannel _channel = 
      MethodChannel('com.poyrazoncel.korubeni/doze');
  
  /// Check if app is whitelisted from Doze Mode
  Future<bool> isWhitelisted() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod<bool>('isDozeWhitelisted');
      final whitelisted = result ?? false;
      
      debugPrint('🌙 Doze whitelist status: $whitelisted');
      
      // Cache result
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyWhitelisted, whitelisted);
      
      return whitelisted;
    } on PlatformException catch (e) {
      debugPrint('Doze whitelist check failed: ${e.message}');
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    } catch (e) {
      debugPrint('Doze whitelist check error: $e');
      return false;
    }
  }
  
  /// Request Doze Mode whitelist
  /// Opens system settings for user to approve
  Future<bool> requestWhitelist() async {
    if (!Platform.isAndroid) return true;
    
    try {
      debugPrint('🌙 Requesting Doze whitelist...');
      
      // Mark that we asked
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyAsked, true);
      
      // Open system settings
      await _channel.invokeMethod('requestDozeWhitelist');
      
      // Wait for user action
      await Future.delayed(Duration(seconds: 2));
      
      // Check if granted
      final whitelistStatus = await isWhitelisted();
      
      if (whitelistStatus) {
        debugPrint('✅ Doze whitelist granted');
        FirebaseCrashlytics.instance.log('Doze whitelist granted');
      } else {
        debugPrint('❌ Doze whitelist denied');
        FirebaseCrashlytics.instance.log('Doze whitelist denied by user');
      }
      
      return whitelistStatus;
    } on PlatformException catch (e) {
      debugPrint('Doze whitelist request failed: ${e.message}');
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    } catch (e) {
      debugPrint('Doze whitelist request error: $e');
      return false;
    }
  }
  
  /// Check if we should show the request
  Future<bool> shouldShowRequest() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAsked = prefs.getBool(_prefKeyAsked) ?? false;
      
      // If already asked, only show again if still not whitelisted
      if (hasAsked) {
        final whitelisted = await isWhitelisted();
        return !whitelisted;
      }
      
      // First time - check current status
      final whitelisted = await isWhitelisted();
      return !whitelisted;
    } catch (e) {
      debugPrint('shouldShowRequest check failed: $e');
      return false;
    }
  }
  
  /// Get Doze Mode status for Crashlytics
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'is_android': Platform.isAndroid,
      'is_whitelisted': await isWhitelisted(),
      'has_asked_user': await _hasAskedUser(),
    };
  }
  
  Future<bool> _hasAskedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKeyAsked) ?? false;
    } catch (e) {
      return false;
    }
  }
}
