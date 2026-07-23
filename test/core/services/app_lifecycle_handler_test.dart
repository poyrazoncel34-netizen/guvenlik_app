import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/app_lifecycle_handler.dart';

void main() {
  test('reauthentication threshold is inclusive and PIN-dependent', () {
    expect(
      resumeRequiresAuthentication(
        backgroundElapsed: const Duration(seconds: 119),
        pinConfigured: true,
      ),
      isFalse,
    );
    expect(
      resumeRequiresAuthentication(
        backgroundElapsed: const Duration(seconds: 120),
        pinConfigured: true,
      ),
      isTrue,
    );
    expect(
      resumeRequiresAuthentication(
        backgroundElapsed: const Duration(days: 1),
        pinConfigured: false,
      ),
      isFalse,
    );
  });
}
