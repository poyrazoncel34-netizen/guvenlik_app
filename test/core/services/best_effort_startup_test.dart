import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/best_effort_startup.dart';

void main() {
  testWidgets('never completing optional plugin cannot block startup forever', (
    tester,
  ) async {
    final hung = Completer<void>();
    var completed = false;
    var healthyRan = false;
    unawaited(
      initializeBestEffortServices([
        () => hung.future,
        () async {
          healthyRan = true;
        },
      ], timeout: const Duration(seconds: 1)).then((_) => completed = true),
    );
    await tester.pump();
    expect(healthyRan, isTrue);
    expect(completed, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, isTrue);
    hung.completeError(StateError('synthetic late plugin error'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test(
    'sync and async plugin failures do not skip other initializers',
    () async {
      var healthyRuns = 0;
      await initializeBestEffortServices([
        () => throw StateError('synthetic sync error'),
        () async => throw StateError('synthetic async error'),
        () async {
          healthyRuns++;
        },
      ]);
      expect(healthyRuns, 1);
    },
  );
}
