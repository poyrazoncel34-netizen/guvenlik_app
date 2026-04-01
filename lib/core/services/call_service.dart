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
        // Permission is pre-granted before countdown starts — do NOT request
        // here (no dialogs during active emergency). Check status only.
        final phonePermission = await Permission.phone.status;
        if (phonePermission.isGranted) {
          final directCallStarted =
              await FlutterDirectCallerPlugin.callNumber(normalized) ?? false;
          if (directCallStarted) {
            return EmergencyCallResult.direct(normalized);
          }
        }
        // If permission somehow not granted (e.g. revoked mid-session),
        // fall through to dialer as last resort.
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
