// Tests that KoruBeniApp wires themeMode from SettingsProvider rather
// than hardcoding it. The test pumps a minimal proxy widget that mirrors
// the exact pattern KoruBeniApp should use.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/widgets/app_theme_mode_wrapper.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  group('AppThemeModeWrapper', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GetIt.instance.reset();
      final mockStorage = MockSecureStorage();
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      GetIt.instance.registerSingleton<SecureStorage>(mockStorage);
    });

    tearDown(() async {
      await GetIt.instance.reset();
    });

    testWidgets('passes SettingsProvider.themeMode to MaterialApp', (tester) async {
      final provider = SettingsProvider();
      await provider.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: provider,
          child: AppThemeModeWrapper(
            child: const Scaffold(),
          ),
        ),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.light));
    });
  });
}
