import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/local_logger_service.dart';

void main() {
  test('redacts phone, location, email and filesystem path', () {
    const raw =
        'call +90 500 123 45 67 at 41.0082, 28.9784 for user@example.com '
        'from /data/user/0/com.poyrazoncel.korubeni/files/state.json';

    final redacted = LocalLoggerService.redactSensitive(raw);

    expect(redacted, contains('[redacted-phone]'));
    expect(redacted, contains('[redacted-location]'));
    expect(redacted, contains('[redacted-email]'));
    expect(redacted, contains('[redacted-path]'));
    expect(redacted, isNot(contains('500 123')));
    expect(redacted, isNot(contains('41.0082')));
    expect(redacted, isNot(contains('user@example.com')));
    expect(redacted, isNot(contains('/data/user/0')));
  });

  test('does not alter allowlisted diagnostic wire codes', () {
    for (final code in LocalErrorCode.values) {
      expect(LocalLoggerService.redactSensitive(code.wireCode), code.wireCode);
    }
    for (final code in LocalWarningCode.values) {
      expect(LocalLoggerService.redactSensitive(code.wireCode), code.wireCode);
    }
  });
}
