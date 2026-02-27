import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/domain/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('fromJson creates instance with all fields', () {
      final json = {
        'uid': 'test-uid-123',
        'phone': '+905551234567',
        'displayName': 'Test User',
        'email': 'test@test.com',
        'fcmToken': 'token-abc',
        'lastActiveAt': '2026-01-15T10:30:00.000Z',
        'createdAt': '2026-01-01T00:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.uid, 'test-uid-123');
      expect(profile.phone, '+905551234567');
      expect(profile.displayName, 'Test User');
      expect(profile.email, 'test@test.com');
      expect(profile.fcmToken, 'token-abc');
      expect(profile.lastActiveAt, isNotNull);
      expect(profile.createdAt, isNotNull);
    });

    test('fromJson handles missing fields gracefully', () {
      final json = <String, dynamic>{};

      final profile = UserProfile.fromJson(json);

      expect(profile.uid, '');
      expect(profile.phone, isNull);
      expect(profile.displayName, isNull);
      expect(profile.email, isNull);
      expect(profile.fcmToken, isNull);
      expect(profile.lastActiveAt, isNull);
      expect(profile.createdAt, isNull);
    });

    test('fromJson handles partial data', () {
      final json = {
        'uid': 'partial-uid',
        'phone': '+901112223344',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.uid, 'partial-uid');
      expect(profile.phone, '+901112223344');
      expect(profile.displayName, isNull);
    });

    test('toJson produces correct map', () {
      final profile = UserProfile(
        uid: 'uid-1',
        phone: '+905551234567',
        displayName: 'Ali',
        email: 'ali@example.com',
        createdAt: DateTime(2026, 1, 1),
      );

      final json = profile.toJson();

      expect(json['uid'], 'uid-1');
      expect(json['phone'], '+905551234567');
      expect(json['displayName'], 'Ali');
      expect(json['email'], 'ali@example.com');
      expect(json.containsKey('createdAt'), isTrue);
      expect(json['fcmToken'], isNull); // fcmToken not set, so null
    });

    test('toJson omits null timestamp fields', () {
      final profile = UserProfile(uid: 'uid-2');
      final json = profile.toJson();

      expect(json.containsKey('lastActiveAt'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
    });

    test('toJson/fromJson round-trip preserves data', () {
      final original = UserProfile(
        uid: 'round-trip-uid',
        phone: '+905557654321',
        displayName: 'Round Trip',
        email: 'rt@test.com',
        fcmToken: 'token-xyz',
        createdAt: DateTime(2026, 2, 15, 10, 30),
      );

      final json = original.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.uid, original.uid);
      expect(restored.phone, original.phone);
      expect(restored.displayName, original.displayName);
      expect(restored.email, original.email);
      expect(restored.fcmToken, original.fcmToken);
    });

    test('copyWith produces updated copy', () {
      final original = UserProfile(
        uid: 'uid-copy',
        displayName: 'Original',
      );

      final updated = original.copyWith(displayName: 'Updated');

      expect(updated.uid, 'uid-copy');
      expect(updated.displayName, 'Updated');
      expect(original.displayName, 'Original');
    });

    test('equality is based on uid', () {
      final a = UserProfile(uid: 'same-uid', displayName: 'A');
      final b = UserProfile(uid: 'same-uid', displayName: 'B');
      final c = UserProfile(uid: 'different-uid');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns readable output', () {
      final profile = UserProfile(
        uid: 'uid-str',
        phone: '+90555',
        displayName: 'Test',
      );
      expect(profile.toString(), contains('uid-str'));
      expect(profile.toString(), contains('Test'));
    });

    test('fromJson handles invalid timestamp string', () {
      final json = {
        'uid': 'uid-invalid-ts',
        'createdAt': 'not-a-date',
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.createdAt, isNull);
    });
  });
}
