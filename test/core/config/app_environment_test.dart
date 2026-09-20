// A-022: `isDev` was `!isProduction`, which folded `ci_smoke` into "dev".
//
// The getters read `String.fromEnvironment('ENV')`, a COMPILE-TIME constant,
// so a unit test cannot vary it -- that is why the defect shipped untested.
// AppEnvironment therefore exposes the classification as pure functions over
// the environment string, and this file exercises all three values plus the
// unknown one.
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/config/app_environment.dart';

void main() {
  group('AppEnvironment classifies three environments, not two', () {
    test('each environment matches exactly its own predicate', () {
      const cases = <String, List<bool>>{
        // env         : [isProduction, isCiSmoke, isDev]
        'production': <bool>[true, false, false],
        'ci_smoke': <bool>[false, true, false],
        'dev': <bool>[false, false, true],
      };
      for (final entry in cases.entries) {
        final env = entry.key;
        expect(
          <bool>[
            AppEnvironment.envIsProduction(env),
            AppEnvironment.envIsCiSmoke(env),
            AppEnvironment.envIsDev(env),
          ],
          entry.value,
          reason: '$env must match one predicate and only one',
        );
      }
    });

    test('ci_smoke is NOT dev', () {
      // The exact regression: under `isDev => !isProduction` this was true and
      // any future `if (isDev)` branch would have taken the dev path during a
      // release-verification build.
      expect(
        AppEnvironment.envIsDev('ci_smoke'),
        isFalse,
        reason: 'ci_smoke is its own environment, not a flavour of dev',
      );
      expect(AppEnvironment.envIsCiSmoke('ci_smoke'), isTrue);
    });

    test('an unknown ENV value belongs to no environment (fail closed)', () {
      // A typo must not silently become "dev" (or anything else). Three
      // literals give that for free; a negation could not.
      const typo = 'produciton';
      expect(AppEnvironment.envIsProduction(typo), isFalse);
      expect(AppEnvironment.envIsCiSmoke(typo), isFalse);
      expect(AppEnvironment.envIsDev(typo), isFalse);
    });

    test('the live getters agree with the predicates for this build', () {
      // Binds the compile-time getters to the tested pure functions, so the
      // seam cannot drift away from what production actually reads.
      expect(
        AppEnvironment.isProduction,
        AppEnvironment.envIsProduction(AppEnvironment.name),
      );
      expect(
        AppEnvironment.isCiSmoke,
        AppEnvironment.envIsCiSmoke(AppEnvironment.name),
      );
      expect(AppEnvironment.isDev, AppEnvironment.envIsDev(AppEnvironment.name));
    });
  });
}
