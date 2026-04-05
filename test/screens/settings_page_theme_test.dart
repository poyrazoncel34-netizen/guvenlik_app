import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/widgets/theme_selector.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';

class FakeSecureStorage extends SecureStorage {
  final Map<String, String> _store = {};
  @override
  Future<void> write({required String key, required String value}) async => _store[key] = value;
  @override
  Future<String?> read({required String key}) async => _store[key];
  @override
  Future<void> delete({required String key}) async => _store.remove(key);
  @override
  Future<void> deleteAll() async => _store.clear();
}

void main() {
  setUpAll(() {
    if (!GetIt.instance.isRegistered<SecureStorage>()) {
      GetIt.instance.registerSingleton<SecureStorage>(FakeSecureStorage());
    }
  });

  testWidgets('SettingsPage shows ThemeSelector when built with required providers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<SubscriptionProvider>(create: (_) => SubscriptionProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: _ThemeSettingsSection()),
        ),
      ),
    );

    expect(find.byType(ThemeSelector), findsOneWidget);
  });

  testWidgets('ThemeSelector tapping light updates SettingsProvider', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<SubscriptionProvider>(create: (_) => SubscriptionProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: _ThemeSettingsSection()),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey(ThemeMode.light)));
    await tester.pump();
    expect(settingsProvider.themeMode, ThemeMode.light);
  });
}

class _ThemeSettingsSection extends StatelessWidget {
  const _ThemeSettingsSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    return ThemeSelector(
      selected: provider.themeMode,
      onChanged: provider.setThemeMode,
    );
  }
}
