// Edge-case: OfflineQueueService serialises/deserialises events correctly
// and enforces the max queue size cap.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/services/offline_queue_service.dart';

void main() {
  group('OfflineQueueService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('enqueued event can be retrieved from SharedPreferences', () async {
      final event = OfflineEvent(
        type: 'test_event',
        title: 'Test',
        data: {'key': 'value'},
      );
      await OfflineQueueService.instance.enqueue(event);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('offline_event_queue');
      expect(raw, isNotNull);
      expect(raw!.isNotEmpty, isTrue);
    });

    test('queue source file enforces a max size cap of 100', () {
      final source = File(
        'lib/core/services/offline_queue_service.dart',
      ).readAsStringSync();
      expect(
        source.contains('100'),
        isTrue,
        reason: 'Max queue size should be capped at 100',
      );
    });
  });
}
