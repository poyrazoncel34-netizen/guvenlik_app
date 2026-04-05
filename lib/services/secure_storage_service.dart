import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';

class SecureStorageService {
  static SecureStorage get _s => serviceLocator<SecureStorage>();

  static Future<void> write({required String key, required String value}) =>
      _s.write(key: key, value: value);

  static Future<String?> read({required String key}) => _s.read(key: key);

  static Future<void> delete({required String key}) => _s.delete(key: key);

  static Future<void> deleteAll() => _s.deleteAll();
}
