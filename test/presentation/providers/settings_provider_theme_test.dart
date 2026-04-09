import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  group('SettingsProvider themeMode', () {
    late MockSecureStorage mockStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GetIt.instance.reset();
      mockStorage = MockSecureStorage();
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      GetIt.instance.registerSingleton<SecureStorage>(mockStorage);
    });

    tearDown(() async {
      await GetIt.instance.reset();
    });

    test('themeMode defaults to ThemeMode.system when no prefs saved', () async {
      final provider = SettingsProvider();
      await provider.loadProfile();
      expect(provider.themeMode, equals(ThemeMode.system));
    });

    test('setThemeMode persists and updates themeMode', () async {
      final provider = SettingsProvider();
      await provider.loadProfile();

      await provider.setThemeMode(ThemeMode.dark);

      expect(provider.themeMode, equals(ThemeMode.dark));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.prefThemeMode), equals('dark'));
    });
  });
}
