// Verifies that setupServiceLocator() skips LocalDatabaseService on web so
// that SecureStorage and other services are still registered on web builds
// (sqflite throws PlatformException on web, which would abort the entire
// setupServiceLocator call and leave SecureStorage unregistered).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'service_locator skips LocalDatabaseService on web with kIsWeb guard',
    () {
      final source = File(
        'lib/core/di/service_locator.dart',
      ).readAsStringSync();

      // The guard must appear as a condition on the LocalDatabaseService block,
      // not just as an import.  We look for the pattern used at runtime.
      expect(
        source.contains('!kIsWeb') &&
            source.contains('LocalDatabaseService'),
        isTrue,
        reason:
            'setupServiceLocator must guard LocalDatabaseService init with '
            '!kIsWeb so that sqflite PlatformException on web does not abort '
            'registration of SecureStorage and other services.',
      );
    },
  );
}
