import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/atomic_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _RejectingStore extends InMemorySharedPreferencesStore {
  _RejectingStore(super.initialData) : super.withData();

  String? rejectKey;
  bool rejected = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (!rejected && key == rejectKey) {
      rejected = true;
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_RejectingStore> installStore(Map<String, Object> values) async {
    final store = _RejectingStore(values);
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    return store;
  }

  test('HATA-05: rejected string commit rolls the prior value back', () async {
    final store = await installStore(<String, Object>{
      'flutter.profile_name': 'onceki',
    });
    store.rejectKey = 'flutter.profile_name';

    expect(
      await AtomicStorageService.instance.writeString('profile_name', 'yeni'),
      isFalse,
    );
    await (await SharedPreferences.getInstance()).reload();
    expect(
      (await SharedPreferences.getInstance()).getString('profile_name'),
      'onceki',
    );
    expect(store.rejected, isTrue, reason: 'the negative branch must run');
  });

  test('HATA-05: rejected int commit rolls the prior value back', () async {
    final store = await installStore(<String, Object>{
      'flutter.retry_count': 2,
    });
    store.rejectKey = 'flutter.retry_count';

    expect(
      await AtomicStorageService.instance.writeInt('retry_count', 3),
      isFalse,
    );
    await (await SharedPreferences.getInstance()).reload();
    expect((await SharedPreferences.getInstance()).getInt('retry_count'), 2);
    expect(store.rejected, isTrue);
  });

  test('HATA-05: rejected bool commit rolls the prior value back', () async {
    final store = await installStore(<String, Object>{
      'flutter.safety_enabled': false,
    });
    store.rejectKey = 'flutter.safety_enabled';

    expect(
      await AtomicStorageService.instance.writeBool('safety_enabled', true),
      isFalse,
    );
    await (await SharedPreferences.getInstance()).reload();
    expect(
      (await SharedPreferences.getInstance()).getBool('safety_enabled'),
      isFalse,
    );
    expect(store.rejected, isTrue);
  });

  test('HATA-05: missing main values recover from typed backups', () async {
    await installStore(<String, Object>{
      'flutter.name_backup': 'koru',
      'flutter.count_backup': 4,
      'flutter.enabled_backup': true,
    });

    expect(await AtomicStorageService.instance.readString('name'), 'koru');
    expect(await AtomicStorageService.instance.readInt('count'), 4);
    expect(await AtomicStorageService.instance.readBool('enabled'), isTrue);

    await (await SharedPreferences.getInstance()).reload();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('name'), 'koru');
    expect(prefs.getInt('count'), 4);
    expect(prefs.getBool('enabled'), isTrue);
  });
}
