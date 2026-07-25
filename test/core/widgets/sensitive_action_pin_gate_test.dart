import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/core/widgets/sensitive_action_pin_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage extends SecureStorage {
  _FakeSecureStorage({this.throwOnRead = false});

  final Map<String, String> store = <String, String>{};
  final bool throwOnRead;

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    if (throwOnRead) throw Exception('keystore unavailable');
    return store[key];
  }

  @override
  Future<void> delete({required String key}) async => store.remove(key);

  @override
  Future<void> deleteAll() async => store.clear();
}

Future<bool?> _runGate(
  WidgetTester tester,
  PinVerificationService service,
) async {
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
