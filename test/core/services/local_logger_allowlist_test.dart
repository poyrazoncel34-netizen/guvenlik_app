import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/local_logger_service.dart';

void main() {
  test('persistent local diagnostics expose only allowlisted event codes', () {
    expect(
      LocalWarningCode.values.map((value) => value.wireCode),
      containsAll(<String>{
        'revenuecat_legal_acceptance_required',
        'revenuecat_disabled_in_smoke',
        'revenuecat_api_key_missing',
      }),
    );

    final source = File(
      'lib/core/services/local_logger_service.dart',
    ).readAsStringSync();
    expect(source, contains('warningCode(LocalWarningCode code)'));
    expect(source, contains('errorCode(LocalErrorCode code)'));
    expect(
      source,
      isNot(contains('warning(String tag, String message)')),
      reason:
          'A free-form persistent warning API can store phone numbers, SDK '
          'identifiers, coordinates, or exception text.',
    );
    expect(
      source,
      isNot(contains('errorCode(String tag, LocalErrorCode code)')),
      reason: 'Even a typed error must not persist a caller-controlled tag.',
    );
  });

  test('RevenueCat diagnostics use the typed local warning allowlist', () {
    final source = File(
      'lib/core/services/revenue_cat_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('.warning(')));
    expect(
      source,
      contains('LocalWarningCode.revenueCatLegalAcceptanceRequired'),
    );
    expect(source, contains('LocalWarningCode.revenueCatDisabledInSmoke'));
    expect(source, contains('LocalWarningCode.revenueCatApiKeyMissing'));
  });
}
