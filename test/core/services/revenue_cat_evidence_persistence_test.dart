import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/revenue_cat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FaultStore extends InMemorySharedPreferencesStore {
  _FaultStore(this.throws)
    : super.withData({
        'flutter.${RevenueCatService.priorProInitializationHintKey}': true,
        'flutter.${RevenueCatService.lastVerifiedProAtKey}': 1000,
      });
  final bool throws;
  bool failWrites = false;
  bool failBothRemovals = false;
  final removed = <String>[];
  @override
  Future<bool> remove(String key) async {
    removed.add(key);
    if (failBothRemovals ||
        key.endsWith(RevenueCatService.lastVerifiedProAtKey)) {
      if (throws) throw StateError('synthetic storage failure');
      return false;
    }
    return super.remove(key);
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (failWrites) {
      if (throws) throw StateError('synthetic storage failure');
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final throws in [false, true]) {
    test(
      'denial invalidates hint even when anchor removal fails throws=$throws',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = _FaultStore(throws);
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = store;
        final service = RevenueCatService();
        await expectLater(service.clearLastVerifiedProAt(), throwsStateError);
        expect(store.removed, hasLength(2));
        await (await SharedPreferences.getInstance()).reload();
        expect(await service.hasPriorProInitializationHint(), isFalse);
        expect(await service.readLastVerifiedProAt(), isNotNull);
      },
    );
    test(
      'total storage failure is surfaced without a false durability claim throws=$throws',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = _FaultStore(throws)..failBothRemovals = true;
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = store;
        final service = RevenueCatService();
        await expectLater(service.clearLastVerifiedProAt(), throwsStateError);
        expect(await service.hasPriorProInitializationHint(), isTrue);
        expect(await service.readLastVerifiedProAt(), isNotNull);
        store.failWrites = true;
        await expectLater(
          service.rememberVerifiedProAt(DateTime(2026)),
          throwsStateError,
        );
        await expectLater(
          service.rememberVerifiedProInitializationHint(),
          throwsStateError,
        );
      },
    );
  }
}
