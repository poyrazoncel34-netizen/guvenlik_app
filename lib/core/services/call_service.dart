import 'package:easy_localization/easy_localization.dart';

enum EmergencyCallStatus { callRequested, dialerRequested, failed }

class EmergencyCallResult {
  final EmergencyCallStatus status;
  final String number;

  const EmergencyCallResult._({required this.status, required this.number});

  factory EmergencyCallResult.requested(String number) {
    return EmergencyCallResult._(
      status: EmergencyCallStatus.callRequested,
      number: number,
    );
  }

  factory EmergencyCallResult.dialer(String number) {
    return EmergencyCallResult._(
      status: EmergencyCallStatus.dialerRequested,
      number: number,
    );
  }

  factory EmergencyCallResult.failed(String number) {
    return EmergencyCallResult._(
      status: EmergencyCallStatus.failed,
      number: number,
    );
  }

  /// Intent dispatch cannot confirm that call UI appeared or a call connected.
  bool get isConfirmed => false;

  /// A dialer request requires the user to press the system call button.
  bool get requiresUserAction => status == EmergencyCallStatus.dialerRequested;

  /// Android Telecom accepted a request, but the user must still verify the
  /// outcome; ringing and connection are never inferred.
  bool get requiresVerification => status == EmergencyCallStatus.callRequested;

  /// True when the action completely failed (nothing opened).
  bool get isFailed => status == EmergencyCallStatus.failed;

  /// True only means Android accepted an intent request. It does not prove the
  /// phone UI appeared, a call was placed, or the other party answered.
  bool get isSuccess => status != EmergencyCallStatus.failed;

  bool get requiresManualConfirmation => status != EmergencyCallStatus.failed;

  String get statusMessage {
    switch (status) {
      case EmergencyCallStatus.callRequested:
        return 'emergency_call_requested'.tr();
      case EmergencyCallStatus.dialerRequested:
        return 'emergency_dialer_requested'.tr();
      case EmergencyCallStatus.failed:
        return 'emergency_call_failed_status'.tr();
    }
  }
}
