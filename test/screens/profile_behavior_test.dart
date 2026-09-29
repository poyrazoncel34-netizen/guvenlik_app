import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';
import 'package:guvenlik_app/screens/edit_profile_screen.dart';
import 'package:guvenlik_app/screens/profile_page.dart';
import 'package:guvenlik_app/screens/settings_detail_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

Future<SettingsProvider> _pumpProfile(WidgetTester tester) async {
  final provider = SettingsProvider();
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: const _RealTrAssetLoader(),
      startLocale: const Locale('tr', 'TR'),
      fallbackLocale: const Locale('tr', 'TR'),
      child: ChangeNotifierProvider<SettingsProvider>.value(
        value: provider,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: const ProfilePage(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.prefProfileName: 'Ada Lovelace',
    });
    PackageInfo.setMockInitialValues(
      appName: 'KoruBeni',
      packageName: 'com.example.korubeni',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets(
    'PRF-01/PRF-05: real profile route validates, saves, pops and refreshes the name',
    (tester) async {
      final provider = await _pumpProfile(tester);
      expect(find.text('Ada Lovelace'), findsOneWidget);

      await _tapText(tester, 'Kişisel Bilgiler');
      expect(find.byType(EditProfileScreen), findsOneWidget);

      final field = find.byType(TextFormField);
      await tester.enterText(field, 'A');
      await _tapText(tester, 'Kaydet');
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.text('Lütfen formu doğru doldurun'), findsOneWidget);

      await tester.enterText(field, '  Grace Hopper  ');
      await _tapText(tester, 'Kaydet');

      expect(find.byType(EditProfileScreen), findsNothing);
      expect(provider.profileName, 'Grace Hopper');
      expect(find.text('Grace Hopper'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.prefProfileName), 'Grace Hopper');
    },
  );

  testWidgets(
    'PRF-02: security row opens the real PIN change bottom sheet',
    (tester) async {
      await _pumpProfile(tester);

      await _tapText(tester, 'Güvenlik & PIN');

      expect(find.text('PIN Ayarları'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Kaydet'), findsOneWidget);
    },
  );

  testWidgets(
    'PRF-03/AYR-17: notifications opens production detail and its back button pops',
    (tester) async {
      await _pumpProfile(tester);

      await _tapText(tester, 'Bildirimler');
      expect(find.byType(SettingsDetailPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsDetailPage), findsNothing);
      expect(find.byType(ProfilePage), findsOneWidget);
    },
  );

  testWidgets('PRF-04/SIF-01: reset dialog cancel closes without deleting data', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await _tapText(tester, 'Cihaz Verilerini Temizle');
    expect(find.byType(AlertDialog), findsOneWidget);

    await _tapText(tester, 'İptal');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ProfilePage), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConstants.prefProfileName), 'Ada Lovelace');
  });
}
