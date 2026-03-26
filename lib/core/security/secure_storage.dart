import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const bool encryptedPrefsEnabled = true;

  // Android: EncryptedSharedPreferences (Keystore-backed AES-256)
  static final _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }

  Future<void> deleteAll() {
    return _storage.deleteAll();
  }
}
