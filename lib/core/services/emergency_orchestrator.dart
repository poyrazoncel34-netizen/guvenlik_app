import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'call_service.dart';
import 'emergency_platform_service.dart';
import 'sms_service.dart';

/// Result of the multi-channel emergency dispatch.
class EmergencyOrchestratorResult {
  final EmergencyCallResult callResult;
  final SmsComposeResult smsResult;
  final String calledNumber;
  final bool atLeastOneChannelSucceeded;

  const EmergencyOrchestratorResult({
    required this.callResult,
    required this.smsResult,
    required this.calledNumber,
    required this.atLeastOneChannelSucceeded,
  });
}

/// Coordinates independent SMS + Call channels with retry, failover,
/// and native-side fallback. Guarantees at least one channel executes
/// or fires the native emergency executor as last resort.
class EmergencyOrchestrator {
  EmergencyOrchestrator._();

  /// Execute emergency dispatch across all channels.
  ///
  /// SMS and Call run as fully independent Futures — neither can
  /// crash or block the other. If both Flutter channels fail,
  /// fires the native EmergencyExecutor as a last resort.
  static Future<EmergencyOrchestratorResult> execute({
    required List<String> numbers,
    required String message,
    required String? primaryNumber,
  }) async {
    // Ensure CPU stays awake during dispatch
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    // Quick permission pre-check (non-blocking, 2s timeout)
    Map<String, dynamic> deviceState = const {};
    try {
      deviceState = await EmergencyPlatformService.instance
          .getDeviceState()
          .timeout(const Duration(seconds: 2), onTimeout: () => const {});
    } catch (_) {}

    // Launch both channels independently
    final smsFuture = _executeSmsChannel(numbers, message, deviceState);
    final callFuture = _executeCallChannel(numbers, primaryNumber, deviceState);

    // Wait for both — neither can throw (wrapped in try-catch)
    final results = await Future.wait([smsFuture, callFuture]);
    final smsResult = results[0] as SmsComposeResult;
    final callResultPair = results[1] as _CallChannelResult;

    final atLeastOne = smsResult.isSuccess || callResultPair.result.isSuccess;

    // System 4D: Native fallback — last resort if both Flutter channels failed
    if (!atLeastOne) {
      debugPrint('[Orchestrator] Both channels failed — firing native executor');
      try {
        await EmergencyPlatformService.instance.executeEmergencyNative(
          recipients: numbers,
          message: message,
          primaryNumber: primaryNumber ?? (numbers.isNotEmpty ? numbers.first : ''),
        );
      } catch (_) {
        debugPrint('[Orchestrator] Native executor also failed');
      }
    }

    return EmergencyOrchestratorResult(
      callResult: callResultPair.result,
      smsResult: smsResult,
      calledNumber: callResultPair.calledNumber,
      atLeastOneChannelSucceeded: atLeastOne,
    );
  }

  /// Independent SMS channel with retry.
  /// Completely isolated — can never affect the call channel.
  static Future<SmsComposeResult> _executeSmsChannel(
    List<String> numbers,
    String message,
    Map<String, dynamic> deviceState,
  ) async {
    try {
      final result = await SmsService.sendSms(
        numbers: numbers,
        message: message,
      );

      // If failed, retry once after brief delay
      if (!result.isSuccess) {
        debugPrint('[Orchestrator] SMS failed, retrying once...');
        await Future.delayed(const Duration(milliseconds: 500));
        final retryResult = await SmsService.sendSms(
          numbers: numbers,
          message: message,
        );
        return retryResult;
      }

      return result;
    } catch (e) {
      debugPrint('[Orchestrator] SMS channel error: $e');
      return SmsComposeResult.failed();
    }
  }

  /// Independent Call channel with retry + failover.
  /// Completely isolated — can never affect the SMS channel.
  static Future<_CallChannelResult> _executeCallChannel(
    List<String> numbers,
    String? primaryNumber,
    Map<String, dynamic> deviceState,
  ) async {
    try {
      String calledNumber = primaryNumber ?? '';

      // Try primary number with retry
      if (primaryNumber != null && primaryNumber.isNotEmpty) {
        final result = await CallService.startEmergencyCallWithRetry(
          primaryNumber,
        );
        if (result.isSuccess) {
          return _CallChannelResult(result, primaryNumber);
        }

        // Failover: try each remaining number
        if (numbers.length > 1) {
          for (final fallback in numbers) {
            if (fallback == primaryNumber) continue;
            final fallbackResult = await CallService.startEmergencyCallWithRetry(
              fallback,
            );
            if (fallbackResult.isSuccess) {
              return _CallChannelResult(fallbackResult, fallback);
            }
          }
        }

        calledNumber = primaryNumber;
      }

      return _CallChannelResult(
        EmergencyCallResult.failed(calledNumber),
        calledNumber,
      );
    } catch (e) {
      debugPrint('[Orchestrator] Call channel error: $e');
      return _CallChannelResult(
        EmergencyCallResult.failed(primaryNumber ?? ''),
        primaryNumber ?? '',
      );
    }
  }
}

class _CallChannelResult {
  final EmergencyCallResult result;
  final String calledNumber;
  const _CallChannelResult(this.result, this.calledNumber);
}
