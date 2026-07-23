import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/widgets/app_privacy_shield.dart';

/// D2 regression: the privacy mask must engage ONLY for true backgrounding
/// (paused/hidden — the recents/app-switcher thumbnail), and stay OFF for
/// transient still-visible states (inactive/detached) so screenshots and system
/// dialogs are not blacked out.
void main() {
  group('privacyShieldShouldMask', () {
    test('masks on paused and hidden (true backgrounding)', () {
      expect(privacyShieldShouldMask(AppLifecycleState.paused), isTrue);
      expect(privacyShieldShouldMask(AppLifecycleState.hidden), isTrue);
    });

    test('does NOT mask on inactive (screenshots/dialogs stay visible)', () {
      expect(privacyShieldShouldMask(AppLifecycleState.inactive), isFalse);
    });

    test('does NOT mask on resumed or detached', () {
      expect(privacyShieldShouldMask(AppLifecycleState.resumed), isFalse);
      expect(privacyShieldShouldMask(AppLifecycleState.detached), isFalse);
    });
  });

  testWidgets('mask overlay starts hidden while resumed', (tester) async {
    final controller = AppPrivacyBarrierController.forTesting();
    await tester.pumpWidget(
      MaterialApp(
        home: AppPrivacyShield(
          controller: controller,
          child: const Text('content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0.0,
    );
  });

  testWidgets(
    'resume keeps the background mask until reauthentication decision',
    (tester) async {
      final controller = AppPrivacyBarrierController.forTesting();
      await tester.pumpWidget(
        MaterialApp(
          home: AppPrivacyShield(
            controller: controller,
            child: const Text('sensitive'),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1.0,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1.0,
        reason:
            'PIN-route scheduling must happen before sensitive pixels return.',
      );

      controller.reveal();
      await tester.pump();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.0,
      );
    },
  );
}
