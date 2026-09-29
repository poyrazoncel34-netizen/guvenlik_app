import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/pin_hasher.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/screens/pin_setup_screen.dart';
import 'package:guvenlik_app/screens/settings_legal/legal_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

class _PinStore extends SecureStorage {
  _PinStore({this.failWrites = false});
  final bool failWrites;
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites && key == SecureStorageKeys.userPin) {
      throw StateError('keystore unavailable');
    }
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

class _Launcher extends StatefulWidget {
  const _Launcher();

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  bool? result;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const PinSetupScreen()),
            );
            if (mounted) setState(() {});
          },
          child: const Text('PIN kur'),
        ),
        Text('sonuc=$result'),
      ],
    ),
  );
}

Future<_PinStore> _pump(WidgetTester tester, {bool failWrites = false}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await serviceLocator.reset();
  final store = _PinStore(failWrites: failWrites);
  serviceLocator.registerSingleton<SecureStorage>(store);
  await pumpLocalized(tester, const _Launcher());
  await tester.tap(find.text('PIN kur'));
  await tester.pumpAndSettle();
  expect(find.byType(PinSetupScreen), findsOneWidget);
  return store;
}

Future<void> _enter(WidgetTester tester, String value) async {
  for (final digit in value.split('')) {
    final key = find.text(digit).last;
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });
  tearDown(() async => serviceLocator.reset());

  testWidgets('PIN-05 mismatch resets the real two-step entry flow', (
    tester,
  ) async {
    await _pump(tester);
    await _enter(tester, '4821');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text("PIN'i Tekrar Girin"), findsOneWidget);

    await _enter(tester, '4822');
    await tester.pump();

    expect(find.text("PIN'ler uyuşmuyor. Tekrar deneyin."), findsOneWidget);
    expect(find.text("Güvenlik PIN'i Belirleyin"), findsOneWidget);
  });

  testWidgets('PIN-06 matching PIN persists a hash and returns success', (
    tester,
  ) async {
    final store = await _pump(tester);
    await _enter(tester, '4821');
    await tester.pump(const Duration(milliseconds: 250));
    await _enter(tester, '4821');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final stored = store.values[SecureStorageKeys.userPin];
    expect(stored, isNotNull);
    expect(stored, isNot('4821'));
    expect(PinHasher.matches(stored: stored!, candidate: '4821'), isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        AppConstants.prefPinSetupDone,
      ),
      isTrue,
    );
    expect(find.text('sonuc=true'), findsOneWidget);
  });

  testWidgets('PIN-07 storage failure stays open and reports failure', (
    tester,
  ) async {
    await _pump(tester, failWrites: true);
    await _enter(tester, '4821');
    await tester.pump(const Duration(milliseconds: 250));
    await _enter(tester, '4821');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.byType(PinSetupScreen), findsOneWidget);
    expect(
      find.text(
        'PIN kaydedilemedi. Cihaz depolaması yanıt vermedi; '
        'lütfen tekrar deneyin.',
      ),
      findsOneWidget,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool(
        AppConstants.prefPinSetupDone,
      ),
      isNull,
    );
  });

  testWidgets('PIN-09 info action opens production legal settings', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.byType(LegalSettingsScreen), findsOneWidget);
  });
}
