import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/services/data_migration_service.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';

void main() {
  group('DataMigrationService v2', () {
    test('sets schema version to 2 after migration', () async {
      SharedPreferences.setMockInitialValues({'data_schema_version': 1});

      await DataMigrationService.migrate();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('data_schema_version'), equals(2));
    });

    test('migrates from v1 to v2 and resets PIN setup flag', () async {
      SharedPreferences.setMockInitialValues({
        'data_schema_version': 1,
        AppConstants.prefPinSetupDone: true,
      });

      await DataMigrationService.migrate();

      final prefs = await SharedPreferences.getInstance();
      // Key is removed or set to false — either way PIN setup is no longer marked done
      expect(prefs.getBool(AppConstants.prefPinSetupDone) ?? false, isFalse);
    });

    test('skips v2 migration if already at version 2', () async {
      SharedPreferences.setMockInitialValues({
        'data_schema_version': 2,
        AppConstants.prefPinSetupDone: true,
      });

      await DataMigrationService.migrate();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.prefPinSetupDone), isTrue);
    });
  });
}
