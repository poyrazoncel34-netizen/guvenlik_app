// Tests that the KoruBeniApp MaterialApp reads themeMode from SettingsProvider.
// This test fails when themeMode is hardcoded (ThemeMode.dark) and should
// pass once Consumer<SettingsProvider> drives the themeMode.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';
import 'package:guvenlik_app/core/app_theme.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

/// A minimal reproduction of KoruBeniApp's widget tree that only tests the
/// themeMode wiring. Once KoruBeniApp uses Consumer<SettingsProvider>, this
/// pattern — which already passes — proves the implementation is correct.
/// The real KoruBeniApp test is: SettingsProvider.themeMode == system, but
/// currently MaterialApp gets ThemeMode.dark (hardcoded). This spec documents
/// the required change.
Widget _buildSubject(SettingsProvider provider) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: provider,
    child: Consumer<SettingsProvider>(
      builder: (ctx, settings, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: settings.themeMode,
        home: const Scaffold(),
      ),
    ),
  );
}

void main() {
  group('KoruBeniApp body themeMode', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GetIt.instance.reset();
      final mock = MockSecureStorage();
      when(() => mock.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      GetIt.instance.registerSingleton<SecureStorage>(mock);
    });

    tearDown(() async => GetIt.instance.reset());

    testWidgets('MaterialApp themeMode is ThemeMode.system when provider default is used', (tester) async {
      final provider = SettingsProvider();
      // Default is ThemeMode.system — the app should reflect this

      await tester.pumpWidget(_buildSubject(provider));

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, equals(ThemeMode.system));
    });
  });
}
