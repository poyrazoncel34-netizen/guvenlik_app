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

    test('fails closed when the PIN reset cannot be committed', () async {
      final store = _FaultingMigrationPreferences(
        values: <String, Object>{'data_schema_version': 1},
        rejectBoolWrites: true,
      );

      await expectLater(
        DataMigrationService.migrate(store: store),
        throwsA(isA<StateError>()),
      );
      expect(store.getInt('data_schema_version'), 1);
    });

    test('fails closed when the schema version cannot be committed', () async {
      final store = _FaultingMigrationPreferences(
        values: <String, Object>{'data_schema_version': 1},
        rejectIntWrites: true,
      );

      await expectLater(
        DataMigrationService.migrate(store: store),
        throwsA(isA<StateError>()),
      );
      expect(store.getInt('data_schema_version'), 1);
    });
  });
}

class _FaultingMigrationPreferences implements MigrationPreferences {
  _FaultingMigrationPreferences({
    required Map<String, Object> values,
    this.rejectBoolWrites = false,
    this.rejectIntWrites = false,
  }) : _values = Map<String, Object>.of(values);

  final Map<String, Object> _values;
  final bool rejectBoolWrites;
  final bool rejectIntWrites;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  Future<bool> setBool(String key, bool value) async {
    if (rejectBoolWrites) return false;
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    if (rejectIntWrites) return false;
    _values[key] = value;
    return true;
  }
}
