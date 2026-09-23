import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/services/volume_trigger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'disabled callback binding becomes live immediately when Settings enables it',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final events = StreamController<Object?>.broadcast(sync: true);
      final nativeStates = <bool>[];
      final service = VolumeTriggerService.forTesting(
        eventStream: events.stream,
        nativeSetter: (enabled) async => nativeStates.add(enabled),
      );
      var panicCount = 0;

      service.bindCallback(onPanicTriggered: () => panicCount += 1);
      expect(service.isListening, isFalse);

      await service.setEnabled(true);
      events.add('volume_panic');

      expect(service.isEnabled, isTrue);
      expect(service.isListening, isTrue);
      expect(nativeStates, <bool>[true, true]);
      expect(panicCount, 1);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          AppConstants.prefVolumeTrigger,
        ),
        isTrue,
      );

      service.stopListening();
      events.add('volume_panic');
      expect(panicCount, 1);
      await events.close();
      service.dispose();
    },
  );

  test(
    'stored preference cannot activate native before entitlement approval',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.prefVolumeTrigger: true,
      });
      final events = StreamController<Object?>.broadcast(sync: true);
      final nativeStates = <bool>[];
      final service = VolumeTriggerService.forTesting(
        eventStream: events.stream,
        nativeSetter: (enabled) async => nativeStates.add(enabled),
      );

      service.bindCallback(onPanicTriggered: () {});
      await service.loadPreference();

      expect(service.isEnabled, isTrue);
      expect(service.isListening, isFalse);
      expect(nativeStates, isEmpty);

      service.startListening(onPanicTriggered: () {});
      expect(service.isListening, isTrue);
      expect(nativeStates, <bool>[true]);

      await events.close();
      service.dispose();
    },
  );
}
