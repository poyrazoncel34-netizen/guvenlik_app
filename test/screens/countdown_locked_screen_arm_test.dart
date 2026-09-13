// Panic pressed, phone locked before the countdown finished loading.
//
// The countdown waits for a frame before it arms the native session. Frames
// are disabled while the app is hidden/paused, and that wait used to be
// unbounded: with the screen off, the native session was never armed -- no
// alarm, no call -- until the user turned the screen back on. A probe saw no
// arm after 60 seconds. The wait is now bounded by BoundedFrameWait.maxWait.
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/bounded_frame_wait.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyAssetLoader extends AssetLoader {
  const _EmptyAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      <String, dynamic>{};
}

/// PIN store whose read stays pending until the test releases it, so the
/// screen can be locked while the countdown is still loading.
class _GatedPinStorage extends SecureStorage {
  final Completer<void> gate = Completer<void>();
  bool readReturned = false;

  @override
  Future<String?> read({required String key}) async {
    await gate.future;
    readReturned = true;
    return key == SecureStorageKeys.userPin ? '4826' : null;
  }

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
        name: 'Primary',
        phone: '+905001234567',
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

void _goTo(WidgetTester tester, List<AppLifecycleState> states) {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    await serviceLocator.reset();
    serviceLocator.registerSingleton<ContactsRepository>(_ContactsRepository());
  });

  tearDown(() async => serviceLocator.reset());

  testWidgets('locking the phone during load still arms the native session', (
    tester,
  ) async {
    const channel = MethodChannel('countdown-locked-screen-arm-test');
    final methods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      methods.add(call.method);
      final arguments = (call.arguments as Map<Object?, Object?>)
          .cast<String, Object?>();
      if (call.method == 'armEmergencySession') {
        return <String, Object?>{
          'type': 'armed',
          'token': <String, Object?>{
            'protocolVersion': arguments['protocolVersion'],
            'randomId': arguments['randomId'],
            'generation': arguments['requestedGeneration'],
            'kind': arguments['kind'],
          },
          'mainDeadlineMs': arguments['mainDeadlineMs'],
          'finalDeadlineMs': arguments['finalDeadlineMs'],
        };
      }
      throw PlatformException(code: 'unexpected', message: call.method);
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    _goTo(tester, <AppLifecycleState>[AppLifecycleState.resumed]);
    final pinStorage = _GatedPinStorage();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const <Locale>[Locale('tr', 'TR')],
        path: 'unused',
        assetLoader: const _EmptyAssetLoader(),
        fallbackLocale: const Locale('tr', 'TR'),
        startLocale: const Locale('tr', 'TR'),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: CountdownScreen(
              entitlementDecision: EntitlementDecision.authorized,
              pinVerificationService: PinVerificationService.forTesting(
                secureStorage: pinStorage,
                operationTimeout: const Duration(minutes: 5),
              ),
              emergencyPlatformService: EmergencyPlatformService.forTesting(
                methodChannel: channel,
                defaultTimeout: const Duration(seconds: 1),
              ),
            ),
          ),
        ),
      ),
    );
    for (
      var i = 0;
      i < 20 && find.byType(CountdownScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(CountdownScreen), findsOneWidget);
    expect(pinStorage.readReturned, isFalse, reason: 'still loading');
    expect(methods, isEmpty);

    // The user locks the phone; then the PIN read finishes. From here on no
    // frame is pumped -- exactly what a locked device delivers.
    _goTo(tester, <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    expect(tester.binding.framesEnabled, isFalse);
    pinStorage.gate.complete();

    await tester.binding.delayed(
      BoundedFrameWait.maxWait + const Duration(milliseconds: 100),
    );

    expect(pinStorage.readReturned, isTrue);
    expect(
      methods,
      contains('armEmergencySession'),
      reason:
          'with no frame delivered, the native session must still arm within '
          'the bound -- otherwise nothing is scheduled until the screen is on',
    );

    _goTo(tester, <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
