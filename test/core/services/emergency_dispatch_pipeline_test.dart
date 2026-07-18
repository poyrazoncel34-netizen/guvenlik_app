import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_dispatch_pipeline.dart';

void main() {
  test('critical dispatch precedes every non-critical side effect', () async {
    final order = <String>[];
    final pipeline = EmergencyDispatchPipeline(
      onBestEffortError: (error, stackTrace) {
        order.add('caught:$error');
      },
    );

    final result = await pipeline.execute<String>(
      criticalOperation: () async {
        order.add('dispatch');
        return 'submitted-unconfirmed';
      },
      shouldRunBestEffort: (_) => true,
      bestEffortOperations: <FutureOr<void> Function()>[
        () {
          order.add('queue');
          throw StateError('queue failed');
        },
        () async {
          order.add('log');
          throw StateError('db full');
        },
        () async {
          order.add('haptic');
          throw StateError('haptic failed');
        },
        () async {
          order.add('notification');
          throw StateError('notification failed');
        },
      ],
    );

    expect(result, 'submitted-unconfirmed');
    expect(order.first, 'dispatch');
    expect(order.where((entry) => entry == 'dispatch'), hasLength(1));
    expect(
      order,
      containsAllInOrder(<String>['queue', 'log', 'haptic', 'notification']),
    );
    expect(order.where((entry) => entry.startsWith('caught:')), hasLength(4));
  });

  test('cancelled critical result suppresses post-dispatch effects', () async {
    var effects = 0;
    final result = await const EmergencyDispatchPipeline().execute<String>(
      criticalOperation: () async => 'cancelled',
      shouldRunBestEffort: (value) => value != 'cancelled',
      bestEffortOperations: <FutureOr<void> Function()>[() => effects += 1],
    );

    expect(result, 'cancelled');
    expect(effects, 0);
  });
}
