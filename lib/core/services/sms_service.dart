import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

import 'android_intent_service.dart';
import 'consent_gate_service.dart';
import 'emergency_platform_service.dart';

enum SmsComposeStatus {
  nativeDispatched,
  composerOpened,
  composerOpenedPrimaryOnly,
  failed,
}

class SmsComposeResult {
  final SmsComposeStatus status;
  final List<String> recipients;
  final String? fallbackPayload;
  final String? errorMessage;

  const SmsComposeResult._({
    required this.status,
    required this.recipients,
    this.fallbackPayload,
    this.errorMessage,
  });

  factory SmsComposeResult.nativeDispatched(List<String> recipients) {
    return SmsComposeResult._(
      status: SmsComposeStatus.nativeDispatched,
      recipients: recipients,
    );
  }

  factory SmsComposeResult.opened(List<String> recipients) {
    return SmsComposeResult._(
      status: SmsComposeStatus.composerOpened,
      recipients: recipients,
    );
  }

  factory SmsComposeResult.primaryOnly({
    required List<String> recipients,
    required String fallbackPayload,
  }) {
    return SmsComposeResult._(
      status: SmsComposeStatus.composerOpenedPrimaryOnly,
      recipients: recipients,
      fallbackPayload: fallbackPayload,
    );
  }

  factory SmsComposeResult.failed(String message) {
    return SmsComposeResult._(
      status: SmsComposeStatus.failed,
      recipients: const [],
      errorMessage: message,
    );
  }

  bool get isSuccess => status != SmsComposeStatus.failed;
  bool get isPartial => status == SmsComposeStatus.composerOpenedPrimaryOnly;

  String get statusMessage {
    switch (status) {
      case SmsComposeStatus.nativeDispatched:
        return 'Yerel SMS gonderimi baslatildi';
      case SmsComposeStatus.composerOpened:
        return 'sms_composer_opened'.tr();
      case SmsComposeStatus.composerOpenedPrimaryOnly:
        return 'sms_composer_partial'.tr();
      case SmsComposeStatus.failed:
        return errorMessage ?? 'sms_composer_failed'.tr();
    }
  }

  String? get inlineNotice {
    if (status == SmsComposeStatus.composerOpened) {
      return null;
    }
    return statusMessage;
  }
}

class SmsService {
  static Future<SmsComposeResult> sendSms({
    required List<String> numbers,
    required String message,
  }) async {
    // KVKK m.5: Log consent status but never block emergency SMS
    if (!ConsentGateService.isEmergencyContactsAllowed()) {
      // ignore: avoid_print
      print('[SmsService] Consent gate returned false, proceeding for safety');
    }

    final recipients = numbers
        .map(AndroidIntentService.normalizePhoneNumber)
        .where((number) => number.isNotEmpty)
        .where(_isValidPhoneNumber)
        .toSet()
        .toList(growable: false);

    if (recipients.isEmpty) {
      return SmsComposeResult.failed('sms_no_recipients'.tr());
    }

    if (EmergencyPlatformService.instance.isSupported) {
      final response = await EmergencyPlatformService.instance.sendSms(
        recipients: recipients,
        message: message,
      );
      final status = response['status']?.toString();
      if (status == 'nativeDispatched') {
        return SmsComposeResult.nativeDispatched(recipients);
      }
      if (status == 'composerOpened') {
        return SmsComposeResult.opened(recipients);
      }
      if (status == 'failed') {
        return SmsComposeResult.failed(_mapNativeError(response['error']));
      }
    }

    final groupedOpened = await AndroidIntentService.composeSms(
      recipients: recipients,
      message: message,
    );
    if (groupedOpened) {
      return SmsComposeResult.opened(recipients);
    }

    final primaryOpened = await AndroidIntentService.composeSms(
      recipients: [recipients.first],
      message: message,
    );
    if (primaryOpened) {
      final payload = _buildFallbackPayload(
        recipients: recipients,
        message: message,
      );
      await Clipboard.setData(ClipboardData(text: payload));
      return SmsComposeResult.primaryOnly(
        recipients: recipients,
        fallbackPayload: payload,
      );
    }

    return SmsComposeResult.failed('sms_composer_failed'.tr());
  }

  static String _buildFallbackPayload({
    required List<String> recipients,
    required String message,
  }) {
    return [
      'sms_fallback_recipients'.tr(
        namedArgs: {'numbers': recipients.join(', ')},
      ),
      '',
      message,
    ].join('\n');
  }

  static bool _isValidPhoneNumber(String number) {
    final digitsOnly = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsOnly.length < 7) return false;
    if (!RegExp(r'^[+\d]').hasMatch(digitsOnly)) return false;
    return true;
  }

  static String _mapNativeError(Object? error) {
    switch (error?.toString()) {
      case 'airplane_mode':
        return 'Ucak modu acik. SMS gonderilemez.';
      case 'sim_unavailable':
        return 'SIM kart bulunamadi veya hazir degil.';
      case 'no_recipients':
        return 'sms_no_recipients'.tr();
      default:
        return 'sms_composer_failed'.tr();
    }
  }
}
