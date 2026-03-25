import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings_page shake toggle gates on SubscriptionGate.canUseProFeature', () {
    final source = File('lib/screens/settings_page.dart').readAsStringSync();
    expect(
      source.contains('SubscriptionGate.canUseProFeature'),
      isTrue,
      reason: 'settings_page.dart must gate shake toggle behind SubscriptionGate.canUseProFeature',
    );
  });
}
