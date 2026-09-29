import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/presentation/providers/settings_provider.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/battery_optimization_wizard.dart';
import 'package:guvenlik_app/screens/oem_background_guide_screen.dart';
import 'package:guvenlik_app/screens/profile_page.dart';
import 'package:guvenlik_app/screens/settings_detail_page.dart';
import 'package:guvenlik_app/screens/settings_legal/legal_settings_screen.dart';
import 'package:guvenlik_app/screens/settings_notifications/notification_categories_screen.dart';
import 'package:guvenlik_app/screens/settings_page.dart';
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

Future<SettingsProvider> _pumpSettings(WidgetTester tester) async {
  final settings = SettingsProvider();
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: const _RealTrAssetLoader(),
      startLocale: const Locale('tr', 'TR'),
      fallbackLocale: const Locale('tr', 'TR'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<SubscriptionProvider>(
            create: (_) => SubscriptionProvider(),
          ),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: const SettingsPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

Future<void> _tapVisible(WidgetTester tester, String text) async {
  final matches = find.text(text);
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      matches,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final finder = matches.last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapTile(WidgetTester tester, String text) async {
  final tile = find.widgetWithText(InkWell, text);
  if (tile.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(tile.last);
  await tester.tap(tile.last);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  setUpAll(() {
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'areNotificationsEnabled') return true;
          if (call.method == 'getNotificationChannels') return <Object?>[];
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.prefProfileName: 'Ada Lovelace',
    });
    PackageInfo.setMockInitialValues(
      appName: 'KoruBeni',
      packageName: 'com.example.korubeni',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
  });

  testWidgets('AYR-01/AYR-03/AYR-04: settings opens real destination surfaces', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await _tapTile(tester, 'Ada Lovelace');
    expect(find.byType(ProfilePage), findsOneWidget);
    await _back(tester);

    await _tapTile(tester, 'Bildirimler');
    expect(find.byType(NotificationCategoriesScreen), findsOneWidget);
    await _back(tester);

    await _tapTile(tester, 'PIN Ayarları');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets(
    'AYR-05/AYR-06/AYR-07: Android rows navigate and sound tap persists state',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final settings = await _pumpSettings(tester);

      await _tapTile(tester, 'Pil Optimizasyonu');
      expect(find.byType(BatteryOptimizationWizard), findsOneWidget);
      await _back(tester);

      await _tapTile(tester, 'Cihaza Özel Arka Plan Ayarları');
      expect(find.byType(OemBackgroundGuideScreen), findsOneWidget);
      await _back(tester);

      expect(settings.soundEnabled, isTrue);
      final soundLabel = find.text('Ses Efektleri');
      await tester.scrollUntilVisible(
        soundLabel,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(settings.soundEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.prefSound), isFalse);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'AYR-09/AYR-10/AYR-11/AYR-13/AYR-16: legal, details and reset routes are wired',
    (tester) async {
      await _pumpSettings(tester);

      await _tapTile(tester, 'Yasal Bilgiler & KVKK');
      expect(find.byType(LegalSettingsScreen), findsOneWidget);
      await _back(tester);

      for (final entry in <(String, String)>[
        ('Uygulama Hakkında', 'settings_about_app'),
        ('Gizlilik Politikası', 'settings_privacy_policy'),
        ('Yardım & Destek', 'settings_help'),
      ]) {
        await _tapTile(tester, entry.$1);
        final detail = tester.widget<SettingsDetailPage>(
          find.byType(SettingsDetailPage),
        );
        expect(detail.sectionKey, entry.$2);
        await _back(tester);
      }

      await _tapVisible(tester, 'Cihaz Verilerini Temizle');
      expect(find.byType(AlertDialog), findsOneWidget);
      await _tapVisible(tester, 'İptal');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
