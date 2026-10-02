// The overlay guard's two policies are not interchangeable, and the lease model
// is what lets a dialog open over a guarded screen without either of them
// losing its protection.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/overlay_touch_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> sent;
  late OverlayTouchGuard guard;

  setUp(() {
    sent = <MethodCall>[];
    const channel = MethodChannel(OverlayTouchGuard.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          sent.add(call);
          return true;
        });
    guard = OverlayTouchGuard(channel: channel, isAndroid: true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(OverlayTouchGuard.channelName),
          null,
        );
  });

  String lastPolicy() =>
      (sent.last.arguments as Map)['policy'] as String;

  group('policy strength', () {
    test('block outranks warn, warn outranks off', () {
      expect(
        OverlayTouchPolicy.block.strength,
        greaterThan(OverlayTouchPolicy.warn.strength),
      );
      expect(
        OverlayTouchPolicy.warn.strength,
        greaterThan(OverlayTouchPolicy.off.strength),
      );
    });
  });

  group('leases', () {
    test('a single owner pushes its own policy', () async {
      await guard.acquire('export', OverlayTouchPolicy.block);

      expect(sent.single.method, 'setPolicy');
      expect(lastPolicy(), 'block');
    });

    test('the strongest live lease wins while surfaces are stacked', () async {
      await guard.acquire('consent', OverlayTouchPolicy.warn);
      await guard.acquire('reset', OverlayTouchPolicy.block);

      expect(guard.effectivePolicy, OverlayTouchPolicy.block);
      expect(lastPolicy(), 'block');
    });

    test('releasing the stronger lease falls back, it does not switch off',
        () async {
      await guard.acquire('consent', OverlayTouchPolicy.warn);
      await guard.acquire('reset', OverlayTouchPolicy.block);

      await guard.release('reset');

      expect(
        guard.effectivePolicy,
        OverlayTouchPolicy.warn,
        reason: 'a dialog closing must not drop the screen underneath it',
      );
      expect(lastPolicy(), 'warn');
    });

    test('the window goes off only when the last lease is gone', () async {
      await guard.acquire('consent', OverlayTouchPolicy.warn);
      await guard.acquire('reset', OverlayTouchPolicy.block);

      await guard.release('reset');
      await guard.release('consent');

      expect(guard.effectivePolicy, OverlayTouchPolicy.off);
      expect(lastPolicy(), 'off');
    });

    test('releasing an owner that never acquired changes nothing', () async {
      await guard.acquire('consent', OverlayTouchPolicy.warn);
      final before = sent.length;

      await guard.release('someone_else');

      expect(sent.length, before);
      expect(guard.effectivePolicy, OverlayTouchPolicy.warn);
    });
  });

  group('failure handling', () {
    test('a refused policy never throws into the calling surface', () async {
      const channel = MethodChannel(OverlayTouchGuard.channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(code: 'INVALID_ARG'),
          );
      final refusing = OverlayTouchGuard(channel: channel, isAndroid: true);

      // The guard is defence in depth. It must never be the reason a user
      // cannot reach a consent screen or a PIN pad.
      await expectLater(
        refusing.acquire('consent', OverlayTouchPolicy.warn),
        completes,
      );
    });

    test('a host without the channel is simply unguarded', () async {
      const channel = MethodChannel(OverlayTouchGuard.channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final missing = OverlayTouchGuard(channel: channel, isAndroid: true);

      await expectLater(
        missing.acquire('consent', OverlayTouchPolicy.warn),
        completes,
      );
    });

    test('nothing is pushed off Android', () async {
      final offPlatform = OverlayTouchGuard(
        channel: const MethodChannel(OverlayTouchGuard.channelName),
        isAndroid: false,
      );
      sent.clear();

      await offPlatform.acquire('consent', OverlayTouchPolicy.warn);

      expect(sent, isEmpty);
    });
  });

  group('native observation', () {
    test('an obscured touch is surfaced with the policy that was in force',
        () async {
      await guard.handleNativeCallForTesting(
        const MethodCall('onObscuredTouch', 'block'),
      );

      expect(guard.lastObscuredTouch.value, OverlayTouchPolicy.block);
    });

    test('an unknown payload is still reported, not dropped', () async {
      // The observation matters more than the label: an overlay was seen.
      await guard.handleNativeCallForTesting(
        const MethodCall('onObscuredTouch', 'something_else'),
      );

      expect(guard.lastObscuredTouch.value, isNotNull);
    });

    test('an unrelated method does not raise a warning', () async {
      await guard.handleNativeCallForTesting(const MethodCall('somethingElse'));

      expect(guard.lastObscuredTouch.value, isNull);
    });
  });
}
