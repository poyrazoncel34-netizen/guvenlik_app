// A-009, end to end through the REAL quick-access entry.
//
// The Quick Settings tile, the home-screen widget and the volume trigger all
// open the countdown through EmergencyTriggerHost._openCountdown, with no PIN
// gate in between. test/screens/countdown_contact_mask_test.dart pumps
// CountdownScreen(maskContactIdentity: true) directly, so it would stay green
// if the host stopped passing that flag -- it never exercised the path the
// finding is about. Here nothing is stubbed between the trigger and the
// screens: the production host builds the production CountdownScreen, the
// countdown really reaches zero, and the production EmergencyCallScreen is
// what gets read.
//
// Harness notes:
//   * pumpWidget runs inside tester.runAsync because the real tr-TR catalogue
//     is read from disk (file I/O deadlocks under FakeAsync).
//   * The countdown compares a real DateTime.now() against its deadline, so
//     reaching zero needs ten REAL seconds; FakeAsync alone cannot get there.
//   * Every platform channel the dispatch path awaits is answered by a mock:
//     an unanswered channel's reply rides the real event loop, which FakeAsync
//     does not drive, and the best-effort steps are awaited in sequence.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/core/utils/contact_name_mask.dart';
import 'package:guvenlik_app/core/widgets/emergency_trigger_host.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:guvenlik_app/screens/emergency_call_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Diacritic and two words: the surname alone must not leak either.
const String kContactName = 'Ayşe Yılmaz';
const String kContactPhone = '+905001234567';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _PinStorage extends SecureStorage {
  @override
  Future<String?> read({required String key}) async =>
      key == SecureStorageKeys.userPin ? '4826' : null;
  @override
  Future<void> write({required String key, required String value}) async {}
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<void> deleteAll() async {}
}

class _ContactsRepository implements ContactsRepository {
  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async =>
      const EmergencyContact(
        name: kContactName,
        phone: kContactPhone,
        isPrimary: true,
      );
  @override
  Future<List<String>> getAllEmergencyNumbers() async => const <String>[];
  @override
  Future<List<EmergencyContact>> getContactRecords() async =>
      const <EmergencyContact>[];
  @override
  Future<List<String>> getContacts() async => const <String>[];
  @override
  Future<void> clearPrimaryEmergencyContact() async {}
  @override
  Future<void> saveContactRecords(List<EmergencyContact> contacts) async {}
  @override
  Future<void> saveContacts(List<String> numbers) async {}
  @override
  Future<void> saveEmergencyNumbers(List<String> numbers) async {}
  @override
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {}
}

/// A subscriber whose Pro was verified an hour ago: authorized for panic.
class _AuthorizedSubscriptionProvider extends SubscriptionProvider {
  final SubscriptionAccessState _answer = SubscriptionAccessState(
    status: SubscriptionAccessStatus.unavailable,
    lastVerifiedPro: true,
    lastVerifiedProAt: DateTime.now().subtract(const Duration(hours: 1)),
  );

  @override
  SubscriptionAccessState get access => _answer;

  @override
  Future<void> ensureOfflineGraceLoaded() async {}

  @override
  Future<SubscriptionAccessState> resolveAccess() async => _answer;
}

/// Answers the native safety kernel the way a healthy device does: the arm is
/// accepted, and the dispatch reports a submitted call request.
Future<Object?> _nativeKernel(MethodCall call) async {
  final args = call.arguments is Map
      ? (call.arguments as Map<Object?, Object?>).cast<String, Object?>()
      : const <String, Object?>{};
  switch (call.method) {
    case 'armEmergencySession':
      return <String, Object?>{
        'type': 'armed',
        'token': <String, Object?>{
          'protocolVersion': args['protocolVersion'],
          'randomId': args['randomId'],
          'generation': args['requestedGeneration'],
          'kind': args['kind'],
        },
        'mainDeadlineMs': args['mainDeadlineMs'],
        'finalDeadlineMs': args['finalDeadlineMs'],
      };
    case 'dispatchEmergencySession':
      return <String, Object?>{
        'token': args['token'],
        'callRequestOutcome': 'submittedUnconfirmed',
        'fallbackOutcome': 'notAttempted',
        'terminalState': 'requestSubmittedUnconfirmed',
        'connectionState': 'unknown',
      };
    default:
      return null;
  }
}

/// Channels the dispatch path awaits but whose answer does not matter here.
/// `flutter/platform` (haptics, system chrome) uses the JSON codec, so it is
/// mocked through its own [SystemChannels.platform] instance.
final List<MethodChannel> _quietChannels = <MethodChannel>[
  const MethodChannel('com.poyrazoncel.korubeni/emergency_platform/events'),
  const MethodChannel('dexterous.com/flutter/local_notifications'),
  const MethodChannel('com.poyrazoncel.korubeni/android_intents'),
  SystemChannels.platform,
];

String renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_PinStorage());
    serviceLocator.registerSingleton<ContactsRepository>(_ContactsRepository());

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(EmergencyPlatformService.channelName),
      _nativeKernel,
    );
    for (final channel in _quietChannels) {
      messenger.setMockMethodCallHandler(
        channel,
        (MethodCall call) async => null,
      );
    }
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(EmergencyPlatformService.channelName),
      null,
    );
    for (final channel in _quietChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    await serviceLocator.reset();
  });

  Future<EmergencyTriggerHostState> pumpHost(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('tr', 'TR')],
          path: 'assets/translations',
          assetLoader: const _RealTrAssetLoader(),
          startLocale: const Locale('tr', 'TR'),
          fallbackLocale: const Locale('tr', 'TR'),
          child: ChangeNotifierProvider<SubscriptionProvider>.value(
            value: _AuthorizedSubscriptionProvider(),
            // No countdownBuilder: the production route is what is tested.
            child: EmergencyTriggerHost(
              child: Builder(
                builder: (context) => MaterialApp(
                  navigatorKey: rootNavigatorKey,
                  scaffoldMessengerKey: rootScaffoldMessengerKey,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  home: const Scaffold(body: Center(child: Text('HOME'))),
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('HOME'), findsOneWidget, reason: 'host tree not built');
    return tester.state<EmergencyTriggerHostState>(
      find.byType(EmergencyTriggerHost),
    );
  }

  /// Lets real-loop replies and fake timers take turns, since the dispatch
  /// path needs both, until [done] holds or the budget runs out.
  Future<void> interleave(
    WidgetTester tester, {
    required bool Function() done,
    int rounds = 60,
  }) async {
    for (var i = 0; i < rounds && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('the quick-access path never shows the contact name', (
    tester,
  ) async {
    final host = await pumpHost(tester);

    unawaited(host.triggerPanicForTest());
    await interleave(
      tester,
      done: () =>
          renderedText(tester).contains(ContactNameMask.mask(kContactName)),
    );

    // 1. The countdown opened by the host, with the production screen.
    expect(find.byType(CountdownScreen), findsOneWidget);
    final countdownText = renderedText(tester);
    expect(
      countdownText,
      isNot(contains(kContactName)),
      reason: 'the tile disclosed the full name without the PIN (A-009)',
    );
    expect(countdownText, isNot(contains('Yılmaz')));
    expect(
      countdownText,
      contains('A***'),
      reason: 'the user must still see that a contact IS configured',
    );

    // 2. Let the countdown really run out, then follow the hand-off.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10300)),
    );
    await interleave(
      tester,
      done: () => find.byType(EmergencyCallScreen).evaluate().isNotEmpty,
    );

    expect(
      find.byType(EmergencyCallScreen),
      findsOneWidget,
      reason: 'the countdown must hand off to the call screen',
    );
    final callScreen = tester.widget<EmergencyCallScreen>(
      find.byType(EmergencyCallScreen),
    );
    expect(
      callScreen.name,
      'A***',
      reason:
          'masking only the countdown label is cosmetic: the name came back '
          'ten seconds later on the call screen',
    );
    final callText = renderedText(tester);
    expect(callText, isNot(contains(kContactName)));
    expect(callText, isNot(contains('Yılmaz')));

    // Unmount so the call screen's fail-safe/auto-dismiss timers are cancelled
    // and the host's readiness probe timer is drained.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });
}
