// flutter_secure_storage 10 defaults AndroidOptions.resetOnError to TRUE
// (its own doc comment says "Defaults to false"). With it, ANY decryption or
// keystore failure makes the plugin delete the entry and answer null.
//
// Reproduced on an API 35 emulator: one byte of the stored user_pin
// ciphertext changed -> AEADBadTagException -> "Attempting to delete
// corrupted data and retry..." -> PIN gone -> the app opened on "Güvenlik
// PIN'i Belirleyin" instead of the lock. Every fail-closed branch this app
// has for an unreadable PIN, contact list or lockout counter was unreachable:
// the plugin turned the error into absence before Dart could see it.
//
// These cases pin the option at the channel boundary, where the plugin
// actually reads it.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  String? resetOnError(MethodCall call) =>
      ((call.arguments as Map)['options'] as Map)['resetOnError'] as String?;

  test('the app store never lets the plugin delete data on an error', () async {
    final storage = SecureStorage();
    await storage.read(key: SecureStorageKeys.userPin);
    await storage.write(key: SecureStorageKeys.userPin, value: 'x');
    await storage.delete(key: SecureStorageKeys.userPin);
    await storage.deleteAll();

    expect(calls, hasLength(4));
    for (final call in calls) {
      expect(resetOnError(call), 'false', reason: call.method);
    }
  });

  test('the legacy consent read is read-only even when it fails', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ConsentManager().initialize();

    final reads = calls.where((c) => c.method == 'read').toList();
    expect(reads, isNotEmpty, reason: 'precondition: the legacy read ran');
    for (final call in reads) {
      expect(resetOnError(call), 'false');
    }
  });
}
