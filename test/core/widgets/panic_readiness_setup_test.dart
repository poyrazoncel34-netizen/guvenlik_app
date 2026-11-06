// The panic setup asks for each missing capability once, in native refusal
// order, and reads the device again after every step (2026-11-02).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/app_lifecycle_handler.dart';
import 'package:guvenlik_app/core/services/arm_remedy.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_readiness_service.dart';
import 'package:guvenlik_app/core/services/panic_countdown_guard.dart';
import 'package:guvenlik_app/core/widgets/panic_readiness_setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

const channel = MethodChannel('korubeni-test/panic-setup');

/// The readiness key each step fixes on the fake device.
const Map<ArmRemedy, String> fixes = <ArmRemedy, String>{
  ArmRemedy.exactAlarm: 'canScheduleExactAlarms',
  ArmRemedy.callPermission: 'callPermissionGranted',
  ArmRemedy.notifications: 'notificationsEnabled',
  ArmRemedy.alertChannel: 'alertChannelHigh',
};

/// A keystore whose PIN read is held open, so the resume lock stays
/// undecided -- and up -- until [release]. No PIN is stored: it then comes
/// down without a lock screen.
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

  late Set<String> missing;
  late bool deviceAnswers;
  late List<ArmRemedy> asked;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    missing = <String>{};
    deviceAnswers = true;
    asked = <ArmRemedy>[];
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
          'callPermissionGranted',
          'notificationsEnabled',
          'alertChannelHigh',
        ])
          key: !missing.contains(key),
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

  /// A user who accepts every step and fixes what it names.
  Future<bool> fixingPrompt(BuildContext context, ArmRemedy step) async {
    asked.add(step);
    missing.remove(fixes[step]);
    return false;
  }

  /// A user who declines every step.
  Future<bool> decliningPrompt(BuildContext context, ArmRemedy step) async {
    asked.add(step);
    return false;
  }

  Future<bool> offered() async =>
      (await SharedPreferences.getInstance()).getBool(
        AppConstants.prefPanicReadinessSetupOffered,
      ) ??
      false;

  testWidgets('asks in native refusal order', (tester) async {
    missing = fixes.values.toSet();
    final context = await pumpHost(tester);

    await PanicReadinessSetup.run(
      context,
      readiness: readiness(),
      prompt: fixingPrompt,
    );

    expect(asked, ArmRemedy.capabilityOrder);
    expect(missing, isEmpty);
    expect(await offered(), isTrue);
  });

  testWidgets('a declined step is not asked again in the same run', (
    tester,
  ) async {
    missing = fixes.values.toSet();
    final context = await pumpHost(tester);

    await PanicReadinessSetup.run(
      context,
      readiness: readiness(),
      prompt: decliningPrompt,
    );

    expect(asked, ArmRemedy.capabilityOrder);
  });

  testWidgets('one trip that fixes two steps skips the second', (tester) async {
    missing = <String>{'canScheduleExactAlarms', 'notificationsEnabled'};
    final context = await pumpHost(tester);

    await PanicReadinessSetup.run(
      context,
      readiness: readiness(),
      prompt: (context, step) async {
        asked.add(step);
        missing.clear();
        return false;
      },
    );

    expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm]);
  });

  testWidgets('a ready device is asked nothing', (tester) async {
    final context = await pumpHost(tester);

    await PanicReadinessSetup.run(
      context,
      readiness: readiness(),
      prompt: decliningPrompt,
    );

    expect(asked, isEmpty);
    expect(await offered(), isTrue);
  });

  testWidgets('a device that does not answer is asked nothing, and the setup '
      'is offered again next time', (tester) async {
    deviceAnswers = false;
    missing = fixes.values.toSet();
    final context = await pumpHost(tester);

    await PanicReadinessSetup.run(
      context,
      readiness: readiness(),
      prompt: decliningPrompt,
    );

    expect(asked, isEmpty);
    expect(await offered(), isFalse);
  });

  testWidgets('a step that opened Settings waits for the user to come back', (
    tester,
  ) async {
    missing = <String>{'canScheduleExactAlarms', 'callPermissionGranted'};
    final context = await pumpHost(tester);
    var finished = false;

    PanicReadinessSetup.run(
      context,
      readiness: readiness(),
      prompt: (context, step) async {
        asked.add(step);
        return step == ArmRemedy.exactAlarm;
      },
    ).then((_) => finished = true);
    await tester.pump();
    expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 1));
    expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm], reason: 'user is away');

    missing.remove('canScheduleExactAlarms');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm, ArmRemedy.callPermission]);
    expect(finished, isTrue);
  });

  testWidgets('Settings that never opened does not stall the setup', (
    tester,
  ) async {
    missing = <String>{'canScheduleExactAlarms', 'callPermissionGranted'};
    final context = await pumpHost(tester);

    final done = PanicReadinessSetup.run(
      context,
      readiness: readiness(),
      prompt: (context, step) async {
        asked.add(step);
        return step == ArmRemedy.exactAlarm;
      },
    );
    await tester.pump(const Duration(seconds: 3));
    await done;

    expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm, ArmRemedy.callPermission]);
  });

  testWidgets('a device that stops answering mid-setup is offered it again '
      'next time', (tester) async {
    missing = <String>{'canScheduleExactAlarms', 'callPermissionGranted'};
    final context = await pumpHost(tester);

    await PanicReadinessSetup.run(
      context,
      readiness: readiness(),
      prompt: (context, step) async {
        asked.add(step);
        deviceAnswers = false; // the next probe goes unanswered
        return false;
      },
    );

    expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm]);
    expect(
      await offered(),
      isFalse,
      reason: 'the call permission was never asked',
    );
  });

  for (final failure in <Exception>[
    PlatformException(code: 'unavailable'),
    MissingPluginException(),
  ]) {
    testWidgets('a step failing with ${failure.runtimeType} is skipped; the '
        'rest are still asked', (tester) async {
      missing = <String>{'canScheduleExactAlarms', 'callPermissionGranted'};
      final context = await pumpHost(tester);

      await PanicReadinessSetup.run(
        context,
        readiness: readiness(),
        prompt: (context, step) async {
          asked.add(step);
          // A permission request already running, a Settings screen missing.
          if (step == ArmRemedy.exactAlarm) throw failure;
          return false;
        },
      );

      expect(asked, <ArmRemedy>[
        ArmRemedy.exactAlarm,
        ArmRemedy.callPermission,
      ]);
      expect(await offered(), isTrue);
    });
  }

  // Review 2026-11-06: the setup ran on its own schedule, so a prompt could
  // land ABOVE the resume PIN lock (audit A-07), or above a live panic
  // countdown and its PIN-cancel pad (A-06).
  group('never above the lock or a countdown', () {
    setUp(() {
      AppLifecycleHandler.instance.resetForTest();
      PanicCountdownGuard.resetForTesting();
    });

    tearDown(() async {
      AppLifecycleHandler.instance.resetForTest();
      PanicCountdownGuard.resetForTesting();
      await serviceLocator.reset();
    });

    testWidgets('nothing is asked while the resume lock is up; the step '
        'follows once it is down', (tester) async {
      missing = <String>{'canScheduleExactAlarms'};
      final keystore = _HeldPinRead();
      serviceLocator.registerSingleton<SecureStorage>(keystore);
      final context = await pumpHost(tester);

      // Back after longer than the lock threshold: the lock is decided now.
      AppLifecycleHandler.instance.pausedAtForTest = DateTime.now().subtract(
        const Duration(seconds: AppLifecycleHandler.lockAfterSeconds + 5),
      );
      unawaited(AppLifecycleHandler.instance.onResumed());
      expect(AppLifecycleHandler.instance.lockActive.value, isTrue);

      var finished = false;
      unawaited(
        PanicReadinessSetup.run(
          context,
          readiness: readiness(),
          prompt: decliningPrompt,
        ).then((_) => finished = true),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(asked, isEmpty, reason: 'a prompt now lands above the PIN lock');

      keystore.release();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(AppLifecycleHandler.instance.lockActive.value, isFalse);
      expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm]);
      expect(finished, isTrue);
    });

    testWidgets('back from a long Settings visit, the next step waits for '
        'the PIN lock', (tester) async {
      missing = <String>{'canScheduleExactAlarms', 'callPermissionGranted'};
      final keystore = _HeldPinRead();
      serviceLocator.registerSingleton<SecureStorage>(keystore);
      final context = await pumpHost(tester);
      unawaited(
        PanicReadinessSetup.run(
          context,
          readiness: readiness(),
          prompt: (context, step) async {
            asked.add(step);
            return step == ArmRemedy.exactAlarm; // only that one opened Settings
          },
        ),
      );
      await tester.pump();
      expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // Away for longer than the lock threshold...
      AppLifecycleHandler.instance.pausedAtForTest = DateTime.now().subtract(
        const Duration(seconds: AppLifecycleHandler.lockAfterSeconds + 5),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ...and back: EmergencyTriggerHost decides the lock as the app resumes.
      unawaited(AppLifecycleHandler.instance.onResumed());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        asked,
        <ArmRemedy>[ArmRemedy.exactAlarm],
        reason: 'the call-permission prompt would land above the PIN lock',
      );

      keystore.release();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(asked, <ArmRemedy>[
        ArmRemedy.exactAlarm,
        ArmRemedy.callPermission,
      ]);
    });

    testWidgets('a live panic countdown ends the setup: nothing covers its '
        'PIN-cancel pad', (tester) async {
      missing = <String>{'canScheduleExactAlarms'};
      final context = await pumpHost(tester);
      expect(PanicCountdownGuard.tryAcquire(Object()), isTrue);

      await PanicReadinessSetup.run(
        context,
        readiness: readiness(),
        prompt: decliningPrompt,
      );

      expect(asked, isEmpty);
      expect(await offered(), isFalse, reason: 'asked again next start');
    });

    testWidgets('a countdown opened while the user was in Settings ends the '
        'setup', (tester) async {
      missing = <String>{'canScheduleExactAlarms', 'callPermissionGranted'};
      final context = await pumpHost(tester);
      var finished = false;
      unawaited(
        PanicReadinessSetup.run(
          context,
          readiness: readiness(),
          prompt: (context, step) async {
            asked.add(step);
            return true; // opened Settings
          },
        ).then((_) => finished = true),
      );
      await tester.pump();
      expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // The Quick Settings panic tile, pressed from the notification shade.
      expect(PanicCountdownGuard.tryAcquire(Object()), isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm]);
      expect(finished, isTrue);
    });
  });

  group('offerOnce', () {
    testWidgets('runs for an install allowed to panic, then never again', (
      tester,
    ) async {
      missing = <String>{'canScheduleExactAlarms'};
      final context = await pumpHost(tester);

      await PanicReadinessSetup.offerOnce(
        context,
        emergencyAuthorized: true,
        readiness: readiness(),
        prompt: decliningPrompt,
      );
      await PanicReadinessSetup.offerOnce(
        context,
        emergencyAuthorized: true,
        readiness: readiness(),
        prompt: decliningPrompt,
      );

      expect(asked, <ArmRemedy>[ArmRemedy.exactAlarm]);
    });

    testWidgets('does nothing for an install not allowed to panic', (
      tester,
    ) async {
      missing = <String>{'canScheduleExactAlarms'};
      final context = await pumpHost(tester);

      await PanicReadinessSetup.offerOnce(
        context,
        emergencyAuthorized: false,
        readiness: readiness(),
        prompt: decliningPrompt,
      );

      expect(asked, isEmpty);
      expect(await offered(), isFalse);
    });
  });
}
