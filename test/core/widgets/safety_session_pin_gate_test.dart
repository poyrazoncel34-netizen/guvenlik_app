import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/core/widgets/safety_session_pin_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MapAssetLoader extends AssetLoader {
  const _MapAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      <String, dynamic>{
        'reset_pin_verify_title': 'PIN Doğrulaması',
        'reset_pin_verify_hint': 'PIN girin',
        'reset_pin_verify_confirm': 'Doğrula',
        'settings_cancel': 'İptal',
        'settings_pin_wrong': 'Yanlış PIN',
      };
}

class _FakeSecureStorage extends SecureStorage {
  _FakeSecureStorage(this.pin);

  final String pin;

  @override
  Future<String?> read({required String key}) async =>
      key == SecureStorageKeys.userPin ? pin : null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {}
}

class _ThrowingSecureStorage extends _FakeSecureStorage {
  _ThrowingSecureStorage() : super('');

  @override
  Future<String?> read({required String key}) =>
      Future<String?>.error(StateError('secure storage unavailable'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('wrong PIN cannot authorize but correct PIN can', (tester) async {
    final service = PinVerificationService.forTesting(
      secureStorage: _FakeSecureStorage('4826'),
    );
    var authorized = 0;

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const <Locale>[Locale('tr', 'TR')],
        path: 'unused',
        assetLoader: const _MapAssetLoader(),
        fallbackLocale: const Locale('tr', 'TR'),
        startLocale: const Locale('tr', 'TR'),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    if (await SafetySessionPinGate.verify(
                      context,
                      verificationService: service,
                    )) {
                      authorized += 1;
                    }
                  },
                  child: const Text('session action'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('session action'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1111');
    await tester.tap(find.text('Doğrula'));
    await tester.pumpAndSettle();

    expect(authorized, 0);
    expect(find.text('Yanlış PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '4826');
    await tester.tap(find.text('Doğrula'));
    await tester.pumpAndSettle();

    expect(authorized, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('secure-storage read failure never opens a PIN dialog', (
    tester,
  ) async {
    final service = PinVerificationService.forTesting(
      secureStorage: _ThrowingSecureStorage(),
      operationTimeout: const Duration(milliseconds: 20),
    );
    var authorized = 0;

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const <Locale>[Locale('tr', 'TR')],
        path: 'unused',
        assetLoader: const _MapAssetLoader(),
        fallbackLocale: const Locale('tr', 'TR'),
        startLocale: const Locale('tr', 'TR'),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    if (await SafetySessionPinGate.verify(
                      context,
                      verificationService: service,
                    )) {
                      authorized += 1;
                    }
                  },
                  child: const Text('session action'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('session action'));
    await tester.pumpAndSettle();

    expect(authorized, 0);
    expect(service.state, PinState.readFailed);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
