// A-022, second half. `AppEnvironment.isDev` was fixed to name its own
// environment, but RevenueCatService kept a private copy of the same defect:
// `_isProduction ? production : dev`, so every non-production ENV -- ci_smoke
// included -- got the DEV key policy and accepted a `test_` sandbox key.
//
// The policy is a pure function of (environment, key), so all four cases are
// exercised directly: production, dev, ci_smoke, and an ENV that names no
// environment. Only the key policy is under test; entitlement, purchase and
// restore handling are out of scope here (audit A-003).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/config/app_environment.dart';
import 'package:guvenlik_app/core/services/revenue_cat_service.dart';

const String kPublicKey = 'goog_publicAndroidSdkKey1234';
const String kSandboxKey = 'test_sandboxClientKey1234';
const String kSecretKey = 'sk_secretServerKey1234';

bool allowed(String env, String key) =>
    RevenueCatService.isClientKeyAllowedFor(env, key);

void main() {
  group('RevenueCat client-key policy over three environments', () {
    test('production accepts only the public goog_ key', () {
      expect(allowed('production', kPublicKey), isTrue);
      expect(allowed('production', kSandboxKey), isFalse);
      expect(allowed('production', kSecretKey), isFalse);
      expect(allowed('production', ''), isFalse);
      expect(
        allowed('production', AppEnvironment.ciSmokeRevenueCatKey),
        isFalse,
      );
    });

    test('dev accepts public and sandbox client keys, never a secret one', () {
      expect(allowed('dev', kPublicKey), isTrue);
      expect(allowed('dev', kSandboxKey), isTrue);
      expect(allowed('dev', kSecretKey), isFalse);
      expect(allowed('dev', AppEnvironment.ciSmokeRevenueCatKey), isFalse);
    });

    test('ci_smoke does NOT inherit the dev policy', () {
      // The exact regression: under `_isProduction ? prod : dev` the first
      // two were true, so a smoke build handed a real key configured billing.
      expect(
        allowed('ci_smoke', kSandboxKey),
        isFalse,
        reason: 'ci_smoke is its own environment, not a flavour of dev',
      );
      expect(allowed('ci_smoke', kPublicKey), isFalse);
      expect(allowed('ci_smoke', kSecretKey), isFalse);
      expect(allowed('ci_smoke', AppEnvironment.ciSmokeRevenueCatKey), isFalse);
    });

    test(
      'an ENV that names no environment gets no key policy (fail closed)',
      () {
        for (final env in const <String>['produciton', 'staging', 'DEV', '']) {
          expect(allowed(env, kPublicKey), isFalse, reason: env);
          expect(allowed(env, kSandboxKey), isFalse, reason: env);
        }
      },
    );

    test('the service no longer keeps its own copy of ENV', () {
      // Binds the tested function to what initialization actually reads: a
      // second, private `String.fromEnvironment('ENV')` is how the defect
      // survived the AppEnvironment fix.
      final source = File(
        'lib/core/services/revenue_cat_service.dart',
      ).readAsStringSync();
      expect(source, isNot(contains("String.fromEnvironment('ENV')")));
      // Whitespace-agnostic: a reflow of the call site is not a regression.
      expect(
        source,
        contains(RegExp(r'isClientKeyAllowedFor\(\s*AppEnvironment\.name\s*,')),
      );
    });
  });
}
