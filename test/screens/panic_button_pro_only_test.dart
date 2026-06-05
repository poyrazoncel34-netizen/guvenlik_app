import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Panic button Pro-only honesty', () {
    late String source;

    setUp(() {
      source = File('lib/widgets/panic_button.dart').readAsStringSync();
    });

    test('free users see locked Pro copy before long press', () {
      expect(source, contains('panic_button_locked_title'));
      expect(source, contains('panic_button_locked_subtitle'));
      expect(source, contains('subscription_badge_pro'));
      expect(source, contains('context.watch<SubscriptionProvider>().isPro'));
    });

    test('free long press uses SubscriptionGate and cannot open countdown', () {
      final startIndex = source.indexOf('Future<void> _onPressStart');
      final openIndex = source.indexOf('Future<void> _openCountdownScreen');
      final pressStart = source.substring(startIndex, openIndex);

      expect(pressStart, contains('PremiumFeature.panic'));
      expect(pressStart, contains('SubscriptionGate.ensureAccess'));
      expect(pressStart, contains('if (!allowed || !mounted) return;'));
    });

    test('Pro users retain active panic copy and countdown route', () {
      expect(source, contains('panic_button_hold_title'));
      expect(source, contains('panic_button_hold_subtitle'));
      expect(source, contains('const CountdownScreen()'));
    });
  });
}
