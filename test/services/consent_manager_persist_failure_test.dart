// ============================================================================
// CONSENT MANAGER — Kalıcılık / hata yüzeye çıkarma regresyonu (S11)
// ============================================================================
// Rıza değişikliği secure storage'a yazılamadığında SESSİZCE yutulmamalı:
// grantConsent hatayı yukarı taşımalı ve önbelleği "granted" olarak
// güncellememeli (aksi halde toggle kaydolmuş gibi görünüp yeniden açılışta
// geri döner). Okuma tümüyle başarısızsa loadFailed = true olmalı.
// ============================================================================

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/services/consent_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> store;
  late bool failWrites;
  late bool failReads;

  setUp(() {
    store = {};
    failWrites = false;
    failReads = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          final args = call.arguments is Map
              ? Map<String, dynamic>.from(call.arguments as Map)
              : <String, dynamic>{};
          switch (call.method) {
            case 'read':
              if (failReads) {
                throw PlatformException(code: 'storage_error');
              }
              return store[args['key'] as String];
            case 'readAll':
              return Map<String, dynamic>.from(store);
            case 'write':
              if (failWrites) {
                throw PlatformException(code: 'storage_error');
              }
              store[args['key'] as String] = args['value'] as String;
              return null;
            case 'delete':
              store.remove(args['key'] as String);
              return null;
            case 'deleteAll':
              store.clear();
              return null;
            case 'containsKey':
              return store.containsKey(args['key'] as String);
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('grantConsent propagates a write failure and does not cache it',
      () async {
    final cm = ConsentManager();
    await cm.initialize();
    failWrites = true;

    await expectLater(
      cm.grantConsent(ConsentRecord.typeLocation),
      throwsA(isA<PlatformException>()),
    );
    expect(
      cm.isGranted(ConsentRecord.typeLocation),
      isFalse,
      reason: 'a failed write must not leave the consent cached as granted',
    );
  });

  test('grantConsent persists across a reload when the write succeeds',
      () async {
    final cm = ConsentManager();
    await cm.initialize();

    await cm.grantConsent(ConsentRecord.typeLocation);
    expect(cm.isGranted(ConsentRecord.typeLocation), isTrue);

    // A fresh manager reads the same backing store and still sees the consent.
    final reloaded = ConsentManager();
    await reloaded.initialize();
    expect(reloaded.isGranted(ConsentRecord.typeLocation), isTrue);
    expect(reloaded.loadFailed, isFalse);
  });

  test('loadFailed is true when secure storage read throws', () async {
    failReads = true;
    final cm = ConsentManager();
    await cm.initialize();
    expect(cm.loadFailed, isTrue);
  });

  test('loadFailed stays false on a clean load', () async {
    final cm = ConsentManager();
    await cm.initialize();
    expect(cm.loadFailed, isFalse);
  });
}
