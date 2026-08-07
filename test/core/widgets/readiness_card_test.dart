// The readiness card is the first thing a user reads on the home screen, and
// this app is a fear product: what it *says* about an incomplete setup is a
// safety-copy decision, not styling. These tests pin the three states and the
// rule that "setup complete" can never outrun the platform snapshot.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/widgets/readiness_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MapAssetLoader extends AssetLoader {
  const _MapAssetLoader(this._data);
  final Map<String, Map<String, dynamic>> _data;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final key = locale.countryCode != null
        ? '${locale.languageCode}-${locale.countryCode}'
        : locale.languageCode;
    return _data[key] ?? {};
  }
}

const _tr = {
  'ready': 'Kurulum tamam',
  'system_ready_desc': 'Acil kişin kayıtlı, arama izni açık.',
  'setup_incomplete': 'Kuruluma {count} adım kaldı',
  'setup_incomplete_desc': 'Önce acil kişini ekleyelim; gerisi bekleyebilir.',
  'readiness_almost_title': 'Kurulumun büyük bölümü tamam',
  'readiness_almost_desc': 'Tek eksik: {item}. Yaklaşık 30 saniye sürer.',
  'readiness_background_note': 'Ekran kapalıyken zamanlayıcılar gecikebilir.',
  'readiness_auto_call_note': 'Bu cihaz aramayı kendi başlatamıyor.',
  'readiness_last_rehearsal': 'Son prova: {date}',
  'readiness_no_rehearsal': 'Henüz prova yapmadın.',
  'call_permission_fallback_note': 'İzin verilmedi',
  'emergency_contact': 'Acil kişi',
  'phone_call_permission': 'Telefon Araması',
  'background_readiness': 'Arka Plan Hazırlığı',
  'location': 'Konum',
  'contacts': 'Rehber',
};

PlatformReadinessSnapshot _snapshot({
  bool callPermission = true,
  bool telephony = true,
  bool exactAlarm = true,
}) => PlatformReadinessSnapshot(
  supportedOs: true,
  telephonyCalling: telephony,
  telecomAvailable: telephony,
  dialHandlerAvailable: telephony,
  batteryOptimizationWhitelisted: true,
  exactAlarmPermission: exactAlarm,
  callPermission: callPermission,
  notificationPermission: true,
  alertChannelHigh: true,
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required bool locationGranted,
  required bool contactsGranted,
  required bool hasEmergencyContact,
  required PlatformReadinessSnapshot? readiness,
  DateTime? lastRehearsalAt,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: const _MapAssetLoader({'tr-TR': _tr}),
      fallbackLocale: const Locale('tr', 'TR'),
      startLocale: const Locale('tr', 'TR'),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReadinessCard(
                locationGranted: locationGranted,
                contactsGranted: contactsGranted,
                hasEmergencyContact: hasEmergencyContact,
                readiness: readiness,
                lastRehearsalAt: lastRehearsalAt,
                onFixEmergencyContact: () {},
                onFixCallPermission: () {},
                onFixBackground: () {},
                onFixLocation: () {},
                onFixContacts: () {},
                onRunRehearsal: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('a fully ready setup reports completion, not a warning', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      locationGranted: true,
      contactsGranted: true,
      hasEmergencyContact: true,
      readiness: _snapshot(),
    );

    expect(find.text('Kurulum tamam'), findsOneWidget);
    expect(find.textContaining('adım kaldı'), findsNothing);
  });

  testWidgets('one missing item names that item instead of scolding', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      locationGranted: false,
      contactsGranted: true,
      hasEmergencyContact: true,
      readiness: _snapshot(),
    );

    expect(find.text('Kurulumun büyük bölümü tamam'), findsOneWidget);
    expect(find.textContaining('Tek eksik: Konum'), findsOneWidget);
  });

  testWidgets('several missing items count forward, never "hazırlık eksik"', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      locationGranted: false,
      contactsGranted: false,
      hasEmergencyContact: false,
      readiness: _snapshot(callPermission: false, exactAlarm: false),
    );

    expect(find.text('Kuruluma 5 adım kaldı'), findsOneWidget);
    expect(find.textContaining('Hazırlık eksik'), findsNothing);
  });

  testWidgets('an unknown platform snapshot never claims a complete setup', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      locationGranted: true,
      contactsGranted: true,
      hasEmergencyContact: true,
      readiness: null,
    );

    expect(find.text('Kurulum tamam'), findsNothing);
  });

  testWidgets(
    'a device that cannot dial is not reported as ready even with permission',
    (tester) async {
      await _pumpCard(
        tester,
        locationGranted: true,
        contactsGranted: true,
        hasEmergencyContact: true,
        readiness: _snapshot(telephony: false),
      );

      expect(find.text('Kurulum tamam'), findsNothing);
      expect(find.text('Bu cihaz aramayı kendi başlatamıyor.'), findsOneWidget);
    },
  );

  testWidgets('a never-rehearsed setup states the fact without blame', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      locationGranted: true,
      contactsGranted: true,
      hasEmergencyContact: true,
      readiness: _snapshot(),
      lastRehearsalAt: null,
    );

    expect(find.text('Henüz prova yapmadın.'), findsOneWidget);
  });

  testWidgets('a recorded rehearsal is shown as a dated record', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      locationGranted: true,
      contactsGranted: true,
      hasEmergencyContact: true,
      readiness: _snapshot(),
      lastRehearsalAt: DateTime(2026, 3, 12),
    );

    expect(find.text('Son prova: 12.03.2026'), findsOneWidget);
  });
}
