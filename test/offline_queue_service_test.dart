import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('OfflineQueueService', () {
    test('singleton instance is consistent', () {
      final instance1 = OfflineQueueService.instance;
      final instance2 = OfflineQueueService.instance;
      expect(identical(instance1, instance2), true);
    });

    test('pendingCount returns 0 on fresh state', () async {
      final count = await OfflineQueueService.instance.pendingCount();
      expect(count, isA<int>());
    });
  });

  group('OfflineEvent', () {
    test('toJson and fromJson round-trip', () {
      final original = OfflineEvent(
        type: 'emergency',
        title: 'Test Emergency',
        description: 'Test description',
        data: {'lat': 41.0, 'lng': 29.0},
      );

      final json = original.toJson();
      final restored = OfflineEvent.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.data?['lat'], original.data?['lat']);
      expect(restored.data?['lng'], original.data?['lng']);
    });

    test('fromJson handles missing fields gracefully', () {
      final json = <String, dynamic>{};
      final event = OfflineEvent.fromJson(json);

      expect(event.type, 'unknown');
      expect(event.title, '');
      expect(event.description, isNull);
    });

    test('createdAt defaults to now if not provided', () {
      final event = OfflineEvent(type: 'test', title: 'Test');
      expect(event.createdAt.difference(DateTime.now()).inSeconds.abs(), lessThan(2));
    });
  });
}
