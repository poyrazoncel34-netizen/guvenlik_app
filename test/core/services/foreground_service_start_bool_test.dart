import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SILENT-3: ForegroundService.start() must return bool so callers
/// know if background protection is active.
void main() {
  test('ForegroundService.start() should return Future<bool>', () {
    final source = File('lib/core/services/foreground_service.dart').readAsStringSync();

    expect(source.contains('static Future<bool> start()'), isTrue,
        reason: 'start() must return Future<bool> for failure feedback');
  });
}
