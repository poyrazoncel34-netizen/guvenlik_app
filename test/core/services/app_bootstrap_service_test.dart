import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/app_bootstrap_service.dart';

void main() {
  test('critical bootstrap executes every step in declared order', () async {
    final order = <String>[];
    final service = AppBootstrapService(
      criticalSteps: <CriticalBootstrapStep>[
        CriticalBootstrapStep('di', () async => order.add('di')),
        CriticalBootstrapStep('migration', () async => order.add('migration')),
        CriticalBootstrapStep('pin', () async => order.add('pin')),
        CriticalBootstrapStep('contact', () async => order.add('contact')),
      ],
    );

    final result = await service.initializeCritical();

    expect(result.isReady, isTrue);
    expect(result.reasonCode, isNull);
    expect(order, <String>['di', 'migration', 'pin', 'contact']);
  });

  test(
    'critical bootstrap fails closed and does not run later steps',
    () async {
      final order = <String>[];
      final service = AppBootstrapService(
        criticalSteps: <CriticalBootstrapStep>[
          CriticalBootstrapStep('di', () async => order.add('di')),
          CriticalBootstrapStep('pin', () async {
            order.add('pin');
            throw StateError('CANARY_RAW_KEYSTORE_ERROR');
          }),
          CriticalBootstrapStep('contact', () async => order.add('contact')),
        ],
      );

      final result = await service.initializeCritical();

      expect(result.isReady, isFalse);
      expect(result.reasonCode, 'pinFailed');
      expect(result.reasonCode, isNot(contains('CANARY')));
      expect(order, <String>['di', 'pin']);
    },
  );

  test('hung critical bootstrap step becomes a bounded failure', () async {
    final never = Completer<void>();
    final service = AppBootstrapService(
      timeout: const Duration(milliseconds: 10),
      criticalSteps: <CriticalBootstrapStep>[
        CriticalBootstrapStep('pin', () => never.future),
      ],
    );

    final result = await service.initializeCritical();

    expect(result.isReady, isFalse);
    expect(result.reasonCode, 'pinTimeout');
  });
}
