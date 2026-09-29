import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/widgets/app_privacy_shield.dart';

/// D2 regression: the privacy mask must engage at inactive, before Flutter
/// disables frame production for hidden/paused. Waiting for those later states
/// leaks the last foreground frame into Android's recents thumbnail.
void main() {
  group('privacyShieldShouldMask', () {
    test('masks on inactive, paused and hidden', () {
      expect(privacyShieldShouldMask(AppLifecycleState.inactive), isTrue);
      expect(privacyShieldShouldMask(AppLifecycleState.paused), isTrue);
      expect(privacyShieldShouldMask(AppLifecycleState.hidden), isTrue);
    });

    test('does NOT mask on resumed or detached', () {
      expect(privacyShieldShouldMask(AppLifecycleState.resumed), isFalse);
      expect(privacyShieldShouldMask(AppLifecycleState.detached), isFalse);
    });
  });

  testWidgets('mask overlay starts hidden while resumed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppPrivacyShield(child: Text('content'))),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0.0,
    );
  });

  testWidgets('inactive masks immediately before paused disables frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppPrivacyShield(child: Text('sensitive'))),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    var opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1.0);
    expect(opacity.duration, Duration.zero);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1.0);
    expect(opacity.duration, Duration.zero);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1.0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 0.0);
  });
}
