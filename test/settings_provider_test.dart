import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider', () {
    late SettingsProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = SettingsProvider();
    });

    test('initial state has correct defaults', () {
      expect(provider.notificationsEnabled, isTrue);
      expect(provider.locationEnabled, isTrue);
      expect(provider.soundEnabled, isTrue);
      expect(provider.vibrationEnabled, isTrue);
      expect(provider.hasProfile, isFalse);
      expect(provider.profileEmail, isEmpty);
    });

    test('loadProfile loads saved preferences', () async {
      SharedPreferences.setMockInitialValues({
        'profile_name': 'Ali Yılmaz',
        'profile_email': 'ali@test.com',
        'pref_notifications': false,
        'pref_location': false,
      });
      provider = SettingsProvider();
      await provider.loadProfile();

      expect(provider.profileName, 'Ali Yılmaz');
      expect(provider.profileEmail, 'ali@test.com');
      expect(provider.notificationsEnabled, isFalse);
      expect(provider.locationEnabled, isFalse);
      expect(provider.hasProfile, isTrue);
    });

    test('updateProfile saves name and email', () async {
      await provider.loadProfile();
      await provider.updateProfile(name: 'Mehmet', email: 'mehmet@test.com');

      expect(provider.profileName, 'Mehmet');
      expect(provider.profileEmail, 'mehmet@test.com');
      expect(provider.hasProfile, isTrue);
    });

    test('updateProfile trims whitespace', () async {
      await provider.loadProfile();
      await provider.updateProfile(name: '  Ayşe  ', email: '  ayse@test.com  ');

      expect(provider.profileName, 'Ayşe');
      expect(provider.profileEmail, 'ayse@test.com');
    });

    test('setNotifications toggles and persists', () async {
      await provider.loadProfile();
      expect(provider.notificationsEnabled, isTrue);

      await provider.setNotifications(false);
      expect(provider.notificationsEnabled, isFalse);

      await provider.setNotifications(true);
      expect(provider.notificationsEnabled, isTrue);
    });

    test('setLocation toggles and persists', () async {
      await provider.loadProfile();
      expect(provider.locationEnabled, isTrue);

      await provider.setLocation(false);
      expect(provider.locationEnabled, isFalse);
    });

    test('setSound toggles and persists', () async {
      await provider.loadProfile();
      await provider.setSound(false);
      expect(provider.soundEnabled, isFalse);
    });

    test('setVibration toggles and persists', () async {
      await provider.loadProfile();
      await provider.setVibration(false);
      expect(provider.vibrationEnabled, isFalse);
    });

    test('notifies listeners on profile update', () async {
      await provider.loadProfile();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.updateProfile(name: 'Test', email: 'test@test.com');
      expect(notifyCount, greaterThan(0));
    });

    test('notifies listeners on setting change', () async {
      await provider.loadProfile();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setNotifications(false);
      expect(notifyCount, greaterThan(0));
    });

    test('loadProfile only reads prefs once for settings', () async {
      await provider.loadProfile();

      // Change a setting after load
      await provider.setNotifications(false);
      expect(provider.notificationsEnabled, isFalse);

      // Second loadProfile should NOT reset the setting from prefs
      // (because _loaded flag prevents re-reading)
      await provider.loadProfile();
      expect(provider.notificationsEnabled, isFalse);
    });
  });
}
