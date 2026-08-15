// MP-11-014 / MP-23-010 / MP-26-006 -- FIR-02.
//
// `showEmergencyAlert` returns a typed outcome so that "the user switched this
// off" can never read as "Android displayed it". Two live call sites threw that
// outcome away: the Check-In grace warning awaited it inside
// `catch (_) { // Notification not critical }`, and the Safe Walk pre-expiry
// warning neither awaited nor captured it. The verifier property vouching for
// the fix was `"suppressedByUserSetting" in service` -- a substring test over
// one file, structurally unable to see a dropped return value.
//
// This file measures BEHAVIOUR: with notifications switched off, the running
// service must end up knowing that the grace warning never reached the user.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/app_settings_service.dart';
import 'package:guvenlik_app/core/services/check_in_expiry_coordinator.dart';
import 'package:guvenlik_app/core/services/check_in_service.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/notification_service.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Contacts implements ContactsRepository {
  _Contacts([this.primary]);

  EmergencyContact? primary;

  @override
  Future<void> clearPrimaryEmergencyContact() async => primary = null;

  @override
  Future<List<String>> getAllEmergencyNumbers() async =>
      primary == null ? const <String>[] : <String>[primary!.phone];

  @override
  Future<List<EmergencyContact>> getContactRecords() async => primary == null
      ? const <EmergencyContact>[]
      : <EmergencyContact>[primary!];

  @override
  Future<List<String>> getContacts() => getAllEmergencyNumbers();

  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async => primary;

  @override
  Future<void> saveContactRecords(List<EmergencyContact> contacts) async {
    primary = contacts.isEmpty ? null : contacts.first;
  }

  @override
  Future<void> saveContacts(List<String> numbers) async {
    primary = numbers.isEmpty
        ? null
        : EmergencyContact(name: 'Kisi', phone: numbers.first, isPrimary: true);
  }

  @override
  Future<void> saveEmergencyNumbers(List<String> numbers) =>
      saveContacts(numbers);

  @override
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {
    primary = EmergencyContact(name: name, phone: phone, isPrimary: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('safety_alert_outcome_test');
  // The notifications plugin's own channel. Mocked so that "the OS accepted
  // the post" is reachable in a host test; without it every post fails with
  // MissingPluginException and the reached branch could never be exercised.
  const notificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  late _Contacts contacts;
  late EmergencyPlatformService platform;
  CheckInService? service;

  Map<String, Object?> armedResponse(MethodCall call) {
    final arguments = call.arguments as Map<Object?, Object?>;
    return <String, Object?>{
      'type': 'armed',
      'token': <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'randomId': arguments['randomId'],
        'generation': arguments['requestedGeneration'],
        'kind': arguments['kind'],
      },
      'mainDeadlineMs': arguments['mainDeadlineMs'],
      'finalDeadlineMs': arguments['finalDeadlineMs'],
    };
  }

  /// Arms a real session, then drives it into the grace window through the
  /// production entry point the native side uses.
  Future<CheckInService> enterGrace({required bool notificationsEnabled}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pref_notifications': notificationsEnabled,
    });
    contacts = _Contacts(
      const EmergencyContact(
        name: 'Birincil',
        phone: '+90 555 111 22 33',
        isPrimary: true,
      ),
    );
    platform = EmergencyPlatformService.forTesting(
      methodChannel: channel,
      defaultTimeout: const Duration(milliseconds: 20),
      dispatchTimeout: const Duration(milliseconds: 20),
    );
    final created = CheckInService.forTesting(
      sessionId: CheckInExpiryCoordinator.checkInSession,
      platform: platform,
      contactsRepository: contacts,
      sideEffectsEnabled: true,
    );
    service = created;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'armEmergencySession') return armedResponse(call);
      if (call.method == 'readEmergencySession') {
        final token = created.sessionToken!;
        return <String, Object?>{
          'type': 'present',
          'session': <String, Object?>{
            'token': token.toMap(),
            'lifecycleState': 'armed',
            // Main deadline already passed, final deadline still ahead: the
            // definition of "inside the grace window".
            'mainDeadlineMs': DateTime.now()
                .subtract(const Duration(seconds: 5))
                .millisecondsSinceEpoch,
            'finalDeadlineMs': DateTime.now()
                .add(const Duration(seconds: 55))
                .millisecondsSinceEpoch,
            'target': '+905551112233',
            'callRequestOutcome': 'notAttempted',
            'fallbackOutcome': 'notAttempted',
          },
        };
      }
      return null;
    });

    final armed = await created.startSession(
      minutes: 5,
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
    );
    expect(armed, isA<Armed>());
    expect(created.graceAlertOutcome, isNull,
        reason: 'no grace warning has been attempted yet');

    await created.handleNativeGraceStarted();
    expect(created.isGracePeriod, isTrue,
        reason: 'the harness must actually reach the grace window, otherwise '
            'this test proves nothing');
    return created;
  }

  tearDown(() async {
    service?.dispose();
    service = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  group('the posting API reports what happened', () {
    test('an alert the user switched off is suppressedByUserSetting', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pref_notifications': false,
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationsChannel, (call) async => null);
      expect(await AppSettingsService.notificationsEnabled(), isFalse);

      final outcome = await NotificationService.instance.showEmergencyAlert(
        id: 1,
        title: 'title',
        body: 'body',
      );
      expect(outcome, DispatchTargetOutcome.suppressedByUserSetting);
      expect(outcome.reachability, DispatchReachability.notReached,
          reason: 'a suppressed safety alert definitively did not reach');
    });
  });

  group('the Check-In grace warning', () {
    test('a suppressed grace warning is RECORDED, not dropped', () async {
      final running = await enterGrace(notificationsEnabled: false);

      expect(running.graceAlertOutcome,
          DispatchTargetOutcome.suppressedByUserSetting,
          reason: 'the grace warning is the last cue before a call; a service '
              'that cannot tell it never appeared cannot tell the user');
      expect(running.graceAlertOutcome!.reachability,
          DispatchReachability.notReached);
    });

    test('with notifications ON the recorded outcome reflects the PLATFORM, '
        'not the setting', () async {
      final running = await enterGrace(notificationsEnabled: true);

      expect(running.graceAlertOutcome, isNotNull,
          reason: 'an attempted warning always leaves a record');
      expect(running.graceAlertOutcome,
          isNot(DispatchTargetOutcome.suppressedByUserSetting),
          reason: 'the user did not switch it off, so that cannot be the '
              'recorded reason');
      // On a host VM there is no notification manager, so the honest outcome
      // here is a platform failure -- which is itself the point: the recorded
      // value tracks what really happened rather than what was requested.
      expect(running.graceAlertOutcome!.reachability,
          isNot(DispatchReachability.inapplicable));
    });

    test('the two outcomes are DISTINGUISHABLE -- the whole point', () async {
      final off = await enterGrace(notificationsEnabled: false);
      final suppressed = off.graceAlertOutcome;
      off.dispose();
      service = null;

      final on = await enterGrace(notificationsEnabled: true);
      expect(suppressed, isNot(on.graceAlertOutcome));
    });
  });

  group('no live call site discards the outcome (source contract)', () {
    test('no syntactically visible showEmergencyAlert invocation in lib/ '
        'discards its outcome', () {
      // RER-04. This test used to be named "every ... is consumed" and anchored
      // on `NotificationService.instance.showEmergencyAlert` -- one receiver
      // spelling. The hoisted form
      //
      //     final svc = NotificationService.instance;
      //     await svc.showEmergencyAlert(...);
      //
      // was therefore never ENUMERATED, so the word "every" was carried by a
      // check that could not have found the counterexample. The anchor is now
      // the METHOD NAME, receiver-agnostic.
      //
      // The claim this test makes is deliberately the smaller one: nothing
      // SYNTACTICALLY VISIBLE drops an outcome. The element-resolved
      // enumeration -- which follows the wrapper chain to a fixpoint and
      // reports invocations it cannot resolve instead of skipping them -- is
      // `scripts/verify_alert_outcome_consumption.dart`, run by
      // `scripts/verify_repository_convergence.sh`.
      final anchor = RegExp(
        r'(?:\.showEmergencyAlert|SafetyAlertDispatch\.postWarning)\(',
      );
      final unconsumed = <String>[];
      var found = 0;
      for (final entry in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = entry.readAsStringSync();
        for (final match in anchor.allMatches(src)) {
          found++;
          final head = src.substring(0, match.start);
          final boundary = <int>[
            head.lastIndexOf(';'),
            head.lastIndexOf('{'),
            head.lastIndexOf('}'),
          ].reduce((a, b) => a > b ? a : b);
          // The anchor starts at `.showEmergencyAlert`, so the receiver
          // expression is at the tail of the statement and would mask the
          // `=` / `return` / `=>` that decides consumption. Strip it: what
          // matters is what precedes the receiver, not its spelling.
          final statement = head
              .substring(boundary + 1)
              .replaceAll(RegExp(r'//[^\n]*'), '')
              .replaceAll(RegExp(r'[\w$.]+\s*$'), '')
              .trim();
          final consumed =
              RegExp(r'(?:=|return|=>)\s*(?:await)?\s*$').hasMatch(statement);
          if (!consumed) {
            unconsumed.add('${entry.path}:${head.split('\n').length}');
          }
        }
      }
      expect(found, greaterThanOrEqualTo(5),
          reason: 'the census must actually find the call sites; zero sites '
              'would make this assertion vacuous');
      expect(unconsumed, isEmpty,
          reason: 'a safety alert whose typed outcome is thrown away is '
              'indistinguishable from one the OS displayed: $unconsumed');
    });

    test('the element-resolved verifier exists and is the authoritative '
        'enumeration', () {
      // The honest half of RER-04: the regex above states a smaller claim, and
      // something else must carry the bigger one. If this file is deleted, the
      // repository is back to claiming "every" from a substring match.
      final verifier =
          File('scripts/verify_alert_outcome_consumption.dart');
      expect(verifier.existsSync(), isTrue,
          reason: 'the authoritative enumeration must exist');
      final src = verifier.readAsStringSync();
      expect(src, contains('package:analyzer/dart/ast/visitor.dart'),
          reason: 'it must resolve the AST, not match text');
      expect(src, contains('node.methodName.element'),
          reason: 'enumeration must go through the element model, so the '
              'receiver spelling cannot change what is found');
      expect(src, contains('escapesViaReturn'),
          reason: 'the wrapper chain must be followed, not assumed');
      expect(src, contains('unresolvedAlertLikeInvocation'),
          reason: 'what it cannot resolve must be reported, not skipped');

      // And the convergence gate must actually run it.
      final gate = File('scripts/verify_repository_convergence.sh');
      expect(gate.existsSync(), isTrue);
      expect(gate.readAsStringSync(),
          contains('verify_alert_outcome_consumption.dart'),
          reason: 'a verifier nothing runs proves nothing');
    });

    test('the Safe Walk warning is neither an un-awaited Future nor a bare '
        'catch', () {
      final src = File('lib/screens/safe_walk_screen.dart').readAsStringSync();
      expect(src, contains('unawaited(_firePreExpiryWarning())'),
          reason: 'fire-and-forget must be explicit, so a throw is not an '
              'unhandled async error');
      final start = src.indexOf('Future<void> _firePreExpiryWarning()');
      expect(start, isNot(-1));
      final body = src.substring(start, src.indexOf('Future<void> _markSafe'));
      expect(body, contains('final outcome = await'));
      expect(body, isNot(contains('catch (_)')));
      expect(body, contains('DispatchReachability.reached'));
      expect(body, contains('safe_walk_pre_warning_undelivered'),
          reason: 'the user is on this screen; they must be told');
    });

    test('the Check-In grace warning no longer hides failure in a bare catch',
        () {
      final src =
          File('lib/core/services/check_in_service.dart').readAsStringSync();
      final start =
          src.indexOf('Future<DispatchTargetOutcome> _showGraceNotification()');
      expect(start, isNot(-1),
          reason: 'the grace notification must report an outcome');
      expect(src, contains('SafetyAlertDispatch.postWarning'),
          reason: 'the grace warning posts through the reporting wrapper');
      expect('_lastGraceAlertOutcome = await'.allMatches(src).length, 2,
          reason: 'BOTH grace entry points (Dart expiry and the native '
              'grace-started callback) must keep the outcome');
      expect(src, isNot(contains('_bestEffort(_showGraceNotification)')),
          reason: 'the best-effort wrapper is where the outcome used to die');
    });

    test('the shared wrapper classifies and records instead of swallowing', () {
      final raw = File(
        'lib/core/services/safety_alert_dispatch.dart',
      ).readAsStringSync();
      // Comments quote the defect being described; only code counts.
      final src = raw.replaceAll(RegExp(r'//[^\n]*'), '');
      expect(src, isNot(contains('catch (_)')),
          reason: 'a bare catch turned every failure mode into one silence');
      expect(src, contains('on Exception catch'));
      expect(src, contains('on Error catch'),
          reason: 'documented dispatch-fan-out exception: recorded, never '
              'swallowed, so a notification bug cannot stop a grace ticker');
      expect(src, contains('DispatchOutcomeClassifier.classifyError'));
      expect(src, contains('LocalWarningCode.safetyAlertNotDelivered'));
    });

    test('the Check-In screen surfaces a warning the user never saw', () {
      final screen =
          File('lib/screens/check_in_screen.dart').readAsStringSync();
      expect(screen, contains('_service.graceAlertOutcome'));
      expect(screen, contains('check_in_grace_alert_undelivered'));
    });
  });
}
