import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retired generic service has no heartbeat isolate or partial wakelock',
    () {
      final source = File(
        'lib/core/services/foreground_service.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('Timer.periodic')));
      expect(source, isNot(contains('FlutterBackgroundService')));
      expect(source, isNot(contains('DartPluginRegistrant')));
      expect(source, isNot(contains('WakelockPlus')));
    },
  );
}
