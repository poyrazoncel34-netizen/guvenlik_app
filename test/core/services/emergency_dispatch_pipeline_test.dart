import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/core/services/emergency_dispatch_pipeline.dart';

/// Builds one step that succeeds, one that fails, or one that reports an
/// explicit outcome, and appends its name to [order] when it runs.
BestEffortStep _step(
  List<String> order,
  DispatchTarget target, {
  Object? throws,
  DispatchTargetOutcome? reports,
}) => BestEffortStep(
  target: target,
  run: () async {
    order.add(target.name);
    if (throws != null) throw throws;
    return reports;
  },
);

void main() {
  group('ordering contract', () {
    test('critical dispatch precedes every non-critical side effect', () async {
      final order = <String>[];
      final pipeline = EmergencyDispatchPipeline(
        onBestEffortError: (error, stackTrace) => order.add('caught:$error'),
      );

      final execution = await pipeline.execute<String>(
        dispatchId: 'd1',
        criticalOperation: () async {
          order.add('dispatch');
          return 'submitted-unconfirmed';
        },
        shouldRunBestEffort: (_) => true,
        bestEffortOperations: <BestEffortStep>[
          _step(order, DispatchTarget.offlineQueue,
              throws: StateError('queue failed')),
          _step(order, DispatchTarget.safetyTimeline,
              throws: StateError('db full')),
          _step(order, DispatchTarget.haptic,
              throws: StateError('haptic failed')),
          _step(order, DispatchTarget.alertNotification,
              throws: StateError('notification failed')),
        ],
      );

      expect(execution.result, 'submitted-unconfirmed');
      expect(order.first, 'dispatch');
      expect(order.where((entry) => entry == 'dispatch'), hasLength(1));
      expect(
        order,
        containsAllInOrder(<String>[
          'offlineQueue',
          'safetyTimeline',
          'haptic',
          'alertNotification',
        ]),
      );
      expect(order.where((entry) => entry.startsWith('caught:')), hasLength(4));
    });

    test('cancelled critical result suppresses post-dispatch effects', () async {
      var effects = 0;
      final execution = await const EmergencyDispatchPipeline().execute<String>(
        dispatchId: 'd2',
        criticalOperation: () async => 'cancelled',
        shouldRunBestEffort: (value) => value != 'cancelled',
        bestEffortOperations: <BestEffortStep>[
          BestEffortStep.effect(
            target: DispatchTarget.haptic,
            run: () async => effects += 1,
          ),
        ],
      );

      expect(execution.result, 'cancelled');
      expect(effects, 0);
      // The suppressed target is RECORDED as cancelled, not omitted: an absent
      // row and a failed row must never look the same.
      expect(execution.ledger.results.single.outcome,
          DispatchTargetOutcome.cancelled);
      expect(execution.ledger.attemptedCount, 0);
      expect(execution.ledger.summary,
          DispatchOutcomeSummary.nothingAttempted);
    });
  });

  group('per-target outcome matrix (MP-01-027)', () {
    Future<DispatchOutcomeLedger> run(List<BestEffortStep> steps) async {
      final execution = await const EmergencyDispatchPipeline().execute<bool>(
        dispatchId: 'matrix',
        criticalOperation: () async => true,
        shouldRunBestEffort: (_) => true,
        bestEffortOperations: steps,
      );
      return execution.ledger;
    }

    test('all targets succeed', () async {
      final order = <String>[];
      final ledger = await run(<BestEffortStep>[
        _step(order, DispatchTarget.offlineQueue),
        _step(order, DispatchTarget.safetyTimeline),
        _step(order, DispatchTarget.alertNotification),
      ]);
      expect(ledger.reachedCount, 3);
      expect(ledger.notReachedCount, 0);
      expect(ledger.isPartial, isFalse);
      expect(ledger.summary, DispatchOutcomeSummary.everyTargetReached);
    });

    test('FIRST target fails and stays distinguishable', () async {
      final order = <String>[];
      final ledger = await run(<BestEffortStep>[
        _step(order, DispatchTarget.offlineQueue, throws: Exception('x')),
        _step(order, DispatchTarget.safetyTimeline),
        _step(order, DispatchTarget.alertNotification),
      ]);
      expect(ledger.isPartial, isTrue);
      expect(ledger.results.first.reachability, DispatchReachability.notReached);
      expect(ledger.results[1].reachability, DispatchReachability.reached);
      expect(ledger.results[2].reachability, DispatchReachability.reached);
    });

    test('MIDDLE target fails: [SUCCESS, FAILURE, SUCCESS] never aggregates',
        () async {
      final order = <String>[];
      final ledger = await run(<BestEffortStep>[
        _step(order, DispatchTarget.offlineQueue),
        _step(order, DispatchTarget.safetyTimeline, throws: Exception('db')),
        _step(order, DispatchTarget.alertNotification),
      ]);

      // The defect this row exists for: two successes around one failure must
      // not read as success. Assert the SHAPE, not just a boolean.
      expect(
        ledger.results.map((r) => r.reachability).toList(),
        <DispatchReachability>[
          DispatchReachability.reached,
          DispatchReachability.notReached,
          DispatchReachability.reached,
        ],
      );
      expect(ledger.isPartial, isTrue);
      expect(ledger.summary, DispatchOutcomeSummary.mixed);
      expect(ledger.summary, isNot(DispatchOutcomeSummary.everyTargetReached));
    });

    test('LAST target fails', () async {
      final order = <String>[];
      final ledger = await run(<BestEffortStep>[
        _step(order, DispatchTarget.offlineQueue),
        _step(order, DispatchTarget.safetyTimeline),
        _step(order, DispatchTarget.alertNotification, throws: Exception('n')),
      ]);
      expect(ledger.isPartial, isTrue);
      expect(ledger.results.last.reachability, DispatchReachability.notReached);
    });

    test('ALL targets fail', () async {
      final order = <String>[];
      final ledger = await run(<BestEffortStep>[
        _step(order, DispatchTarget.offlineQueue, throws: Exception('a')),
        _step(order, DispatchTarget.safetyTimeline, throws: Exception('b')),
        _step(order, DispatchTarget.alertNotification, throws: Exception('c')),
      ]);
      expect(ledger.reachedCount, 0);
      expect(ledger.notReachedCount, 3);
      // Not "partial": partial means SOMETHING got through.
      expect(ledger.isPartial, isFalse);
      expect(ledger.summary, DispatchOutcomeSummary.noTargetReached);
    });

    test('platform exception is classified, not flattened', () async {
      final order = <String>[];
      final ledger = await run(<BestEffortStep>[
        _step(order, DispatchTarget.alertNotification,
            throws: PlatformException(code: 'permission_denied')),
        _step(order, DispatchTarget.safetyTimeline,
            throws: PlatformException(code: 'ACTIVITY_NOT_FOUND')),
        _step(order, DispatchTarget.offlineQueue,
            throws: PlatformException(code: 'io_error')),
        _step(order, DispatchTarget.haptic,
            throws: MissingPluginException('vibration')),
        _step(order, DispatchTarget.dialerHandoff,
            throws: StateError('bug in bookkeeping')),
      ]);
      expect(
        ledger.results.map((r) => r.outcome).toList(),
        <DispatchTargetOutcome>[
          DispatchTargetOutcome.permissionDenied,
          DispatchTargetOutcome.noCompatibleHandler,
          DispatchTargetOutcome.platformRejected,
          DispatchTargetOutcome.noCompatibleHandler,
          DispatchTargetOutcome.platformException,
        ],
      );
      expect(
        ledger.results.map((r) => r.reasonCode).toList(),
        <String>[
          'permission_denied',
          'ACTIVITY_NOT_FOUND',
          'io_error',
          'missingPlugin',
          'StateError',
        ],
      );
    });

    test('a step may report an outcome that is neither success nor failure',
        () async {
      final order = <String>[];
      final ledger = await run(<BestEffortStep>[
        _step(order, DispatchTarget.primaryCall,
            reports: DispatchTargetOutcome.handoffUnconfirmed),
        _step(order, DispatchTarget.alertNotification,
            reports: DispatchTargetOutcome.suppressedByUserSetting),
      ]);
      expect(ledger.unknownCount, 1);
      expect(ledger.notReachedCount, 1);
      expect(ledger.reachedCount, 0);
      expect(ledger.hasUnconfirmedTarget, isTrue);
      // Unknown is never laundered into either side.
      expect(ledger.summary, DispatchOutcomeSummary.mixed);
      expect(ledger.isPartial, isFalse);
    });

    test('a duplicated target keeps BOTH attempts', () async {
      final order = <String>[];
      final ledger = await run(<BestEffortStep>[
        _step(order, DispatchTarget.alertNotification),
        _step(order, DispatchTarget.alertNotification, throws: Exception('2')),
      ]);
      expect(ledger.results, hasLength(2));
      expect(ledger.duplicateTargets, <DispatchTarget>[
        DispatchTarget.alertNotification,
      ]);
      expect(ledger.isPartial, isTrue);
    });

    test('concurrent dispatches keep separate ledgers', () async {
      final orderA = <String>[];
      final orderB = <String>[];
      const pipeline = EmergencyDispatchPipeline();

      final futures = <Future<DispatchExecution<String>>>[
        pipeline.execute<String>(
          dispatchId: 'A',
          criticalOperation: () async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return 'A';
          },
          shouldRunBestEffort: (_) => true,
          bestEffortOperations: <BestEffortStep>[
            _step(orderA, DispatchTarget.safetyTimeline),
            _step(orderA, DispatchTarget.haptic, throws: Exception('A-fail')),
          ],
        ),
        pipeline.execute<String>(
          dispatchId: 'B',
          criticalOperation: () async => 'B',
          shouldRunBestEffort: (_) => true,
          bestEffortOperations: <BestEffortStep>[
            _step(orderB, DispatchTarget.safetyTimeline),
            _step(orderB, DispatchTarget.haptic),
          ],
        ),
      ];

      final results = await Future.wait(futures);
      expect(results[0].ledger.dispatchId, 'A');
      expect(results[1].ledger.dispatchId, 'B');
      expect(results[0].ledger.results, hasLength(2));
      expect(results[1].ledger.results, hasLength(2));
      expect(results[0].ledger.isPartial, isTrue);
      expect(results[1].ledger.summary,
          DispatchOutcomeSummary.everyTargetReached);
    });
  });

  group('vocabulary invariants', () {
    test('no outcome claims delivery, ringing or answering', () {
      const forbidden = <String>[
        'delivered',
        'ringing',
        'answered',
        'completed',
        'connected',
      ];
      for (final outcome in DispatchTargetOutcome.values) {
        for (final word in forbidden) {
          expect(
            outcome.name.toLowerCase().contains(word),
            isFalse,
            reason:
                '${outcome.name} claims more than an intent handoff can prove',
          );
        }
      }
    });

    test('every outcome has a reachability and a distinct message key', () {
      final keys = <String>{};
      for (final outcome in DispatchTargetOutcome.values) {
        expect(outcome.reachability, isNotNull);
        expect(keys.add(outcome.messageKey), isTrue,
            reason: '${outcome.name} reuses another outcome message key');
      }
      final labels = <String>{};
      for (final target in DispatchTarget.values) {
        expect(labels.add(target.labelKey), isTrue,
            reason: '${target.name} reuses another target label key');
      }
    });

    test('the ledger projection carries every entry', () {
      final ledger = DispatchOutcomeLedger(dispatchId: 'p')
        ..recordOutcome(
            DispatchTarget.primaryCall, DispatchTargetOutcome.handoffAccepted)
        ..recordOutcome(DispatchTarget.alertNotification,
            DispatchTargetOutcome.permissionDenied,
            reasonCode: 'POST_NOTIFICATIONS');
      final map = ledger.toMap();
      expect(map['isPartial'], isTrue);
      expect(map['reached'], 1);
      expect(map['notReached'], 1);
      expect((map['results']! as List<Object?>), hasLength(2));
      expect(
        (map['results']! as List<Object?>)[1],
        containsPair('reasonCode', 'POST_NOTIFICATIONS'),
      );
    });
  });
}
