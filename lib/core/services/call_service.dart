import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_direct_caller_plugin/flutter_direct_caller_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

import 'android_intent_service.dart';
import 'consent_gate_service.dart';
import 'emergency_platform_service.dart';

enum EmergencyCallStatus { directCallStarted, dialerOpened, failed }

class EmergencyCallResult {
  final EmergencyCallStatus status;
  final String number;
  final int attemptCount;

  const EmergencyCallResult._({
    required this.status,
    required this.number,
    this.attemptCount = 1,
  });

  factory EmergencyCallResult.direct(String number) {
    return EmergencyCallResult._(
      status: EmergencyCallStatus.directCallStarted,
      number: number,
    );
  }

  factory EmergencyCallResult.dialer(String number) {
    return EmergencyCallResult._(
      status: EmergencyCallStatus.dialerOpened,
      number: number,
    );
  }

  factory EmergencyCallResult.failed(String number) {
    return EmergencyCallResult._(
      status: EmergencyCallStatus.failed,
      number: number,
    );
  }

  bool get isSuccess => status != EmergencyCallStatus.failed;
  bool get requiresManualConfirmation =>
      status == EmergencyCallStatus.dialerOpened;

  String get statusMessage {
    switch (status) {
      case EmergencyCallStatus.directCallStarted:
        return 'emergency_call_direct_started'.tr();
      case EmergencyCallStatus.dialerOpened:
        return 'emergency_call_dialer_opened'.tr();
      case EmergencyCallStatus.failed:
        return 'emergency_call_failed_status'.tr();
    }
  }
}

class CallService {
  CallService._();

  static Future<EmergencyCallResult> startEmergencyCall(String number) async {
    // KVKK m.5: Log consent status but never block emergency calls
    if (!ConsentGateService.isEmergencyContactsAllowed()) {
      // ignore: avoid_print
      print('[CallService] Consent gate returned false, proceeding for safety');
    }

    final normalized = AndroidIntentService.normalizePhoneNumber(number);
    if (normalized.isEmpty) {
      return EmergencyCallResult.failed(normalized);
    }

    final digitsOnly = normalized.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 7) {
      return EmergencyCallResult.failed(normalized);
    }

    if (Platform.isAndroid) {
      try {
        final phonePermission = await Permission.phone.request();
        if (!phonePermission.isGranted) {
          final dialerOpened = await AndroidIntentService.openDialer(
            normalized,
          );
          if (dialerOpened) {
            return EmergencyCallResult.dialer(normalized);
          }
          return EmergencyCallResult.failed(normalized);
        }

        final directCallStarted =
            await FlutterDirectCallerPlugin.callNumber(normalized)
                .timeout(const Duration(seconds: 3), onTimeout: () => false) ?? false;
        if (directCallStarted) {
          return EmergencyCallResult.direct(normalized);
        }
      } catch (_) {
        // Fallback to dialer below.
      }
    }

    final dialerOpened = await AndroidIntentService.openDialer(normalized);
    if (dialerOpened) {
      return EmergencyCallResult.dialer(normalized);
    }

    return EmergencyCallResult.failed(normalized);
  }

  /// Call guarantee system: retry with phone state verification.
  /// Subscribes to PhoneStateStreamHandler to detect OFFHOOK (call connected).
  /// Retries up to [maxRetries] times per number before returning failure.
  static Future<EmergencyCallResult> startEmergencyCallWithRetry(
    String number, {
    int maxRetries = 2,
  }) async {
    StreamSubscription<Map<String, dynamic>>? phoneStateSub;
    try {
      for (int attempt = 1; attempt <= maxRetries + 1; attempt++) {
        final result = await startEmergencyCall(number);

        // Dialer opened — cannot verify, return immediately
        if (result.status == EmergencyCallStatus.dialerOpened) {
          return EmergencyCallResult._(
            status: result.status,
            number: result.number,
            attemptCount: attempt,
          );
        }

        // Direct call started — verify via phone state
        if (result.status == EmergencyCallStatus.directCallStarted) {
          final verified = Completer<bool>();
          phoneStateSub = EmergencyPlatformService.instance.phoneStates
              .listen((event) {
            final state = event['state']?.toString().toLowerCase() ?? '';
            if (state == 'offhook' || state == 'ringing') {
              if (!verified.isCompleted) verified.complete(true);
            }
          });

          final isConnected = await verified.future
              .timeout(const Duration(seconds: 5), onTimeout: () => false);
          await phoneStateSub.cancel();
          phoneStateSub = null;

          if (isConnected) {
            return EmergencyCallResult._(
              status: EmergencyCallStatus.directCallStarted,
              number: result.number,
              attemptCount: attempt,
            );
          }
          debugPrint('[CallService] Attempt $attempt/${maxRetries + 1} — no offhook detected, retrying');
          continue;
        }

        // Failed — retry unless last attempt
        if (attempt <= maxRetries) {
          debugPrint('[CallService] Attempt $attempt failed, retrying...');
          continue;
        }
      }
    } catch (e) {
      debugPrint('[CallService] Retry loop error: $e');
    } finally {
      await phoneStateSub?.cancel();
    }

    return EmergencyCallResult._(
      status: EmergencyCallStatus.failed,
      number: number,
      attemptCount: maxRetries + 1,
    );
  }
}
