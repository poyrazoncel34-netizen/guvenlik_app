// ============================================================================
// DOZE MODE RELIABILITY GUIDANCE SERVICE
// ============================================================================
// Requests an optional Android battery optimization exemption for active
// safety-session reliability. Denial is expected and must degrade gracefully.
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Doze Mode reliability guidance service for Android.
///
/// A whitelist/exemption can improve timer reliability but does not guarantee
/// operation during deep sleep or OEM battery restrictions.
class DozeModeService {
  static final DozeModeService _instance = DozeModeService._();
  static DozeModeService get instance => _instance;
  DozeModeService._();

  static const String _prefKeyWhitelisted = 'doze_whitelisted';
  static const String _prefKeyAsked = 'doze_asked';

  static const MethodChannel _channel = MethodChannel(
    'com.poyrazoncel.korubeni/doze',
  );

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
      return false;
    } catch (e) {
      debugPrint('Doze whitelist check error: $e');
      return false;
    }
  }

  /// Request optional Doze Mode whitelist.
  /// Opens system settings for the user to approve or decline.
  Future<bool> requestWhitelist() async {
    if (!Platform.isAndroid) return true;

    try {
      debugPrint('🌙 Requesting optional Doze whitelist...');

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
      } else {
        debugPrint('❌ Doze whitelist not granted');
      }

      return whitelistStatus;
    } on PlatformException catch (e) {
      debugPrint('Doze whitelist request failed: ${e.message}');
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

  /// Get Doze Mode status for local diagnostics
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
