// An install that granted CALL_PHONE before READ_PHONE_STATE existed in the
// manifest is never asked for it by the arm-refusal flow (CALL_PHONE is not
// missing), so dual-SIM "ask every time" keeps parking its emergency call in
// the SIM picker. SimSelectionOffer asks such an install once.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/app_lifecycle_handler.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_readiness_service.dart';
import 'package:guvenlik_app/core/services/panic_countdown_guard.dart';
import 'package:guvenlik_app/core/widgets/sim_selection_offer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const channel = MethodChannel('korubeni-test/sim-selection');

/// A keystore whose PIN read is held open, so the resume lock stays up.
class _HeldPinRead extends SecureStorage {
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<String?> read({required String key}) async {
    await _gate.future;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool callPermissionGranted;
  late bool deviceAnswers;
  late PermissionStatus phoneGroup;
  late int prompts;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    callPermissionGranted = true;
    deviceAnswers = true;
    phoneGroup = PermissionStatus.denied;
    prompts = 0;
    AppLifecycleHandler.instance.resetForTest();
    PanicCountdownGuard.resetForTesting();
  });

  tearDown(() async {
    AppLifecycleHandler.instance.resetForTest();
    PanicCountdownGuard.resetForTesting();
    await serviceLocator.reset();
  });

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method != 'getDeviceState' || !deviceAnswers) return null;
      return <String, Object?>{
        for (final key in const <String>[
          'supportedOs',
          'telephonyCalling',
          'telecomAvailable',
          'dialHandlerAvailable',
          'batteryOptimizationsIgnored',
          'canScheduleExactAlarms',
          'notificationsEnabled',
          'alertChannelHigh',
        ])
          key: true,
        'callPermissionGranted': callPermissionGranted,
      };
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  EmergencyReadinessService readiness() => EmergencyReadinessService.forTesting(
    platformService: EmergencyPlatformService.forTesting(
      methodChannel: channel,
    ),
  );

  Future<void> offer(BuildContext context, {bool authorized = true}) =>
      SimSelectionOffer.offerOnce(
        context,
        emergencyAuthorized: authorized,
        readiness: readiness(),
        phoneStatus: () async => phoneGroup,
        prompt: (_) async => prompts++,
      );

  Future<bool> offered() async =>
      (await SharedPreferences.getInstance()).getBool(
        AppConstants.prefSimSelectionOffered,
      ) ??
      false;

  testWidgets('an upgraded install with CALL_PHONE but not the full phone '
      'group is asked once', (tester) async {
    final context = await pumpHost(tester);

    await offer(context);
    await offer(context);

    expect(prompts, 1);
    expect(await offered(), isTrue);
  });

  testWidgets('a granted phone group is asked nothing', (tester) async {
    phoneGroup = PermissionStatus.granted;
    final context = await pumpHost(tester);

    await offer(context);

    expect(prompts, 0);
    expect(await offered(), isTrue);
  });

  testWidgets('a permanently denied phone group is not nagged', (tester) async {
    phoneGroup = PermissionStatus.permanentlyDenied;
    final context = await pumpHost(tester);

    await offer(context);

    expect(prompts, 0);
    expect(await offered(), isTrue);
  });

  testWidgets('an install without the emergency entitlement is not asked', (
    tester,
  ) async {
    final context = await pumpHost(tester);

    await offer(context, authorized: false);

    expect(prompts, 0);
    expect(await offered(), isFalse);
  });

  testWidgets('without CALL_PHONE the call-permission flow asks the whole '
      'group instead', (tester) async {
    callPermissionGranted = false;
    final context = await pumpHost(tester);

    await offer(context);

    expect(prompts, 0);
    expect(await offered(), isFalse);
  });

  testWidgets('a device that does not answer is not asked and stays '
      'eligible', (tester) async {
    deviceAnswers = false;
    final context = await pumpHost(tester);

    await offer(context);

    expect(prompts, 0);
    expect(await offered(), isFalse);
  });

  testWidgets('nothing is asked above a live panic countdown', (tester) async {
    final context = await pumpHost(tester);
    expect(PanicCountdownGuard.tryAcquire(Object()), isTrue);

    await offer(context);

    expect(prompts, 0);
    expect(await offered(), isFalse);
  });

  // Same contract as PanicReadinessSetup: a raised lock defers the offer
  // instead of dropping it for this start.
  testWidgets('nothing is asked above the resume PIN lock; the offer '
      'follows once it is down', (tester) async {
    final keystore = _HeldPinRead();
    serviceLocator.registerSingleton<SecureStorage>(keystore);
    final context = await pumpHost(tester);
    AppLifecycleHandler.instance.pausedAtForTest = DateTime.now().subtract(
      const Duration(seconds: AppLifecycleHandler.lockAfterSeconds + 5),
    );
    unawaited(AppLifecycleHandler.instance.onResumed());
    expect(AppLifecycleHandler.instance.lockActive.value, isTrue);

    var finished = false;
    unawaited(offer(context).then((_) => finished = true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(prompts, 0, reason: 'a prompt now lands above the PIN lock');

    keystore.release();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(AppLifecycleHandler.instance.lockActive.value, isFalse);
    expect(prompts, 1);
    expect(finished, isTrue);
    expect(await offered(), isTrue);
  });

  testWidgets('a failing prompt does not escape', (tester) async {
    final context = await pumpHost(tester);

    await SimSelectionOffer.offerOnce(
      context,
      emergencyAuthorized: true,
      readiness: readiness(),
      phoneStatus: () async => phoneGroup,
      prompt: (_) async => throw PlatformException(code: 'busy'),
    );

    expect(await offered(), isTrue);
  });
}
