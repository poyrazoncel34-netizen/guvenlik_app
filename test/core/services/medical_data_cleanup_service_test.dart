import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/medical_data_cleanup_service.dart';

class _FakeSecureStorage extends SecureStorage {
  final Map<String, String> store = {};
  int deleteCount = 0;

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> delete({required String key}) async {
    deleteCount++;
    store.remove(key);
  }

  @override
  Future<void> deleteAll() async => store.clear();
}

class _FaultingMedicalCleanupStore implements MedicalDataCleanupStore {
  _FaultingMedicalCleanupStore({this.rejectedPreferenceKey});

  final String? rejectedPreferenceKey;
  final List<String> operations = [];
  bool completionPublished = false;

  @override
  Future<bool> isCleanupDone() async => false;

  @override
  Future<bool> removePreference(String key) async {
    operations.add('remove:$key');
    return key != rejectedPreferenceKey;
  }

  @override
  Future<void> deleteSecureMedicalProfile() async {
    operations.add('secure');
  }

  @override
  Future<bool> publishCleanupDone() async {
    operations.add('publish');
    completionPublished = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecureStorage secure;

  setUp(() async {
    await serviceLocator.reset();
    secure = _FakeSecureStorage();
    serviceLocator.registerSingleton<SecureStorage>(secure);
  });

  tearDown(() async {
    await serviceLocator.reset();
  });

  test('purges legacy medical prefs and secure blob on first run', () async {
    SharedPreferences.setMockInitialValues({
      // ignore: deprecated_member_use_from_same_package
      AppConstants.prefBloodType: '0 Rh+',
      // ignore: deprecated_member_use_from_same_package
      AppConstants.prefAllergies: 'penicillin',
    });
    // ignore: deprecated_member_use_from_same_package
    secure.store[SecureStorageKeys.medicalProfile] = '{"bloodType":"0 Rh+"}';

    await MedicalDataCleanupService.purgeIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    // ignore: deprecated_member_use_from_same_package
    expect(prefs.getString(AppConstants.prefBloodType), isNull);
    // ignore: deprecated_member_use_from_same_package
    expect(prefs.getString(AppConstants.prefAllergies), isNull);
    // ignore: deprecated_member_use_from_same_package
    expect(secure.store[SecureStorageKeys.medicalProfile], isNull);
    expect(prefs.getBool(AppConstants.prefMedicalCleanupDone), isTrue);
    expect(secure.deleteCount, 1);
  });

  test('is a no-op once the cleanup flag is set', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefMedicalCleanupDone: true,
    });

    await MedicalDataCleanupService.purgeIfNeeded();

    expect(secure.deleteCount, 0);
  });

  test('does not throw when there is nothing to purge', () async {
    SharedPreferences.setMockInitialValues({});

    await MedicalDataCleanupService.purgeIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConstants.prefMedicalCleanupDone), isTrue);
  });

  test(
    'failed legacy-key deletion never publishes the completion marker',
    () async {
      final store = _FaultingMedicalCleanupStore(
        // ignore: deprecated_member_use_from_same_package
        rejectedPreferenceKey: AppConstants.prefAllergies,
      );

      await MedicalDataCleanupService.purgeIfNeeded(store: store);

      // ignore: deprecated_member_use_from_same_package
      const bloodTypeKey = AppConstants.prefBloodType;
      // ignore: deprecated_member_use_from_same_package
      const emergencyNotesKey = AppConstants.prefEmergencyNotes;
      expect(store.completionPublished, isFalse);
      expect(store.operations, contains('secure'));
      expect(store.operations, contains('remove:$bloodTypeKey'));
      expect(store.operations, contains('remove:$emergencyNotesKey'));
      expect(store.operations, isNot(contains('publish')));
    },
  );
}
