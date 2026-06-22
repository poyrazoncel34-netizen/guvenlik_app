import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// D1(a) regression: under Android 15 edge-to-edge (targetSdk 35 +
/// setEnabledSystemUIMode(edgeToEdge)), pushed full-screen scaffolds must pad
/// their bottom by the system gesture-nav inset so trailing content/buttons
/// clear the navigation bar. Source-contract: each affected screen references
/// MediaQuery.viewPaddingOf(context).bottom for its bottom inset.
void main() {
  const screens = <String>[
    'lib/screens/subscription/paywall_screen.dart',
    'lib/screens/subscription/subscription_management_screen.dart',
    'lib/screens/profile_page.dart',
    'lib/screens/edit_profile_screen.dart',
    'lib/screens/settings_detail_page.dart',
    'lib/screens/safety_timeline_screen.dart',
    'lib/screens/check_in_screen.dart',
    'lib/screens/settings_legal/legal_settings_screen.dart',
    'lib/screens/settings_legal/data_deletion_screen.dart',
    'lib/screens/settings_legal/data_export_screen.dart',
    'lib/screens/legal/consent_management_screen.dart',
    'lib/screens/legal/age_verification_screen.dart',
    'lib/screens/legal/consent_screen.dart',
    'lib/screens/legal/terms_of_service_screen.dart',
    'lib/screens/legal/kvkk_disclosure_screen.dart',
  ];

  group('full-screen scaffolds pad the bottom system inset (edge-to-edge)', () {
    for (final path in screens) {
      test(path, () {
        final src = File(path).readAsStringSync();
        expect(
          src.contains('MediaQuery.viewPaddingOf(context).bottom'),
          isTrue,
          reason: '$path must pad its bottom by the gesture-nav inset',
        );
      });
    }
  });
}
