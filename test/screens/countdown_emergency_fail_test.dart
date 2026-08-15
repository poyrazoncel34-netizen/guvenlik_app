// CountdownScreen fail-safe kaynak kontrati: arama akisi basarisiz oldugunda
// bloklayici "elle ara" diyalogu gosterilmeli; sessiz SnackBar + Navigator.pop
// ASLA. Bu dosya, F1 denetimi kapsaminda sabit-bool karsilastiran totolojik
// halinden gercek kaynak kontratina cevrildi.
//
// FIR-01 ile genisletildi: diyalogun GOSTERILMESI yetmez -- gosterilen iddia
// dispatch defterine uymak zorunda. Bu dosya kablolamayi (uretim dalinin
// deftere gercekten eristigini) korur; iddianin dogrulugunu
// test/core/services/emergency_result_policy_test.dart, ekranda ne gorundugunu
// test/screens/emergency_failure_surface_test.dart olcer.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Directory.current.path.endsWith('test')
      ? Directory.current.parent.path
      : Directory.current.path;

  late String source;
  late String executeBody;
  late String makeCallBody;
  late String checkInSource;

  setUpAll(() {
    source = File('$base/lib/screens/countdown_screen.dart').readAsStringSync();
    checkInSource =
        File('$base/lib/core/services/check_in_service.dart').readAsStringSync();
    final makeStart = source.indexOf('Future<void> _makeEmergencyCall()');
    final execStart = source.indexOf('Future<void> _executeEmergency()');
    final execEnd = source.indexOf('  @override\n  void dispose() {');
    expect(makeStart, isNot(-1), reason: '_makeEmergencyCall must exist');
    expect(execStart, isNot(-1), reason: '_executeEmergency must exist');
    expect(execEnd, isNot(-1), reason: 'dispose must follow _executeEmergency');
    makeCallBody = source.substring(makeStart, execStart);
    executeBody = source.substring(execStart, execEnd);
  });

  group('CountdownScreen - acil cagri basarisiz durumu', () {
    test('fail dali bloklayici fail-safe diyalogunu cagirir', () {
      final failedIdx = executeBody.indexOf(
        'EmergencyResultSurface.blockingFailure',
      );
      expect(
        failedIdx,
        isNot(-1),
        reason: '_executeEmergency must branch on the blocking-failure surface',
      );
      final failSafeIdx = executeBody.indexOf(
        'EmergencyFailureDialog.show',
        failedIdx,
      );
      final branchEnd = executeBody.indexOf('return;', failedIdx);
      expect(failSafeIdx, isNot(-1));
      expect(branchEnd, isNot(-1));
      expect(
        failSafeIdx < branchEnd,
        isTrue,
        reason:
            'fail dali return etmeden ONCE bloklayici diyalogu '
            'gostermeli - sessiz cikis yasak',
      );
    });

    test('fail dalinda sessiz Navigator.pop yok', () {
      final failedIdx = executeBody.indexOf(
        'EmergencyResultSurface.blockingFailure',
      );
      final branchEnd = executeBody.indexOf('return;', failedIdx);
      final branch = executeBody.substring(failedIdx, branchEnd);
      expect(
        branch.contains('Navigator.pop'),
        isFalse,
        reason:
            'Basarisizlikta kullanici "uygulama kapandi" sanmamali; '
            'pop yerine bloklayici diyalog gosterilir',
      );
    });

    test('catch-all fail-safe: dispatch cokse bile diyalog gosterilir', () {
      final catchIdx = makeCallBody.indexOf('catch (');
      expect(
        catchIdx,
        isNot(-1),
        reason: '_makeEmergencyCall must have a catch-all guard',
      );
      final failSafeIdx = makeCallBody.indexOf(
        'EmergencyFailureDialog.show',
        catchIdx,
      );
      expect(
        failSafeIdx,
        isNot(-1),
        reason: 'Beklenmeyen exception da bloklayici fail-safe ile bitmeli',
      );
      expect(
        makeCallBody.contains(
          r"debugPrint('CountdownScreen: Emergency execution crashed: $e')",
        ),
        isFalse,
        reason: 'Raw exception details must not reach local debug output.',
      );
    });
  });

  group('FIR-01 - gosterilen iddia deftere baglidir', () {
    test('the failure branch is decided from the ledger, not the call result '
        'alone', () {
      final decideIdx = executeBody.indexOf('EmergencyResultPolicy.decide(');
      expect(decideIdx, isNot(-1),
          reason: 'the surface must come from the shared policy');
      final window = executeBody.substring(decideIdx, decideIdx + 200);
      expect(window, contains('callResult: callResult'));
      expect(window, contains('ledger: ledger'),
          reason: 'the decision must SEE the ledger; passing only the call '
              'result is the FIR-01 defect');
    });

    test('no failure surface in this screen hard-codes the absolute claim', () {
      // The four failure sites now name a reason and let the policy choose the
      // copy. A literal total-failure key here would bypass the invariant.
      expect(
        source.contains("'emergency_total_failure_title'"),
        isFalse,
        reason: 'the absolute title must be chosen by EmergencyResultPolicy, '
            'never typed into a call site',
      );
      expect(
        source.contains("'emergency_total_failure_body'"),
        isFalse,
        reason: 'the absolute body must be chosen by EmergencyResultPolicy',
      );
    });

    test('every EmergencyFailureDialog call site names a reason', () {
      final sites = 'EmergencyFailureDialog.show('.allMatches(source).length;
      final reasons = 'EmergencyFailureReason.'.allMatches(source).length +
          'decision.failureCopy'.allMatches(source).length;
      expect(sites, greaterThanOrEqualTo(4),
          reason: 'the four failure paths: arm rejection, dispatch throw, '
              'failed call, unavailable result screen');
      expect(reasons, greaterThanOrEqualTo(sites),
          reason: 'each site supplies a policy-derived copy');
    });

    test('the ledger reaches a user-facing surface on BOTH dispatch paths', () {
      // Panic: the failure surface carries the copy (which carries the ledger);
      // the success surface carries the ledger directly.
      expect(executeBody, contains('dispatchLedger: ledger'));
      expect(executeBody, contains('ledger: ledger'));
      // Check-In escalation: unconditional handover, unchanged.
      expect(checkInSource, contains('dispatchLedger: ledger'),
          reason: 'the two paths DispatchLedgerRecorder exists to keep '
              'identical must both hand the ledger to the user');
    });

    test('the extracted dialog replaced the private one, not duplicated it',
        () {
      expect(source.contains('_showBlockingFailure'), isFalse,
          reason: 'one blocking-failure surface, in one place');
    });
  });
}
