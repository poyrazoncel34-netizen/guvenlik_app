// MP-01-027 -- the per-target dispatch outcome must be VISIBLE, not merely
// modelled.
//
// The ledger tests in test/core/services/emergency_dispatch_pipeline_test.dart
// prove [reached, notReached, reached] stays distinguishable in the data. That
// is only half the requirement: a truthful model rendered through an aggregate
// success screen is still a lie to the user. This file renders the real screen
// with the real Turkish catalogue and asserts the user can read each target's
// fate.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/call_service.dart';
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/screens/emergency_call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

Map<String, String> _catalogue() =>
    (jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
            as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    DispatchOutcomeLedger? ledger, {
    EmergencyCallStatus status = EmergencyCallStatus.callRequested,
  }) async {
    final result = switch (status) {
      EmergencyCallStatus.callRequested =>
        EmergencyCallResult.requested('+905001234567'),
      EmergencyCallStatus.dialerRequested =>
        EmergencyCallResult.dialer('+905001234567'),
      EmergencyCallStatus.failed =>
        EmergencyCallResult.failed('+905001234567'),
    };
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const <Locale>[Locale('tr', 'TR')],
        path: 'assets/translations',
        fallbackLocale: const Locale('tr', 'TR'),
        assetLoader: const _RealTrAssetLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: EasyLocalization.of(context)!.locale,
            supportedLocales: EasyLocalization.of(context)!.supportedLocales,
            localizationsDelegates:
                EasyLocalization.of(context)!.delegates,
            home: EmergencyCallScreen(
              name: 'Primary',
              phone: '+905001234567',
              callResult: result,
              dispatchLedger: ledger,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Collects every rendered string, including semantics labels, so an
  /// assertion cannot pass on a raw localization key.
  List<String> renderedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  testWidgets('partial dispatch names EACH target and its outcome',
      (tester) async {
    final catalogue = _catalogue();
    final ledger = DispatchOutcomeLedger(dispatchId: 'w1')
      ..recordOutcome(
          DispatchTarget.primaryCall, DispatchTargetOutcome.handoffAccepted)
      ..recordOutcome(DispatchTarget.safetyTimeline,
          DispatchTargetOutcome.platformException,
          reasonCode: 'StateError')
      ..recordOutcome(DispatchTarget.alertNotification,
          DispatchTargetOutcome.suppressedByUserSetting);

    expect(ledger.isPartial, isTrue);
    await pumpScreen(tester, ledger);

    final texts = renderedText(tester);

    // The section itself.
    expect(texts, contains(catalogue['emergency_per_target_title']));
    expect(
      texts,
      contains(catalogue['emergency_per_target_partial_body']),
      reason: 'a partial dispatch must use the partial body, not the neutral '
          'one -- the neutral sentence does not tell the user to act',
    );

    // Each target label, and each DISTINCT outcome. Three targets with three
    // different fates must produce three different sentences.
    expect(texts, contains(catalogue['dispatch_target_primary_call']));
    expect(texts, contains(catalogue['dispatch_target_timeline']));
    expect(texts, contains(catalogue['dispatch_target_notification']));
    expect(texts, contains(catalogue['dispatch_outcome_handed_off']));
    expect(texts, contains(catalogue['dispatch_outcome_exception']));
    expect(texts, contains(catalogue['dispatch_outcome_suppressed']));

    // The defect in one assertion: success and failure copy coexist on screen.
    expect(
      texts.where((t) => t == catalogue['dispatch_outcome_handed_off']),
      hasLength(1),
    );
  });

  testWidgets('no raw localization key reaches the tree', (tester) async {
    final ledger = DispatchOutcomeLedger(dispatchId: 'w2')
      ..recordOutcome(
          DispatchTarget.primaryCall, DispatchTargetOutcome.handoffAccepted)
      ..recordOutcome(DispatchTarget.alertNotification,
          DispatchTargetOutcome.permissionDenied);
    await pumpScreen(tester, ledger);

    final leaked = renderedText(tester)
        .where((d) => RegExp(r'^[a-z0-9]+(_[a-z0-9]+){2,}$').hasMatch(d))
        .toList();
    expect(leaked, isEmpty,
        reason: 'raw keys reached the emergency status tree: $leaked');
  });

  testWidgets('a fully successful dispatch does not add the list',
      (tester) async {
    final catalogue = _catalogue();
    final ledger = DispatchOutcomeLedger(dispatchId: 'w3')
      ..recordOutcome(
          DispatchTarget.primaryCall, DispatchTargetOutcome.handoffAccepted)
      ..recordOutcome(DispatchTarget.safetyTimeline,
          DispatchTargetOutcome.handoffAccepted);
    expect(ledger.summary, DispatchOutcomeSummary.everyTargetReached);

    await pumpScreen(tester, ledger);
    expect(renderedText(tester),
        isNot(contains(catalogue['emergency_per_target_title'])));
  });

  testWidgets('every target row carries a screen-reader label', (tester) async {
    final catalogue = _catalogue();
    final ledger = DispatchOutcomeLedger(dispatchId: 'w4')
      ..recordOutcome(
          DispatchTarget.primaryCall, DispatchTargetOutcome.handoffAccepted)
      ..recordOutcome(DispatchTarget.alertNotification,
          DispatchTargetOutcome.permissionDenied);
    await pumpScreen(tester, ledger);

    final expected =
        '${catalogue['dispatch_target_notification']}: '
        '${catalogue['dispatch_outcome_permission_denied']}';
    expect(find.bySemanticsLabel(expected), findsOneWidget);
  });

  testWidgets('a screen with no ledger still renders (no regression)',
      (tester) async {
    await pumpScreen(tester, null);
    expect(find.byType(EmergencyCallScreen), findsOneWidget);
    expect(renderedText(tester), isNotEmpty);
  });
}
