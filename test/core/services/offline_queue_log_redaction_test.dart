import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('local queue processing never writes event PII to debug logs', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OfflineQueueService.instance.dispose();
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() {
      debugPrint = originalDebugPrint;
      OfflineQueueService.instance.dispose();
    });

    await OfflineQueueService.instance.enqueue(
      OfflineEvent(
        type: 'emergency',
        title: 'CANARY_PRIVATE_TITLE',
        description: 'CANARY_PRIVATE_DESCRIPTION',
        data: <String, Object?>{
          'lat': 40.987654,
          'lng': 29.123456,
          'message': 'CANARY_PRIVATE_MESSAGE',
          'phone': '+905551112233',
        },
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    final persisted = (prefs.getStringList('offline_event_queue') ?? <String>[])
        .join('\n');
    for (final secret in <String>[
      'CANARY_PRIVATE_TITLE',
      'CANARY_PRIVATE_DESCRIPTION',
      'CANARY_PRIVATE_MESSAGE',
      '40.987654',
      '29.123456',
      '+905551112233',
    ]) {
      expect(persisted, isNot(contains(secret)), reason: 'persisted $secret');
    }
    await OfflineQueueService.instance.processPendingEventsLocal();

    final output = messages.join('\n');
    for (final secret in <String>[
      'CANARY_PRIVATE_TITLE',
      'CANARY_PRIVATE_DESCRIPTION',
      'CANARY_PRIVATE_MESSAGE',
      '40.987654',
      '29.123456',
      '+905551112233',
    ]) {
      expect(output, isNot(contains(secret)), reason: 'leaked $secret');
    }
    expect(output, contains('OfflineQueue: local event processed'));
  });
}
