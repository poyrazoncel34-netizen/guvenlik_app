// ============================================================================
// BREADCRUMB LOGGING SERVICE - Crash Context Tracking
// ============================================================================
// Tracks the last 50 user actions to provide context when crashes occur.
// Automatically uploads breadcrumb trail to Crashlytics on errors.
// ============================================================================

import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Breadcrumb logging service for crash context
/// 
/// Maintains a circular buffer of user actions to provide context when errors occur
class BreadcrumbService {
  static final BreadcrumbService _instance = BreadcrumbService._();
  static BreadcrumbService get instance => _instance;
  BreadcrumbService._();
  
  static const int _maxBreadcrumbs = 50;
  final Queue<String> _breadcrumbs = Queue<String>();
  
  /// Add a breadcrumb entry
  void add(String breadcrumb) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] $breadcrumb';
    
    _breadcrumbs.add(entry);
    
    // Maintain max size
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeFirst();
    }
    
    // Also log to Crashlytics immediately
    FirebaseCrashlytics.instance.log(entry);
    
    debugPrint('🍞 Breadcrumb: $breadcrumb');
  }
  
  /// Get the full breadcrumb trail as a string
  String getTrail() {
    if (_breadcrumbs.isEmpty) {
      return 'No breadcrumbs recorded';
    }
    return _breadcrumbs.join('\n');
  }
  
  /// Get breadcrumbs as a list
  List<String> getBreadcrumbs() {
    return _breadcrumbs.toList();
  }
  
  /// Get the last N breadcrumbs
  List<String> getLastN(int n) {
    final count = _breadcrumbs.length;
    if (count <= n) {
      return _breadcrumbs.toList();
    }
    return _breadcrumbs.toList().sublist(count - n);
  }
  
  /// Report an error with full breadcrumb trail
  Future<void> reportWithTrail(
    dynamic error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      // Set breadcrumb trail as custom key
      await FirebaseCrashlytics.instance.setCustomKey(
        'breadcrumb_trail',
        getTrail(),
      );
      
      await FirebaseCrashlytics.instance.setCustomKey(
        'breadcrumb_count',
        _breadcrumbs.length,
      );
      
      // Record the error
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
      
      debugPrint('📊 Error reported with ${_breadcrumbs.length} breadcrumbs');
    } catch (e) {
      debugPrint('Failed to report error with breadcrumbs: $e');
    }
  }
  
  /// Clear all breadcrumbs
  void clear() {
    _breadcrumbs.clear();
    debugPrint('🧹 Breadcrumbs cleared');
  }
  
  /// Add a screen view breadcrumb
  void addScreenView(String screenName) {
    add('Screen: $screenName');
  }
  
  /// Add a button tap breadcrumb
  void addButtonTap(String buttonName) {
    add('Tap: $buttonName');
  }
  
  /// Add an API call breadcrumb
  void addApiCall(String endpoint, {String? method}) {
    final methodStr = method != null ? '$method ' : '';
    add('API: $methodStr$endpoint');
  }
  
  /// Add an error breadcrumb
  void addError(String errorMessage) {
    add('Error: $errorMessage');
  }
  
  /// Add a success breadcrumb
  void addSuccess(String action) {
    add('Success: $action');
  }
  
  /// Add a warning breadcrumb
  void addWarning(String warning) {
    add('Warning: $warning');
  }
  
  /// Add a custom breadcrumb with category
  void addWithCategory(String category, String message) {
    add('[$category] $message');
  }
}
