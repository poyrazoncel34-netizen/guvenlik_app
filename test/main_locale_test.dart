// startLocale: Locale('tr', 'TR') ile İngilizce cihazda uygulama Türkçe açılır.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asset dosyası yüklemeden çalışan in-memory çeviri yükleyici.
class _MapAssetLoader extends AssetLoader {
  final Map<String, Map<String, dynamic>> _data;
  const _MapAssetLoader(this._data);

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final key = locale.countryCode != null
        ? '${locale.languageCode}-${locale.countryCode}'
        : locale.languageCode;
    return _data[key] ?? {};
  }
}

const _trTranslations = {'legal_age_title': 'Yaş Doğrulama'};
const _enTranslations = {'legal_age_title': 'Age Verification'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // SharedPreferences mock'u ensureInitialized'dan ÖNCE kurulmalı
    SharedPreferences.setMockInitialValues({});
    // _deviceLocale static alanını findSystemLocale() ile başlat
    await EasyLocalization.ensureInitialized();
  });

  testWidgets(
    'İngilizce cihazda uygulama Türkçe başlamalı (startLocale tr-TR gerekli)',
    (tester) async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('tr', 'TR')],
          path: 'assets/translations',
          assetLoader: const _MapAssetLoader({
            'tr-TR': _trTranslations,
            'en-US': _enTranslations,
          }),
          fallbackLocale: const Locale('tr', 'TR'),
          startLocale: const Locale('tr', 'TR'),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(body: Text('legal_age_title'.tr())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Yaş Doğrulama'),
        findsOneWidget,
        reason:
            'Cihaz dili İngilizce olsa bile uygulama Türkçe başlamalı. '
            "startLocale: const Locale('tr', 'TR') eklenmeli.",
      );
    },
  );
}
