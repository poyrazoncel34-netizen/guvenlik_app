// MP-01-027 / FIR-01 -- what the panic path's blocking failure surface actually
// RENDERS, with the real Turkish catalogue.
//
// The policy test proves the decision; this proves the pixels agree with it.
// Together they cover the branch that had neither: the failure branch returned
// before any renderer, so the ledger never reached a screen.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/call_service.dart';
import 'package:guvenlik_app/core/services/dispatch_ledger_recorder.dart';
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/core/services/emergency_result_policy.dart';
import 'package:guvenlik_app/core/widgets/emergency_failure_dialog.dart';
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

  Future<void> pumpDialog(
    WidgetTester tester,
    EmergencyFailureCopy copy,
  ) async {
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
            localizationsDelegates: EasyLocalization.of(context)!.delegates,
            home: Builder(
              builder: (inner) => ElevatedButton(
                onPressed: () => EmergencyFailureDialog.show(
                  inner,
                  copy: copy,
                  phoneNumber: '+905001234567',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    // EasyLocalization resolves its catalogue asynchronously; the host button
    // does not exist until that settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<String> renderedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  /// The ledger the panic path builds when the phone handoff fails but the
  /// bookkeeping targets run: 4 reached, 2 not reached.
  DispatchOutcomeLedger failedCallPartialLedger() {
    final ledger = DispatchOutcomeLedger(dispatchId: 'render');
    DispatchLedgerRecorder.recordCallTargets(
      ledger,
      EmergencyCallResult.failed('+905001234567'),
    );
    for (final target in const [
      DispatchTarget.offlineQueue,
      DispatchTarget.safetyTimeline,
      DispatchTarget.haptic,
      DispatchTarget.alertNotification,
    ]) {
      ledger.recordOutcome(target, DispatchTargetOutcome.handoffAccepted);
    }
    return ledger;
  }

  testWidgets('B/C: a failed call with reached targets never renders the '
      'absolute "nothing completed" sentence', (tester) async {
    final catalogue = _catalogue();
    final ledger = failedCallPartialLedger();
    expect(ledger.reachedCount, 4);

    final copy = EmergencyResultPolicy.decide(
      callResult: EmergencyCallResult.failed('+905001234567'),
      ledger: ledger,
    ).failureCopy;
    await pumpDialog(tester, copy!);

    final texts = renderedText(tester);
    expect(
      texts,
      isNot(contains(catalogue['emergency_total_failure_title'])),
      reason: 'the ledger records four reached targets; "Hicbir islem '
          'tamamlanmadi" is a false statement about this dispatch',
    );
    expect(texts, isNot(contains(catalogue['emergency_total_failure_body'])));
    expect(texts, contains(catalogue['emergency_partial_failure_title']));
    expect(texts, contains(catalogue['emergency_partial_failure_body']));
  });

  testWidgets('B/C: reached and not-reached targets stay distinguishable ON '
      'the failure surface', (tester) async {
    final catalogue = _catalogue();
    final copy = EmergencyResultPolicy.decide(
      callResult: EmergencyCallResult.failed('+905001234567'),
      ledger: failedCallPartialLedger(),
    ).failureCopy;
    await pumpDialog(tester, copy!);

    final texts = renderedText(tester);
    // The section, the reached targets, and the failed call, all on screen.
    expect(texts, contains(catalogue['emergency_per_target_title']));
    expect(texts, contains(catalogue['emergency_per_target_partial_body']));
    expect(texts, contains(catalogue['dispatch_target_primary_call']));
    expect(texts, contains(catalogue['dispatch_target_dialer']));
    expect(texts, contains(catalogue['dispatch_target_queue']));
    expect(texts, contains(catalogue['dispatch_target_timeline']));
    expect(texts, contains(catalogue['dispatch_outcome_handed_off']));
    expect(texts, contains(catalogue['dispatch_outcome_rejected']));
    expect(texts, contains(catalogue['dispatch_outcome_no_handler']));

    // A screen-reader user hears each target with its own fate.
    expect(
      find.bySemanticsLabel('${catalogue['dispatch_target_queue']}: '
          '${catalogue['dispatch_outcome_handed_off']}'),
      findsOneWidget,
    );
  });

  testWidgets('A: a genuine total failure still gets the absolute copy',
      (tester) async {
    final catalogue = _catalogue();
    final ledger = DispatchOutcomeLedger(dispatchId: 'total');
    DispatchLedgerRecorder.recordCallTargets(
      ledger,
      EmergencyCallResult.failed('+905001234567'),
    );
    ledger.recordOutcome(DispatchTarget.alertNotification,
        DispatchTargetOutcome.permissionDenied);
    expect(ledger.reachedCount, 0);

    final copy = EmergencyResultPolicy.decide(
      callResult: EmergencyCallResult.failed('+905001234567'),
      ledger: ledger,
    ).failureCopy;
    await pumpDialog(tester, copy!);

    final texts = renderedText(tester);
    expect(texts, contains(catalogue['emergency_total_failure_title']));
    expect(texts, contains(catalogue['emergency_total_failure_body']));
    // Even here the per-target account is shown: "nothing completed" is the
    // headline, and the list says which targets refused and why.
    expect(texts, contains(catalogue['dispatch_target_notification']));
    expect(texts, contains(catalogue['dispatch_outcome_permission_denied']));
  });

  /// RER-05, rendered. The policy test proves the decision; this proves the
  /// user is not shown "Hicbir islem tamamlanmadi" over a list that says
  /// "belirsiz" next to every row.
  testWidgets('unknown-only ledger never renders the absolute claim',
      (tester) async {
    final catalogue = _catalogue();
    final ledger = DispatchOutcomeLedger(dispatchId: 'unknown-only');
    DispatchLedgerRecorder.recordCallTargets(
      ledger,
      EmergencyCallResult.failed('+905001234567'),
    );
    // Every bookkeeping target came back unconfirmed: the app does not know
    // that they failed, and must not say that they did.
    for (final target in const <DispatchTarget>[
      DispatchTarget.alertNotification,
      DispatchTarget.safetyTimeline,
      DispatchTarget.offlineQueue,
      DispatchTarget.haptic,
    ]) {
      ledger.recordOutcome(target, DispatchTargetOutcome.handoffUnconfirmed);
    }
    expect(ledger.reachedCount, 0);
    expect(ledger.unknownCount, 4);

    final copy = EmergencyResultPolicy.decide(
      callResult: EmergencyCallResult.failed('+905001234567'),
      ledger: ledger,
    ).failureCopy;
    await pumpDialog(tester, copy!);

    final texts = renderedText(tester);
    expect(
      texts,
      isNot(contains(catalogue['emergency_total_failure_title'])),
      reason: 'four targets may well have succeeded; "Hicbir islem '
          'tamamlanmadi" is a claim this app cannot support',
    );
    expect(
      texts,
      isNot(contains(catalogue['emergency_partial_failure_title'])),
      reason: 'and nothing is KNOWN to have completed either, so "bazi '
          'adimlar tamamlandi" would be the opposite lie',
    );
    expect(
      texts,
      contains(catalogue['emergency_unconfirmed_failure_title']),
      reason: 'the honest third claim',
    );
    // The headline and the list must agree: the rows say "belirsiz".
    expect(texts, contains(catalogue['dispatch_outcome_unconfirmed']));
    // The user still gets the thing that actually helps.
    expect(find.text('+905001234567'), findsOneWidget);
    expect(find.text(catalogue['emergency_manual_call_now']!), findsOneWidget);
  });

  /// The complement: with nothing unknown, the absolute claim is still allowed,
  /// so RER-05 narrowed the claim rather than abolishing it.
  testWidgets('definite-failure-only ledger still renders the absolute claim',
      (tester) async {
    final catalogue = _catalogue();
    final ledger = DispatchOutcomeLedger(dispatchId: 'definite-only');
    DispatchLedgerRecorder.recordCallTargets(
      ledger,
      EmergencyCallResult.failed('+905001234567'),
    );
    ledger.recordOutcome(DispatchTarget.alertNotification,
        DispatchTargetOutcome.permissionDenied);
    ledger.recordOutcome(DispatchTarget.safetyTimeline,
        DispatchTargetOutcome.platformRejected);
    expect(ledger.reachedCount, 0);
    expect(ledger.unknownCount, 0);

    final copy = EmergencyResultPolicy.decide(
      callResult: EmergencyCallResult.failed('+905001234567'),
      ledger: ledger,
    ).failureCopy;
    await pumpDialog(tester, copy!);

    expect(
      renderedText(tester),
      contains(catalogue['emergency_total_failure_title']),
      reason: 'nothing reached and nothing unknown: the absolute claim is TRUE',
    );
  });

  testWidgets('the manual-call affordance survives the change', (tester) async {
    final catalogue = _catalogue();
    final copy = EmergencyResultPolicy.decide(
      callResult: EmergencyCallResult.failed('+905001234567'),
      ledger: failedCallPartialLedger(),
    ).failureCopy;
    await pumpDialog(tester, copy!);

    expect(find.text('+905001234567'), findsOneWidget);
    expect(find.text(catalogue['emergency_manual_call_now']!), findsOneWidget);
  });

  testWidgets('no raw localization key reaches the failure surface',
      (tester) async {
    final copy = EmergencyResultPolicy.decide(
      callResult: EmergencyCallResult.failed('+905001234567'),
      ledger: failedCallPartialLedger(),
    ).failureCopy;
    await pumpDialog(tester, copy!);

    final leaked = renderedText(tester)
        .where((d) => RegExp(r'^[a-z0-9]+(_[a-z0-9]+){2,}$').hasMatch(d))
        .toList();
    expect(leaked, isEmpty, reason: 'raw keys rendered: $leaked');
  });

  testWidgets('arm rejection: no ledger, specific reason, absolute claim is '
      'honest', (tester) async {
    final catalogue = _catalogue();
    final copy = EmergencyResultPolicy.failureCopy(
      reason: EmergencyFailureReason.armRejected,
      bodyKeyOverride: 'emergency_total_failure_body',
    );
    await pumpDialog(tester, copy);

    final texts = renderedText(tester);
    expect(texts, contains(catalogue['emergency_total_failure_title']));
    expect(texts, isNot(contains(catalogue['emergency_per_target_title'])),
        reason: 'nothing was attempted, so there is no per-target account');
  });
}
