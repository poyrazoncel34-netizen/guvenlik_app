import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/offline_queue_service.dart';

void main() {
  group('OfflineEvent', () {
    test('toJson and fromJson round-trip', () {
      final now = DateTime(2026, 3, 15, 12, 0, 0);
      final event = OfflineEvent(
        type: 'emergency',
        title: 'Panik butonu',
        description: 'Acil durum tetiklendi',
        data: {'lat': 41.0, 'lng': 29.0, 'message': 'Yardım!'},
        createdAt: now,
      );

      final json = event.toJson();
      final restored = OfflineEvent.fromJson(json);

      expect(restored.type, 'emergency');
      expect(restored.title, 'Panik butonu');
      expect(restored.description, 'Acil durum tetiklendi');
      expect(restored.data?['lat'], 41.0);
      expect(restored.data?['lng'], 29.0);
      expect(restored.data?['message'], 'Yardım!');
      expect(restored.createdAt, now);
    });

    test('fromJson handles missing fields gracefully', () {
      final event = OfflineEvent.fromJson({});
      expect(event.type, 'unknown');
      expect(event.title, '');
      expect(event.description, isNull);
      expect(event.data, isNull);
    });

    test('fromJson handles invalid createdAt', () {
      final event = OfflineEvent.fromJson({
        'type': 'test',
        'title': 'Test',
        'createdAt': 'not-a-date',
      });
      expect(event.type, 'test');
      // Should fall back to DateTime.now() without throwing
      expect(event.createdAt, isNotNull);
    });

    test('createdAt defaults to now when not provided', () {
      final before = DateTime.now();
      final event = OfflineEvent(type: 'test', title: 'Test');
      final after = DateTime.now();

      expect(
        event.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        event.createdAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('toJson includes all fields', () {
      final event = OfflineEvent(
        type: 'check_in',
        title: 'Check-in expired',
        description: 'Grace period ended',
        data: {'duration': 300},
        createdAt: DateTime(2026, 1, 1),
      );

      final json = event.toJson();
      expect(json['type'], 'check_in');
      expect(json['title'], 'Check-in expired');
      expect(json['description'], 'Grace period ended');
      expect(json['data'], {'duration': 300});
      expect(json['createdAt'], '2026-01-01T00:00:00.000');
    });

    test('toJson handles null description and data', () {
      final event = OfflineEvent(type: 'test', title: 'Test');
      final json = event.toJson();
      expect(json['description'], isNull);
      expect(json['data'], isNull);
    });
  });
}
