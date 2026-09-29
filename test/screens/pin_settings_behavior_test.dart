import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/pin_hasher.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/utils/pin_settings_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

class _MemorySecureStorage extends SecureStorage {
  String? pin;
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<String?> read({required String key}) async {
    if (failRead) throw StateError('secure read rejected');
    return key == SecureStorageKeys.userPin ? pin : null;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrite) throw StateError('secure write rejected');
    if (key == SecureStorageKeys.userPin) pin = value;
  }
}

class _MemoryDatabaseService extends LocalDatabaseService {
  _MemoryDatabaseService(this.db);
  final Database db;
  @override
  Future<Database> get database async => db;
}

Future<void> _openSheet(WidgetTester tester) async {
  await pumpLocalized(
    tester,
    Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => PinSettingsHelper.showPinChangeSheet(context),
        child: const Text('PIN sayfasını aç'),
      ),
    ),
  );
  await tester.tap(find.text('PIN sayfasını aç'));
  await tester.pumpAndSettle();
  expect(find.byType(TextField), findsNWidgets(2));
}

Future<void> _submit(
  WidgetTester tester, {
  required String oldPin,
  required String newPin,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), oldPin);
  await tester.enterText(fields.at(1), newPin);
  await tester.tap(find.text('Kaydet'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 600)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late _MemorySecureStorage storage;
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    storage = _MemorySecureStorage();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await LocalDatabaseService.createSchema(db);
    serviceLocator.registerSingleton<SecureStorage>(storage);
    serviceLocator.registerSingleton<LocalDatabaseService>(
      _MemoryDatabaseService(db),
    );
  });

  tearDown(() async {
    await db.close();
    await serviceLocator.reset();
  });

  testWidgets('PCH-01: wrong current PIN stays open and reports the error', (
    tester,
  ) async {
    storage.pin = PinHasher.encode('4937');
    await _openSheet(tester);

    await _submit(tester, oldPin: '8642', newPin: '6284');

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Eski PIN yanlış'), findsOneWidget);
    expect(PinHasher.matches(stored: storage.pin!, candidate: '4937'), isTrue);
  });

  testWidgets('PCH-02: absent and unreadable PIN have distinct fail-closed copy', (
    tester,
  ) async {
    await _openSheet(tester);
    await _submit(tester, oldPin: '4937', newPin: '6284');
    expect(find.text('PIN bulunamadı. Lütfen yeniden oluşturun.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    storage.failRead = true;
    await _openSheet(tester);
    await _submit(tester, oldPin: '4937', newPin: '6284');
    expect(
      find.text("Güvenlik PIN'i okunamadı; PIN ile iptal kullanılamıyor."),
      findsOneWidget,
    );
  });

  testWidgets('PCH-03: invalid, weak and reused new PINs are rejected', (
    tester,
  ) async {
    storage.pin = PinHasher.encode('4937');
    await _openSheet(tester);
    await _submit(tester, oldPin: '4937', newPin: '628');
    expect(find.text('PIN 4 hane olmalıdır'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _openSheet(tester);
    await _submit(tester, oldPin: '4937', newPin: '1234');
    expect(find.text('Daha güvenli bir PIN seçin.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _openSheet(tester);
    await _submit(tester, oldPin: '4937', newPin: '4937');
    expect(
      find.text('Yeni PIN eskisiyle aynı olamaz. Farklı bir PIN seçin.'),
      findsOneWidget,
    );
  });

  testWidgets('PCH-04: successful update persists, logs, pops and confirms', (
    tester,
  ) async {
    storage.pin = PinHasher.encode('4937');
    await _openSheet(tester);

    await _submit(tester, oldPin: '4937', newPin: '6284');

    for (var attempt = 0;
        attempt < 20 && find.byType(TextField).evaluate().isNotEmpty;
        attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(PinHasher.matches(stored: storage.pin!, candidate: '6284'), isTrue);
    final events = await tester.runAsync(() => db.query('activity_events'));
    expect(events, hasLength(1));
    expect(find.byType(TextField), findsNothing);
    expect(find.text('PIN güncellendi'), findsOneWidget);
  });
}
