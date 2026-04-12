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

    test('Contacts tab gates before changing selected tab', () {
      final gateIndex = navigation.indexOf('PremiumFeature.contacts');
      final returnIndex = navigation.indexOf(
        'if (!allowed || !mounted) return;',
      );
      final setStateIndex = navigation.indexOf(
        'setState(() => _selectedIndex = index)',
      );

      expect(gateIndex, isNonNegative);
      expect(returnIndex, greaterThan(gateIndex));
      expect(setStateIndex, greaterThan(returnIndex));
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

    test('test mode is hidden for free users and gated for Pro users', () {
      expect(home, contains('context.watch<SubscriptionProvider>().isPro'));
      expect(
        RegExp(
          r'if\s*\(isPro\)[\s\S]{0,160}_buildTestModeButton\(\)',
        ).hasMatch(home),
        isTrue,
      );
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
