import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/check_in_expiry_coordinator.dart';
import 'package:guvenlik_app/core/services/check_in_service.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';
import 'package:guvenlik_app/presentation/providers/home_provider.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/check_in_screen.dart';
import 'package:guvenlik_app/screens/contacts_page.dart';
import 'package:guvenlik_app/screens/safe_walk_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/contact_service_test_support.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final raw = File('assets/translations/tr-TR.json').readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

class _NoopContactsProvider extends ContactsProvider {
  @override
  Future<void> initialize() async {}
}

class _NoopHomeProvider extends HomeProvider {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshAfterContactsChanged() async {}
}

class _ContactsRepository implements ContactsRepository {
  _ContactsRepository({this.primary});

  EmergencyContact? primary;

  @override
  Future<void> clearPrimaryEmergencyContact() async => primary = null;

  @override
  Future<List<String>> getAllEmergencyNumbers() async =>
      primary == null ? const [] : [primary!.phone];

  @override
  Future<List<EmergencyContact>> getContactRecords() async =>
      primary == null ? const [] : [primary!];

  @override
  Future<List<String>> getContacts() => getAllEmergencyNumbers();

  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async => primary;

  @override
  Future<void> saveContactRecords(List<EmergencyContact> contacts) async {
    primary = contacts.isEmpty ? null : contacts.first;
  }

  @override
  Future<void> saveContacts(List<String> numbers) async {
    primary = numbers.isEmpty
        ? null
        : EmergencyContact(
            name: 'Acil Kişi',
            phone: numbers.first,
            isPrimary: true,
          );
  }

  @override
  Future<void> saveEmergencyNumbers(List<String> numbers) =>
      saveContacts(numbers);

  @override
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {
    primary = EmergencyContact(name: name, phone: phone, isPrimary: true);
  }
}

/// A verified subscriber, answered locally (no store in a widget test).
class _ProSubscription extends SubscriptionProvider {
  static final SubscriptionAccessState _pro = SubscriptionAccessState(
    status: SubscriptionAccessStatus.verifiedPro,
    lastVerifiedPro: true,
    lastVerifiedProAt: DateTime.now(),
  );

  @override
  SubscriptionAccessState get access => _pro;

  @override
  Future<void> ensureOfflineGraceLoaded() async {}

  @override
  Future<SubscriptionAccessState> resolveAccess() async => _pro;
}

class _Host extends StatelessWidget {
  const _Host({required this.destination});

  final Widget destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute<void>(builder: (_) => destination)),
          child: const Text('TEST_OPEN'),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  const channel = MethodChannel('safety_timer_screen_behavior_test');
  late FakeSecureStorage secureStorage;
  late FakeLocalDatabaseService database;
  final services = <CheckInService>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'warning_checkin_shown': true,
      'warning_walk_shown': true,
    });
    await serviceLocator.reset();
    secureStorage = FakeSecureStorage();
    database = FakeLocalDatabaseService();
    serviceLocator.registerSingleton<SecureStorage>(secureStorage);
    serviceLocator.registerSingleton<LocalDatabaseService>(database);
    ContactService.resetCache();
  });

  tearDown(() async {
    for (final service in services) {
      service.dispose();
    }
    services.clear();
    ContactService.resetCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await database.deleteDatabaseFile();
    await serviceLocator.reset();
  });

  Future<void> pumpDestination(
    WidgetTester tester,
    Widget destination, {
    SubscriptionProvider Function()? subscription,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'assets/translations',
        assetLoader: const _RealTrAssetLoader(),
        startLocale: const Locale('tr', 'TR'),
        fallbackLocale: const Locale('tr', 'TR'),
        child: Builder(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider<ContactsProvider>.value(
                value: _NoopContactsProvider(),
              ),
              ChangeNotifierProvider<HomeProvider>.value(
                value: _NoopHomeProvider(),
              ),
              ChangeNotifierProvider<SubscriptionProvider>(
                create: (_) => subscription?.call() ?? SubscriptionProvider(),
              ),
            ],
            child: MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: _Host(destination: destination),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.tap(find.text('TEST_OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  CheckInService makeService(EmergencySessionKind kind) {
    final contacts = _ContactsRepository(
      primary: const EmergencyContact(
        name: 'Acil Kişi',
        phone: '+905551112233',
        isPrimary: true,
      ),
    );
    final platform = EmergencyPlatformService.forTesting(
      methodChannel: channel,
      defaultTimeout: const Duration(milliseconds: 100),
      dispatchTimeout: const Duration(milliseconds: 100),
    );
    final service = CheckInService.forTesting(
      sessionId: kind == EmergencySessionKind.safeWalk
          ? CheckInExpiryCoordinator.safeWalkSession
          : CheckInExpiryCoordinator.checkInSession,
      platform: platform,
      contactsRepository: contacts,
    );
    services.add(service);
    return service;
  }

  Map<String, Object?> armedResponse(MethodCall call) {
    final arguments = call.arguments as Map<Object?, Object?>;
    return <String, Object?>{
      'type': 'armed',
      'token': <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'randomId': arguments['randomId'],
        'generation': arguments['requestedGeneration'],
        'kind': arguments['kind'],
      },
      'mainDeadlineMs': arguments['mainDeadlineMs'],
      'finalDeadlineMs': arguments['finalDeadlineMs'],
    };
  }

  Future<void> arm(CheckInService service) async {
    final result = await service.startSession(
      minutes: 15,
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
    );
    expect(result, isA<Armed>());
  }

  void installPlatformHandler({bool cancelSucceeds = true}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'armEmergencySession') return armedResponse(call);
          if (call.method == 'cancelEmergencySession') {
            final token = (call.arguments as Map<Object?, Object?>)['token'];
            return <String, Object?>{
              'type': cancelSucceeds ? 'cancelled' : 'tooLate',
              'token': token,
              if (!cancelSucceeds) 'terminalState': 'claimed',
            };
          }
          return <String, Object?>{'type': 'absent'};
        });
  }

  Future<void> submitPin(WidgetTester tester, String pin) async {
    await tester.enterText(find.byType(TextField), pin);
    await tester.tap(find.text('Doğrula'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> warmEmptyProductionContacts(WidgetTester tester) async {
    await tester.runAsync(ContactService.getContactRecords);
  }

  Future<void> disposeActiveService(
    WidgetTester tester,
    CheckInService service,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    service.dispose();
    services.remove(service);
  }

  // Audit §17 rapid input. Nothing guarded the start handler itself: a double
  // tap ran two start flows, the second reached the service while the first
  // was arming (operationInProgress) or had armed (sessionAlreadyActive), and
  // its rejection was shown as "Güvenlik oturumu kurulmadı" -- on top of a
  // session that WAS running.
  Future<List<String>> countArms(WidgetTester tester) async {
    final arms = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'armEmergencySession') {
            arms.add(call.method);
            return armedResponse(call);
          }
          return <String, Object?>{'type': 'absent'};
        });
    // The exact-alarm precheck goes through the production singleton channel.
    const production = MethodChannel(EmergencyPlatformService.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          production,
          (call) async => call.method == 'canScheduleExactAlarms' ? true : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(production, null),
    );
    // A configured PIN, as every real user has after onboarding.
    await tester.runAsync(
      () => secureStorage.write(key: SecureStorageKeys.userPin, value: '2468'),
    );
    await tester.runAsync(
      () => secureStorage.write(
        key: SecureStorageKeys.emergencyContactsV1,
        value: jsonEncode(<String, Object?>{
          'version': 1,
          'contacts': <Object?>[
            const EmergencyContact(
              name: 'Acil Kişi',
              phone: '+905551112233',
              isPrimary: true,
            ).toSecureJson(),
          ],
        }),
      ),
    );
    return arms;
  }

  Future<void> drive(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('CHK-DT: a double tap on a duration arms ONE session and shows '
      'no false failure', (tester) async {
    final arms = await countArms(tester);
    final service = makeService(EmergencySessionKind.checkIn);
    await pumpDestination(
      tester,
      CheckInScreen(service: service),
      subscription: _ProSubscription.new,
    );

    await tester.tap(find.text('15 dk'));
    await tester.tap(find.text('15 dk'));
    await drive(tester);

    expect(arms, hasLength(1));
    expect(service.isActive, isTrue);
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'the second tap reported a failure for a session that started',
    );
    await disposeActiveService(tester, service);
  });

  testWidgets('SWK-DT: a double tap on Start arms ONE walk and shows no '
      'false failure', (tester) async {
    final arms = await countArms(tester);
    final service = makeService(EmergencySessionKind.safeWalk);
    await pumpDestination(
      tester,
      SafeWalkScreen(controller: service),
      subscription: _ProSubscription.new,
    );

    final start = find.text('safe_walk_start'.tr());
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.tap(start);
    await drive(tester);

    expect(arms, hasLength(1));
    expect(service.isActive, isTrue);
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'the second tap reported a failure for a session that started',
    );
    await disposeActiveService(tester, service);
  });

  testWidgets('SWK-01: every production duration chip changes selection', (
    tester,
  ) async {
    final service = makeService(EmergencySessionKind.safeWalk);
    await pumpDestination(tester, SafeWalkScreen(controller: service));

    for (final minutes in [5, 10, 15, 30, 60]) {
      final label = '$minutes dk';
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 250));
      final scale = tester.widget<AnimatedScale>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(
        scale.scale,
        1.08,
        reason: '$label seçimi production state’e yazılmalı',
      );
    }
  });

  testWidgets(
    'CHK-01: all four duration choices execute missing-contact branch',
    (tester) async {
      final service = makeService(EmergencySessionKind.checkIn);
      await pumpDestination(tester, CheckInScreen(service: service));
      await warmEmptyProductionContacts(tester);

      for (final label in ['15 dk', '30 dk', '1 sa', '2 sa']) {
        await tester.tap(find.text(label));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          find.text(
            'Bu zamanlayıcıyı başlatmadan önce en az bir acil kişi ekleyin.',
          ),
          findsOneWidget,
          reason: '$label dokunuşu gerçek başlatma doğrulamasına ulaşmalı',
        );
        ScaffoldMessenger.of(
          tester.element(find.byType(CheckInScreen)),
        ).hideCurrentSnackBar();
        await tester.pump(const Duration(milliseconds: 300));
      }
    },
  );

  testWidgets(
    'CHK-03: contact-required action pushes production ContactsPage',
    (tester) async {
      final service = makeService(EmergencySessionKind.checkIn);
      await pumpDestination(tester, CheckInScreen(service: service));
      await warmEmptyProductionContacts(tester);

      await tester.tap(find.text('15 dk'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('Kişi Ekle'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(ContactsPage), findsOneWidget);
    },
  );

  testWidgets('CHK-14: system Back leaves an armed singleton session running', (
    tester,
  ) async {
    installPlatformHandler();
    final service = makeService(EmergencySessionKind.checkIn);
    await arm(service);
    await pumpDestination(tester, CheckInScreen(service: service));

    expect(service.isActive, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('TEST_OPEN'), findsOneWidget);
    expect(find.byType(CheckInScreen), findsNothing);
    expect(service.isActive, isTrue);
    service.dispose();
    services.remove(service);
  });

  testWidgets('SWK-07/08: active Back warns and Stay preserves the session', (
    tester,
  ) async {
    installPlatformHandler();
    final service = makeService(EmergencySessionKind.safeWalk);
    await arm(service);
    await pumpDestination(tester, SafeWalkScreen(controller: service));

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    expect(find.text('Dikkat'), findsOneWidget);
    expect(find.byType(SafeWalkScreen), findsOneWidget);

    await tester.tap(find.text('Kal'));
    await tester.pump();
    expect(find.text('Dikkat'), findsNothing);
    expect(find.byType(SafeWalkScreen), findsOneWidget);
    expect(service.isActive, isTrue);
    await disposeActiveService(tester, service);
  });

  testWidgets('SWK-09: wrong PIN cannot exit; correct PIN cancels then pops', (
    tester,
  ) async {
    installPlatformHandler();
    secureStorage.store[SecureStorageKeys.userPin] = '4826';
    final service = makeService(EmergencySessionKind.safeWalk);
    await arm(service);
    await pumpDestination(tester, SafeWalkScreen(controller: service));

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    await tester.tap(find.text('İptal Et ve Çık'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('PIN Doğrulaması'), findsOneWidget);

    await submitPin(tester, '1111');
    expect(find.byType(SafeWalkScreen), findsOneWidget);
    expect(service.isActive, isTrue);
    expect(find.text('Eski PIN yanlış'), findsOneWidget);

    await submitPin(tester, '4826');
    expect(find.text('TEST_OPEN'), findsOneWidget);
    expect(find.byType(SafeWalkScreen), findsNothing);
    expect(service.isActive, isFalse);
  });

  testWidgets('SWK-09 negative: too-late cancellation keeps screen and timer', (
    tester,
  ) async {
    installPlatformHandler(cancelSucceeds: false);
    secureStorage.store[SecureStorageKeys.userPin] = '4826';
    final service = makeService(EmergencySessionKind.safeWalk);
    await arm(service);
    await pumpDestination(tester, SafeWalkScreen(controller: service));

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    await tester.tap(find.text('İptal Et ve Çık'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await submitPin(tester, '4826');

    expect(find.byType(SafeWalkScreen), findsOneWidget);
    expect(service.isActive, isTrue);
    expect(
      find.text('İptal için çok geç; arama isteği gönderilmiş olabilir.'),
      findsOneWidget,
    );
    await disposeActiveService(tester, service);
  });

  testWidgets('SWK-07 negative control: inactive Back pops without warning', (
    tester,
  ) async {
    final service = makeService(EmergencySessionKind.safeWalk);
    await pumpDestination(tester, SafeWalkScreen(controller: service));

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('TEST_OPEN'), findsOneWidget);
    expect(find.text('Dikkat'), findsNothing);
  });
}
