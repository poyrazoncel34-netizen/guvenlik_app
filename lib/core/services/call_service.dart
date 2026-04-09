import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_direct_caller_plugin/flutter_direct_caller_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

import 'android_intent_service.dart';
import 'consent_gate_service.dart';

enum EmergencyCallStatus { directCallStarted, dialerOpened, failed }

class EmergencyCallResult {
  final EmergencyCallStatus status;
  final String number;

  const EmergencyCallResult._({required this.status, required this.number});

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

  /// True ONLY when a direct call was placed by the OS (no user action needed).
  bool get isConfirmed => status == EmergencyCallStatus.directCallStarted;

  /// True when dialer opened but USER MUST PRESS THE GREEN CALL BUTTON.
  bool get requiresUserAction =>
      status == EmergencyCallStatus.dialerOpened;

  /// True when the action completely failed (nothing opened).
  bool get isFailed => status == EmergencyCallStatus.failed;

  /// True when at least something happened (call placed OR dialer opened).
  /// WARNING: This does NOT mean the call connected.
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
    // KVKK m.5: Acil durum kişileri rızası kontrolü
    if (!ConsentGateService.isEmergencyContactsAllowed()) {
      return EmergencyCallResult.failed(number);
    }

    final normalized = AndroidIntentService.normalizePhoneNumber(number);
    if (normalized.isEmpty) {
      return EmergencyCallResult.failed(normalized);
    }

    if (Platform.isAndroid) {
      try {
        // C1 FIX: Check permission status only — never request() during emergency.
        // Permission is pre-requested at app startup via PermissionHelper.
        // request() shows a blocking dialog that kills the call if phone is in pocket.
        final phoneStatus = await Permission.phone.status;
        if (phoneStatus.isGranted) {
          final directCallStarted =
              await FlutterDirectCallerPlugin.callNumber(normalized).timeout(const Duration(seconds: 8), onTimeout: () => false) ?? false;
          if (directCallStarted) {
            return EmergencyCallResult.direct(normalized);
          }
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
}
