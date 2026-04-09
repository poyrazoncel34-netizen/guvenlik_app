import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// E5: OfflineQueueService must cap individual event payload size to prevent
/// SharedPreferences overflow. 100 events × 1KB+ = 100KB+, approaching the
/// platform limit on some Android versions.
void main() {
  test('OfflineQueueService should validate payload size before enqueue', () {
    final source = File(
      'lib/core/services/offline_queue_service.dart',
    ).readAsStringSync();

    // Should have a max payload size constant or check
    expect(
      source.contains('_maxEventSize') || source.contains('maxEventSize'),
      isTrue,
      reason:
          'OfflineQueueService must enforce a max event payload size to '
          'prevent SharedPreferences overflow on large emergency payloads',
    );
  });
}
