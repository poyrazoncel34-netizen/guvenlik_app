import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/navigation/deep_link_channel.dart';
import 'package:guvenlik_app/core/services/android_intent_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/native_contact_picker_service.dart';
import 'package:guvenlik_app/core/services/notification_service.dart';
import 'package:guvenlik_app/core/services/quick_panic_request_service.dart';
import 'package:guvenlik_app/core/services/volume_trigger_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const _ProbeHost());

  try {
    final deepLink = await DeepLinkChannel.consume();
    debugPrint('STAGE4_DEEP_LINK:${deepLink ?? 'none'}');
    final quickPanic = await QuickPanicRequestService.consume();
    debugPrint('STAGE4_QUICK_PANIC:${quickPanic?.name ?? 'none'}');

    final platform = EmergencyPlatformService.instance;
    final state = await platform.getDeviceState();
    debugPrint('STAGE4_DEVICE_STATE:$state');
    _require(state.isNotEmpty, 'device state was empty');
    _require(!platform.platformBridgeMissing, 'emergency bridge missing');

    final now = DateTime.now();
    final arm = await platform.armEmergencySession(
      kind: EmergencySessionKind.panic,
      mainDeadline: now.add(const Duration(minutes: 10)),
      finalDeadline: now.add(const Duration(minutes: 10)),
      target: '0000000',
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
      randomId: 'stage4-dart-kotlin-${now.millisecondsSinceEpoch}',
    );
    _require(
      arm is Armed,
      'native arm was ${arm.runtimeType}'
      '${arm is ArmRejected ? ':${arm.reasonCode}' : ''}'
      '${arm is ArmUnknown ? ':${arm.reasonCode}' : ''}',
    );
    final token = arm.token!;
    final snapshot = await platform.readEmergencySession(token);
    _require(snapshot.token == token, 'native read returned a different token');
    _require(
      snapshot.lifecycleState == EmergencySessionLifecycle.armed,
      'native read state was ${snapshot.lifecycleState.name}',
    );
    final cancel = await platform.cancelEmergencySession(token);
    _require(
      cancel.isConfirmedCancelled,
      'native cancel was ${cancel.runtimeType}',
    );

    const integrity = MethodChannel(
      'com.poyrazoncel.korubeni/device_integrity',
    );
    final integrityResult = await integrity.invokeMapMethod<Object?, Object?>(
      'probe',
    );
    _require(
      integrityResult != null && integrityResult.isNotEmpty,
      'integrity result was empty',
    );
    debugPrint('STAGE4_CHANNELS_PASS');

    final triggered = Completer<void>();
    final volume = VolumeTriggerService.instance;
    volume.bindCallback(
      onPanicTriggered: () {
        if (!triggered.isCompleted) triggered.complete();
      },
    );
    await volume.setEnabled(true);
    _require(
      volume.isEnabled && volume.isListening,
      'volume listener inactive',
    );
    debugPrint('STAGE4_WAIT_VOLUME');
    await triggered.future.timeout(const Duration(seconds: 30));
    await volume.setEnabled(false);
    debugPrint('STAGE4_VOLUME_PASS');

    _require(
      await AndroidIntentService.openDialer('0000000'),
      'dialer channel returned false',
    );
    debugPrint('STAGE4_DIALER_PASS');

    debugPrint('STAGE4_WAIT_CONTACT_PICKER');
    final pick = await NativeContactPickerService.pickPhoneContact().timeout(
      const Duration(seconds: 30),
    );
    _require(
      pick.status == ContactPickStatus.cancelled,
      'contact picker result was ${pick.status.name}',
    );
    debugPrint('STAGE4_CONTACT_PICKER_PASS');

    _require(
      await NotificationService.instance.scheduleFakeCall(
        delay: const Duration(seconds: 15),
      ),
      'delayed fake-call scheduling returned false',
    );
    debugPrint('STAGE4_FAKE_CALL_SCHEDULED');
    debugPrint('STAGE4_RUNTIME_PROBE_PASS');
  } catch (error, stack) {
    debugPrint('STAGE4_RUNTIME_PROBE_FAIL:${error.runtimeType}:$error');
    debugPrintStack(stackTrace: stack);
    rethrow;
  }
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

class _ProbeHost extends StatelessWidget {
  const _ProbeHost();

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: rootNavigatorKey,
    home: const Scaffold(body: Center(child: Text('Stage 4 runtime probe'))),
  );
}
