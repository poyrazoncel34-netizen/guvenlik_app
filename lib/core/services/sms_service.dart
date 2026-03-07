import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

import 'android_intent_service.dart';

enum SmsComposeStatus {
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
    final recipients = numbers
        .map(AndroidIntentService.normalizePhoneNumber)
        .where((number) => number.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (recipients.isEmpty) {
      return SmsComposeResult.failed('sms_no_recipients'.tr());
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
      'sms_fallback_recipients'.tr(namedArgs: {'numbers': recipients.join(', ')}),
      '',
      message,
    ].join('\n');
  }
}
