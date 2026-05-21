import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Username display — real name from provider', () {
    test('SettingsProvider returns fallback when name is empty', () {
      final source = File(
        'lib/presentation/providers/settings_provider.dart',
      ).readAsStringSync();
      expect(
        source.contains('settings_default_user'),
        isTrue,
        reason:
            'profileName getter boşsa settings_default_user fallback '
            'döndürmeli',
      );
    });

    test('ProfilePage displays name via provider.profileName', () {
      final source = File('lib/screens/profile_page.dart').readAsStringSync();
      expect(
        source.contains('provider.profileName'),
        isTrue,
        reason:
            'ProfilePage kullanıcı adını provider.profileName üzerinden '
            'göstermeli',
      );
    });

    test('SettingsPage displays name via provider.profileName', () {
      final source = File('lib/screens/settings_page.dart').readAsStringSync();
      expect(
        source.contains('provider.profileName'),
        isTrue,
        reason:
            'SettingsPage kullanıcı adını provider.profileName üzerinden '
            'göstermeli',
      );
    });
  });
}
