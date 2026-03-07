import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_direct_caller_plugin/flutter_direct_caller_plugin.dart';

import 'android_intent_service.dart';

enum EmergencyCallStatus {
  directCallStarted,
  dialerOpened,
  failed,
}

class EmergencyCallResult {
  final EmergencyCallStatus status;
  final String number;

  const EmergencyCallResult._({
    required this.status,
    required this.number,
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
    final normalized = AndroidIntentService.normalizePhoneNumber(number);
    if (normalized.isEmpty) {
      return EmergencyCallResult.failed(normalized);
    }

    if (Platform.isAndroid) {
      try {
        final directCallStarted =
            await FlutterDirectCallerPlugin.callNumber(normalized) ?? false;
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
}
