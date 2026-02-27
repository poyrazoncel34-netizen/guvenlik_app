// ============================================================================
// NETWORK RETRY SERVICE - Exponential Backoff & Timeout
// ============================================================================
// Provides zero-fault network operations with automatic retry logic.
// All Firebase and API calls should use this service.
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'breadcrumb_service.dart';

/// Network operation result
class NetworkResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final NetworkErrorType? errorType;
  
  NetworkResult.success(this.data)
      : success = true,
        errorMessage = null,
        errorType = null;
  
  NetworkResult.failure(this.errorMessage, this.errorType)
      : success = false,
        data = null;
}

/// Network error types
enum NetworkErrorType {
  timeout,
  noConnection,
  serverError,
  unknown,
}

/// Network retry service with exponential backoff
class NetworkRetryService {
  static final NetworkRetryService _instance = NetworkRetryService._();
  static NetworkRetryService get instance => _instance;
  NetworkRetryService._();
  
  /// Execute network operation with retry logic
  /// 
  /// Parameters:
  /// - operation: The async operation to execute
  /// - maxAttempts: Maximum number of retry attempts (default: 3)
  /// - initialDelay: Initial delay before first retry (default: 1s)
  /// - timeout: Timeout for each attempt (default: 10s)
  /// - operationName: Name for logging (optional)
  Future<NetworkResult<T>> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration timeout = const Duration(seconds: 10),
    String? operationName,
  }) async {
    final opName = operationName ?? 'network_operation';
    int attempt = 0;
    Duration delay = initialDelay;
    
    BreadcrumbService.instance.add('Network: $opName started');
    
    while (attempt < maxAttempts) {
      attempt++;
      
      try {
        debugPrint('🌐 $opName attempt $attempt/$maxAttempts');
        
        // Execute with timeout
        final result = await operation().timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException('Operation timed out after ${timeout.inSeconds}s');
          },
        );
        
        // Success
        debugPrint('✅ $opName succeeded on attempt $attempt');
        BreadcrumbService.instance.addSuccess('$opName succeeded');
        
        return NetworkResult.success(result);
        
      } on TimeoutException catch (e, stack) {
        debugPrint('⏱️ $opName timeout on attempt $attempt: $e');
        
        if (attempt >= maxAttempts) {
          BreadcrumbService.instance.addError('$opName timeout after $maxAttempts attempts');
          FirebaseCrashlytics.instance.recordError(e, stack);
          return NetworkResult.failure(
            'Operation timed out after $maxAttempts attempts',
            NetworkErrorType.timeout,
          );
        }
        
        // Wait before retry (exponential backoff)
        await Future.delayed(delay);
        delay *= 2; // Double the delay
        
      } on SocketException catch (e, stack) {
        debugPrint('📡 $opName no connection on attempt $attempt: $e');
        
        if (attempt >= maxAttempts) {
          BreadcrumbService.instance.addError('$opName no connection after $maxAttempts attempts');
          FirebaseCrashlytics.instance.recordError(e, stack);
          return NetworkResult.failure(
            'No internet connection',
            NetworkErrorType.noConnection,
          );
        }
        
        await Future.delayed(delay);
        delay *= 2;
        
      } on HttpException catch (e, stack) {
        debugPrint('🌐 $opName HTTP error on attempt $attempt: $e');
        
        if (attempt >= maxAttempts) {
          BreadcrumbService.instance.addError('$opName HTTP error after $maxAttempts attempts');
          FirebaseCrashlytics.instance.recordError(e, stack);
          return NetworkResult.failure(
            'Server error: ${e.message}',
            NetworkErrorType.serverError,
          );
        }
        
        await Future.delayed(delay);
        delay *= 2;
        
      } catch (e, stack) {
        debugPrint('❌ $opName unknown error on attempt $attempt: $e');
        
        if (attempt >= maxAttempts) {
          BreadcrumbService.instance.addError('$opName failed after $maxAttempts attempts: $e');
          FirebaseCrashlytics.instance.recordError(e, stack);
          return NetworkResult.failure(
            'Unknown error: $e',
            NetworkErrorType.unknown,
          );
        }
        
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    
    // Should never reach here
    return NetworkResult.failure(
      'Max attempts reached',
      NetworkErrorType.unknown,
    );
  }
  
  /// Simple retry with default settings
  Future<T?> retry<T>(Future<T> Function() operation) async {
    final result = await executeWithRetry(operation: operation);
    return result.data;
  }
  
  /// Execute with timeout only (no retry)
  Future<T?> executeWithTimeout<T>({
    required Future<T> Function() operation,
    Duration timeout = const Duration(seconds: 10),
    String? operationName,
  }) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException catch (e, stack) {
      debugPrint('Timeout: ${operationName ?? "operation"}');
      FirebaseCrashlytics.instance.recordError(e, stack);
      return null;
    } catch (e, stack) {
      debugPrint('Error: ${operationName ?? "operation"}: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      return null;
    }
  }
}
