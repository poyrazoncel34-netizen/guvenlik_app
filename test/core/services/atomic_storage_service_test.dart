import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/atomic_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('successful typed writes replace values and remove backups', () async {
    final service = AtomicStorageService.instance;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', 'old');
    await prefs.setInt('count', 1);
    await prefs.setBool('enabled', false);

    expect(await service.writeString('name', 'new'), isTrue);
    expect(await service.writeInt('count', 2), isTrue);
    expect(await service.writeBool('enabled', true), isTrue);

    expect(prefs.getString('name'), 'new');
    expect(prefs.getInt('count'), 2);
    expect(prefs.getBool('enabled'), isTrue);
    expect(prefs.containsKey('name_backup'), isFalse);
    expect(prefs.containsKey('count_backup'), isFalse);
    expect(prefs.containsKey('enabled_backup'), isFalse);
  });

  test('reads recover missing typed values from their backups', () async {
    final service = AtomicStorageService.instance;
    SharedPreferences.setMockInitialValues({
      'name_backup': 'restored',
      'count_backup': 7,
      'enabled_backup': true,
    });

    expect(await service.readString('name'), 'restored');
    expect(await service.readInt('count'), 7);
    expect(await service.readBool('enabled'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('name'), 'restored');
    expect(prefs.getInt('count'), 7);
    expect(prefs.getBool('enabled'), isTrue);
  });

  test('JSON round trip is typed and malformed JSON fails closed', () async {
    final service = AtomicStorageService.instance;

    expect(await service.writeJson('payload', {'generation': 3}), isTrue);
    expect(await service.readJson('payload'), {'generation': 3});

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payload', 'not-json');
    expect(await service.readJson('payload'), isNull);
  });

  test('integrity check restores every supported orphan backup', () async {
    SharedPreferences.setMockInitialValues({
      'name_backup': 'safe',
      'count_backup': 4,
      'enabled_backup': true,
      'existing': 'current',
      'existing_backup': 'stale',
    });

    await AtomicStorageService.instance.checkIntegrity();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('name'), 'safe');
    expect(prefs.getInt('count'), 4);
    expect(prefs.getBool('enabled'), isTrue);
    expect(prefs.getString('existing'), 'current');
  });

  test('delete removes both primary and recovery value', () async {
    SharedPreferences.setMockInitialValues({
      'session': 'current',
      'session_backup': 'previous',
    });

    expect(await AtomicStorageService.instance.delete('session'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('session'), isFalse);
    expect(prefs.containsKey('session_backup'), isFalse);
  });
}
