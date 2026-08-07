import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('premium gating contracts', () {
    late String home;
    late String navigation;
    late String contacts;
    late String settings;
    late String panicButton;

    setUp(() {
      home = File('lib/screens/home_page.dart').readAsStringSync();
      navigation = File('lib/screens/main_navigation.dart').readAsStringSync();
      contacts = File('lib/screens/contacts_page.dart').readAsStringSync();
      settings = File('lib/screens/settings_page.dart').readAsStringSync();
      panicButton = File('lib/widgets/panic_button.dart').readAsStringSync();
    });

    test('Contacts tab has no premium gate — contacts is free', () {
      // contacts is now a free feature; the nav must NOT gate the contacts tab
      expect(
        navigation,
        isNot(contains('PremiumFeature.contacts')),
        reason: 'contacts is free — no gate should exist in main_navigation',
      );
    });

    test('red quick help FAB is not present in main navigation', () {
      expect(navigation, isNot(contains('FloatingActionButton')));
      expect(navigation, isNot(contains('quick_help')));
      expect(navigation, isNot(contains('_showQuickHelp')));
      expect(navigation, isNot(contains('_buildHelpOption')));
    });

    test('home quick actions use the central premium gate', () {
      expect(home, contains('_runGated(data.feature, data.onTap)'));
      expect(home, contains('PremiumFeature.fakeCall'));
      expect(home, contains('PremiumFeature.siren'));
      expect(home, contains('PremiumFeature.safeWalk'));
      expect(home, contains('PremiumFeature.contacts'));
      expect(home, contains('PremiumFeature.timeline'));
      expect(home, contains('PremiumFeature.checkIn'));
    });

    test('test mode is reachable by free users, not hidden behind isPro', () {
      expect(home, contains('context.watch<SubscriptionProvider>().isPro'));
      // Test mode is the rehearsal of the panic flow: it dials nothing and
      // sends nothing. Hiding it from free users made the locked SOS button
      // unprovable, so the entry point must NOT sit inside an isPro branch.
      expect(
        RegExp(
          r'if\s*\(isPro\)[\s\S]{0,160}_buildTestModeButton\(\)',
        ).hasMatch(home),
        isFalse,
        reason: 'test mode entry must not be gated on isPro',
      );
      expect(home, contains('_buildTestModeButton()'));
      expect(home, contains('PremiumFeature.testMode'));
      expect(home, contains('CountdownScreen(isTestMode: true)'));
    });

    test('contact management entry points use central Pro gate', () {
      expect(contacts, contains('PremiumFeature.emergencyContactAdd'));
      expect(contacts, contains('PremiumFeature.emergencyContactSelect'));
      expect(contacts, contains('SubscriptionGate.ensureAccess'));
    });

    test('volume trigger and panic button use central Pro gate', () {
      expect(settings, contains('PremiumFeature.volumeTrigger'));
      expect(settings, contains('SubscriptionGate.ensureAccess'));
      expect(panicButton, contains('PremiumFeature.panic'));
      expect(panicButton, contains('SubscriptionGate.ensureAccess'));
    });
  });
}
