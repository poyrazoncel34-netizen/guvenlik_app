import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/models/consent_record.dart';
import 'package:guvenlik_app/screens/legal/consent_management_screen.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_guidelines_test.dart' show pumpLocalized;

class _ControlledConsentManager extends ConsentManager {
  _ControlledConsentManager({bool locationGranted = false})
    : _status = <String, bool>{ConsentRecord.typeLocation: locationGranted};

  final Map<String, bool> _status;
  int grantCalls = 0;
  int revokeCalls = 0;
  bool failGrant = false;
  Completer<void>? grantGate;

  @override
  Map<String, bool> getAllConsentStatus() => Map.unmodifiable(_status);

  @override
  Future<void> grantConsent(String consentType, {String? locale}) async {
    grantCalls++;
    final gate = grantGate;
    if (gate != null) await gate.future;
    if (failGrant) {
      throw const ConsentStorageException('injected write rejection');
    }
    _status[consentType] = true;
  }

  @override
  Future<void> revokeConsent(String consentType, {String? locale}) async {
    revokeCalls++;
    _status[consentType] = false;
  }
}

Future<void> _pumpConsentScreen(
  WidgetTester tester,
  _ControlledConsentManager manager,
) async {
  await serviceLocator.reset();
  serviceLocator.registerSingleton<ConsentManager>(manager);
  await pumpLocalized(tester, const ConsentManagementScreen());
  await tester.pumpAndSettle();
}

Switch _locationSwitch(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch).first);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  tearDown(() => serviceLocator.reset());

  testWidgets(
    'YSL-06: tapping a real production switch grants and persists consent preference',
    (tester) async {
      final manager = _ControlledConsentManager();
      await _pumpConsentScreen(tester, manager);

      expect(_locationSwitch(tester).value, isFalse);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(manager.grantCalls, 1);
      expect(_locationSwitch(tester).value, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.prefConsentLocation), isTrue);
    },
  );

  testWidgets('YSL-07: revoke cancel keeps consent and performs no write', (
    tester,
  ) async {
    final manager = _ControlledConsentManager(locationGranted: true);
    await _pumpConsentScreen(tester, manager);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Rızayı Geri Çek'), findsOneWidget);

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

    expect(manager.revokeCalls, 0);
    expect(_locationSwitch(tester).value, isTrue);
  });

  testWidgets('YSL-06/YSL-07: confirmed revoke updates state and preference', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.prefConsentLocation: true,
    });
    final manager = _ControlledConsentManager(locationGranted: true);
    await _pumpConsentScreen(tester, manager);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geri Çek'));
    await tester.pumpAndSettle();

    expect(manager.revokeCalls, 1);
    expect(_locationSwitch(tester).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConstants.prefConsentLocation), isFalse);
  });

  testWidgets(
    'YSL-06: storage rejection restores state and shows retryable error',
    (tester) async {
      final manager = _ControlledConsentManager()..failGrant = true;
      await _pumpConsentScreen(tester, manager);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(manager.grantCalls, 1);
      expect(_locationSwitch(tester).value, isFalse);
      expect(
        find.text(
          'Rıza değişikliği kaydedilemedi. Cihaz güvenli depolaması yanıt '
          'vermedi; lütfen tekrar deneyin.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('YSL-06: an in-flight write blocks rapid duplicate taps', (
    tester,
  ) async {
    final gate = Completer<void>();
    final manager = _ControlledConsentManager()..grantGate = gate;
    await _pumpConsentScreen(tester, manager);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(manager.grantCalls, 1);
    expect(_locationSwitch(tester).onChanged, isNull);

    await tester.tap(find.byType(Switch).first, warnIfMissed: false);
    await tester.pump();
    expect(manager.grantCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(_locationSwitch(tester).value, isTrue);
  });
}
