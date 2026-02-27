// ============================================================================
// ATOMIC STORAGE SERVICE - Transaction-Safe Data Operations
// ============================================================================
// Ensures data integrity for SharedPreferences operations.
// Implements backup/rollback pattern to prevent data corruption.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:convert';

/// Atomic storage service with transaction support
class AtomicStorageService {
  static final AtomicStorageService _instance = AtomicStorageService._();
  static AtomicStorageService get instance => _instance;
  AtomicStorageService._();
  
  /// Write string with backup/rollback
  Future<bool> writeString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Backup existing value
      final existing = prefs.getString(key);
      if (existing != null) {
        await prefs.setString('${key}_backup', existing);
      }
      
      // 2. Write new value
      final success = await prefs.setString(key, value);
      
      if (success) {
        // 3. Success - remove backup
        await prefs.remove('${key}_backup');
        return true;
      } else {
        // 4. Failed - restore from backup
        if (existing != null) {
          await prefs.setString(key, existing);
        }
        return false;
      }
    } catch (e, stack) {
      debugPrint('Atomic write failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      
      // Try to restore from backup
      try {
        final prefs = await SharedPreferences.getInstance();
        final backup = prefs.getString('${key}_backup');
        if (backup != null) {
          await prefs.setString(key, backup);
          debugPrint('Restored from backup: $key');
        }
      } catch (e2) {
        debugPrint('Backup restore failed: $e2');
      }
      
      return false;
    }
  }
  
  /// Read string with recovery
  Future<String?> readString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try to read main value
      final value = prefs.getString(key);
      if (value != null) return value;
      
      // If null, try backup
      final backup = prefs.getString('${key}_backup');
      if (backup != null) {
        debugPrint('Recovered from backup: $key');
        // Restore backup as main value
        await prefs.setString(key, backup);
        return backup;
      }
      
      return null;
    } catch (e) {
      debugPrint('Atomic read failed: $e');
      return null;
    }
  }
  
  /// Write JSON with backup/rollback
  Future<bool> writeJson(String key, Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      return await writeString(key, jsonString);
    } catch (e, stack) {
      debugPrint('JSON write failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      return false;
    }
  }
  
  /// Read JSON with recovery
  Future<Map<String, dynamic>?> readJson(String key) async {
    try {
      final jsonString = await readString(key);
      if (jsonString == null) return null;
      
      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (e) {
      debugPrint('JSON read failed: $e');
      return null;
    }
  }
  
  /// Write int with backup/rollback
  Future<bool> writeInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Backup
      final existing = prefs.getInt(key);
      if (existing != null) {
        await prefs.setInt('${key}_backup', existing);
      }
      
      // Write
      final success = await prefs.setInt(key, value);
      
      if (success) {
        await prefs.remove('${key}_backup');
        return true;
      } else {
        if (existing != null) {
          await prefs.setInt(key, existing);
        }
        return false;
      }
    } catch (e, stack) {
      debugPrint('Int write failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      return false;
    }
  }
  
  /// Read int with recovery
  Future<int?> readInt(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final value = prefs.getInt(key);
      if (value != null) return value;
      
      // Try backup
      final backup = prefs.getInt('${key}_backup');
      if (backup != null) {
        debugPrint('Recovered int from backup: $key');
        await prefs.setInt(key, backup);
        return backup;
      }
      
      return null;
    } catch (e) {
      debugPrint('Int read failed: $e');
      return null;
    }
  }
  
  /// Write bool with backup/rollback
  Future<bool> writeBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final existing = prefs.getBool(key);
      if (existing != null) {
        await prefs.setBool('${key}_backup', existing);
      }
      
      final success = await prefs.setBool(key, value);
      
      if (success) {
        await prefs.remove('${key}_backup');
        return true;
      } else {
        if (existing != null) {
          await prefs.setBool(key, existing);
        }
        return false;
      }
    } catch (e, stack) {
      debugPrint('Bool write failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      return false;
    }
  }
  
  /// Read bool with recovery
  Future<bool?> readBool(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final value = prefs.getBool(key);
      if (value != null) return value;
      
      final backup = prefs.getBool('${key}_backup');
      if (backup != null) {
        debugPrint('Recovered bool from backup: $key');
        await prefs.setBool(key, backup);
        return backup;
      }
      
      return null;
    } catch (e) {
      debugPrint('Bool read failed: $e');
      return null;
    }
  }
  
  /// Delete key and its backup
  Future<bool> delete(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(key);
      await prefs.remove('${key}_backup');
      
      return true;
    } catch (e) {
      debugPrint('Delete failed: $e');
      return false;
    }
  }
  
  /// Check data integrity - verify all backups are consistent
  Future<void> checkIntegrity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int recoveredCount = 0;
      
      for (final key in keys) {
        if (key.endsWith('_backup')) {
          final mainKey = key.replaceAll('_backup', '');
          
          // Check if main key exists
          if (!prefs.containsKey(mainKey)) {
            // Main key missing - restore from backup
            final backup = prefs.get(key);
            if (backup != null) {
              if (backup is String) {
                await prefs.setString(mainKey, backup);
              } else if (backup is int) {
                await prefs.setInt(mainKey, backup);
              } else if (backup is bool) {
                await prefs.setBool(mainKey, backup);
              }
              
              recoveredCount++;
              debugPrint('Recovered $mainKey from backup');
            }
          }
        }
      }
      
      if (recoveredCount > 0) {
        debugPrint('✅ Integrity check: recovered $recoveredCount keys');
        FirebaseCrashlytics.instance.log(
          'Data integrity check recovered $recoveredCount keys',
        );
      } else {
        debugPrint('✅ Integrity check: all data consistent');
      }
      
    } catch (e, stack) {
      debugPrint('Integrity check failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }
}
