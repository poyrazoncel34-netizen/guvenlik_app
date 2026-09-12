import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/core/widgets/sensitive_action_pin_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/widgets/safety_session_pin_gate.dart';

class _FakeSecureStorage extends SecureStorage {
  _FakeSecureStorage({this.throwOnRead = false});

  final Map<String, String> store = <String, String>{};
  final bool throwOnRead;
  String? fault;
  int pinReads = 0;

  @override
  Future<void> write({required String key, required String value}) async {
    if (fault == 'write' && key.startsWith('pin_lockout')) throw StateError('unavailable');
    store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    if (key == SecureStorageKeys.userPin) pinReads++;
    if (fault == 'read' && key.startsWith('pin_lockout')) throw StateError('unavailable');
    if (throwOnRead) throw Exception('keystore unavailable');
    return store[key];
  }

  @override
  Future<void> delete({required String key}) async {
    if (fault == 'delete' && key.startsWith('pin_lockout')) throw StateError('unavailable');
    store.remove(key);
  }

  @override
  Future<void> deleteAll() async => store.clear();
}

Future<bool?> _runGate(
  WidgetTester tester,
  PinVerificationService service, {
  ValueChanged<bool>? onResult,
}) async {
  bool? allowed;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              allowed = await SensitiveActionPinGate.ensure(
                context,
                verificationService: service,
              );
              onResult?.call(allowed!);
            },
            child: const Text('export'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('export'));
  await tester.pumpAndSettle();
  return allowed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    if (!GetIt.instance.isRegistered<SecureStorage>()) {
      GetIt.instance.registerSingleton<SecureStorage>(_FakeSecureStorage());
    }
  });

  for (final fault in ['read', 'write', 'delete']) {
    testWidgets('counter $fault failure cannot authorize action', (tester) async {
      final storage = GetIt.instance<SecureStorage>() as _FakeSecureStorage;
      storage.store.clear();
      storage.store[SecureStorageKeys.userPin] = '4821';
      storage.fault = fault;
      final service = PinVerificationService.forTesting(secureStorage: storage);
      bool? result;
      await _runGate(tester, service, onResult: (value) => result = value);
      final readsBefore = storage.pinReads;
      await tester.enterText(find.byType(TextField), fault == 'write' ? '1111' : '4821');
      await tester.tap(find.text('reset_pin_verify_confirm'));
      await tester.pumpAndSettle();
      expect(storage.pinReads, readsBefore);
      if (fault == 'read') {
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('settings_cancel'));
        await tester.pumpAndSettle();
      }
      expect(result, isFalse);
      storage.fault = null;
      storage.store.clear();
    });
  }
  testWidgets('persistent lockout blocks verifier even after reopening', (tester) async {
    final storage = GetIt.instance<SecureStorage>() as _FakeSecureStorage;
    storage.store['pin_lockout_failed_attempts'] = '5';
    storage.store['pin_lockout_until_ms'] = '${DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch}';
    storage.store[SecureStorageKeys.userPin] = '4821';
    final service = PinVerificationService.forTesting(secureStorage: storage);
    await _runGate(tester, service);
    final readsBeforeLock = storage.pinReads;
    await tester.enterText(find.byType(TextField), '4821');
    await tester.tap(find.text('reset_pin_verify_confirm'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(storage.pinReads, readsBeforeLock);
    expect(storage.store['pin_lockout_failed_attempts'], '5');
    await tester.tap(find.text('settings_cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4821');
    await tester.tap(find.text('reset_pin_verify_confirm'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    storage.store.clear();
    await tester.tap(find.text('settings_cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('shared sensitive lockout does not throttle armed cancellation', (tester) async {
    final storage = GetIt.instance<SecureStorage>() as _FakeSecureStorage;
    storage.store.clear();
    storage.store[SecureStorageKeys.userPin] = '4821';
    storage.store['pin_lockout_failed_attempts'] = '5';
    storage.store['pin_lockout_until_ms'] = '${DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch}';
    final service = PinVerificationService.forTesting(secureStorage: storage);
    await _runGate(tester, service);
    await tester.enterText(find.byType(TextField), '4821');
    await tester.tap(find.text('reset_pin_verify_confirm'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('settings_cancel'));
    await tester.pumpAndSettle();
    bool? cancelled;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
      onPressed: () async { cancelled = await SafetySessionPinGate.verify(context, verificationService: service); },
      child: const Text('armed cancel'),
    )))));
    await tester.tap(find.text('armed cancel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4821');
    await tester.tap(find.text('reset_pin_verify_confirm'));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
    storage.store.clear();
  });

  testWidgets('a configured PIN is demanded before the data leaves', (
    tester,
  ) async {
    final storage = _FakeSecureStorage();
    await storage.write(key: SecureStorageKeys.userPin, value: '4821');
    final service = PinVerificationService.forTesting(secureStorage: storage);

    final allowed = await _runGate(tester, service);

    expect(
      allowed,
      isNull,
      reason: 'the gate is still waiting on the modal, not resolved',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('no configured PIN does not block access to your own data', (
    tester,
  ) async {
    final service = PinVerificationService.forTesting(
      secureStorage: _FakeSecureStorage(),
    );

    final allowed = await _runGate(tester, service);

    expect(allowed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('an unreadable PIN store is treated as locked, not absent', (
    tester,
  ) async {
    final service = PinVerificationService.forTesting(
      secureStorage: _FakeSecureStorage(throwOnRead: true),
    );

    final allowed = await _runGate(tester, service);

    expect(
      allowed,
      isFalse,
      reason:
          'A provoked storage fault must not downgrade a real lock into no '
          'lock at all.',
    );
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
