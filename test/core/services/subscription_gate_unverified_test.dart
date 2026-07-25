import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/core/services/subscription_gate.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:provider/provider.dart';

/// Pins the access state so the gate can be exercised without RevenueCat.
class _FixedAccessProvider extends SubscriptionProvider {
  _FixedAccessProvider(this._state);

  final SubscriptionAccessState _state;

  @override
  Future<SubscriptionAccessState> resolveAccess() async => _state;
}

Future<bool?> _tapGuardedAction(
  WidgetTester tester,
  SubscriptionAccessState state,
) async {
  bool? allowed;
  await tester.pumpWidget(
    ChangeNotifierProvider<SubscriptionProvider>.value(
      value: _FixedAccessProvider(state),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                allowed = await SubscriptionGate.ensureAccess(
                  context,
                  PremiumFeature.panic,
                );
              },
              child: const Text('arm'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('arm'));
  await tester.pumpAndSettle();
  return allowed;
}

void main() {
  testWidgets('an unresolvable entitlement is refused VISIBLY, not silently', (
    tester,
  ) async {
    final allowed = await _tapGuardedAction(
      tester,
      const SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
        lastVerifiedPro: null,
      ),
    );

    expect(allowed, isFalse, reason: 'authorization must stay fail-closed');
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason:
          'A safety control that does nothing and says nothing is '
          'indistinguishable from a broken button.',
    );
  });

  testWidgets('a verified Pro entitlement passes without a message', (
    tester,
  ) async {
    final allowed = await _tapGuardedAction(
      tester,
      const SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedPro,
        lastVerifiedPro: true,
      ),
    );

    expect(allowed, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  test('verified-free stays a paywall case, not an error case', () {
    const state = SubscriptionAccessState(
      status: SubscriptionAccessStatus.verifiedFree,
      lastVerifiedPro: false,
    );

    expect(state.shouldShowPaywall, isTrue);
    expect(state.canUsePaidSafetyFeature, isFalse);
    expect(
      const SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
        lastVerifiedPro: null,
      ).shouldShowPaywall,
      isFalse,
      reason:
          'An unresolved entitlement must never be presented as a purchase '
          'decision; it is an error the user has to be told about.',
    );
  });
}
