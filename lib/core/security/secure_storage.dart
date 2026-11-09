import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const bool encryptedPrefsEnabled = true;

  // Android: flutter_secure_storage uses platform-backed encrypted storage.
  //
  // resetOnError MUST stay false. flutter_secure_storage 10 defaults it to
  // TRUE (its doc comment says false): on any decryption/keystore failure the
  // plugin deletes the entry and answers null. A corrupt PIN then read as "no
  // PIN" and the app opened on PIN setup instead of the lock (reproduced on an
  // API 35 emulator); contacts and lockout counters vanished the same way.
  // Thrown, the error reaches the fail-closed paths built for it.
  //
  // migrateWithBackup (>= 10.1): a cipher migration copies the encrypted
  // entries to *_BACKUP first, so a crash between "old key deleted" and "data
  // re-encrypted" no longer loses the PIN and contacts. On 10.x it also skips
  // re-initialising the deprecated EncryptedSharedPreferences master key on
  // every cold start. This app never wrote EncryptedSharedPreferences data
  // (10.0.0 with migrateOnAlgorithmChange=true always used custom ciphers), so
  // that skip strands nothing.
  //
  // Every FlutterSecureStorage instance that opens this store MUST pass these
  // exact options: the plugin keeps one native store per process.
  static const AndroidOptions androidOptions = AndroidOptions(
    resetOnError: false,
    migrateOnAlgorithmChange: true,
    migrateWithBackup: true,
  );

  static const _storage = FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
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
