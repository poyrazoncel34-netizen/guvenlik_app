// Verify OSM User-Agent includes contact info per OSMF tile usage policy.
// https://operations.osmfoundation.org/policies/tiles/
// "If you have a way to contact your users (for example, an email address
//  or other contact form), it is highly recommended to include it in the
//  User-Agent."
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/utils/map_utils.dart';

void main() {
  group('OSM tile User-Agent compliance', () {
    test('User-Agent identifier contains application package name', () {
      expect(
        kOsmUserAgentPackageName,
        contains('com.poyrazoncel.korubeni'),
        reason: 'OSM operations team must be able to identify the app source.',
      );
    });

    test('User-Agent identifier contains a contact channel', () {
      // OSMF policy: contact channel "highly recommended" so ops can reach
      // the developer if usage looks abusive. We accept either an email
      // address or an https:// URL as a valid contact channel.
      final hasEmail = RegExp(
        r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
      ).hasMatch(kOsmUserAgentPackageName);
      final hasUrl = kOsmUserAgentPackageName.contains('https://');

      expect(
        hasEmail || hasUrl,
        isTrue,
        reason:
            'OSMF tile policy highly recommends a contact channel in the '
            'User-Agent; expected an email or https URL inside '
            'kOsmUserAgentPackageName.',
      );
    });
  });
}
