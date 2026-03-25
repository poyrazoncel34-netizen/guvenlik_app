import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';

class FakeSecureStorage extends SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> delete({required String key}) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}

void main() {
  late SettingsProvider provider;

  setUpAll(() {
    if (!GetIt.instance.isRegistered<SecureStorage>()) {
      GetIt.instance.registerSingleton<SecureStorage>(FakeSecureStorage());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = SettingsProvider();
  });

  group('SettingsProvider.themeMode', () {
    test('defaults to ThemeMode.dark', () {
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('setThemeMode updates themeMode and persists to SharedPreferences', () async {
      await provider.setThemeMode(ThemeMode.system);
      expect(provider.themeMode, ThemeMode.system);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('pref_theme_mode'), ThemeMode.system.index);
    });

    test('loadProfile restores persisted themeMode', () async {
      SharedPreferences.setMockInitialValues({'pref_theme_mode': ThemeMode.light.index});
      final freshProvider = SettingsProvider();
      await freshProvider.loadProfile();
      expect(freshProvider.themeMode, ThemeMode.light);
    });
  });

  group('MaterialApp themeMode wiring', () {
    testWidgets('MaterialApp themeMode updates when SettingsProvider changes', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: provider,
          child: Consumer<SettingsProvider>(
            builder: (context, settings, _) => MaterialApp(
              theme: ThemeData(brightness: Brightness.light),
              darkTheme: ThemeData(brightness: Brightness.dark),
              themeMode: settings.themeMode,
              home: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);

      await provider.setThemeMode(ThemeMode.light);
      await tester.pump();

      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
    });
  });
}
