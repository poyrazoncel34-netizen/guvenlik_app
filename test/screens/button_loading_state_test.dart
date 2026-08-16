// The "Loading" cell of the component-state matrix (MP-08-008), MEASURED.
//
// Why this file exists
// --------------------
// `MP-08-008` sat at PARTIAL with the gap "Button-level loading state not
// confirmed" and the remediation "Cover in the proposed golden-test suite".
// Goldens are forbidden here (`.claude/rules/dart/testing.md`), so the row was
// parked behind a remedy the repository does not allow -- while the property it
// asks about is decidable two cheaper ways, both used below.
//
// 1. A RENDER assertion on a real non-paywall surface. `paywall_render_test.dart`
//    already proves the busy frame for the restore button, so the open half was
//    everything else; `EmergencyContactConsentDialog` is driven here with a
//    parked `ConsentManager` so the in-flight frame actually exists to observe.
//
// 2. A SOURCE INVENTORY contract over every async in-flight flag in `lib/`, so
//    a NEW async button that forgets its loading state fails this test instead
//    of being discovered by a user. A render test of one screen cannot do that;
//    an inventory cannot prove the pixels. Neither alone is enough.
//
// The inventory rule, stated once
// -------------------------------
// An "async in-flight flag" is a field set to true inside `setState`, followed
// by an `await`, and reset to false afterwards. That signature is what a
// loading state IS. Every one of them must disable its control while the work
// runs; every one attached to a BUTTON must additionally render inline
// progress. Two flags are exempt and each exemption names its reason -- an
// exemption without a reason is how this kind of rule rots.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:guvenlik_app/widgets/emergency_contact_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Part 1 -- render: the busy frame on a real, non-paywall surface
// ---------------------------------------------------------------------------

/// Serves the REAL shipped catalogue, like the neighbouring paywall test.
class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final raw = File('assets/translations/tr-TR.json').readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

/// Parks `grantConsent` so the in-flight frame can be observed at all. A fake
/// that returned immediately would never render the state under test.
class _ParkedConsentManager extends ConsentManager {
  final Completer<void> gate = Completer<void>();
  int grantCalls = 0;

  @override
  Future<void> grantConsent(String consentType, {String? locale}) async {
    grantCalls++;
    await gate.future;
  }
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required VoidCallback onOk,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const <Locale>[Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: const _RealTrAssetLoader(),
      startLocale: const Locale('tr', 'TR'),
      fallbackLocale: const Locale('tr', 'TR'),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(
            body: SingleChildScrollView(
              child: EmergencyContactConsentDialog(
                contactName: 'QA Kisi',
                onConfirmed: onOk,
                onCancelled: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Bounded pumps, never pumpAndSettle: a repeating animation anywhere in the
  // tree makes settle() hang forever in this repo's widget tests.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The confirm button -- the one whose `onPressed` runs the async work.
Finder _confirmButton() => find.byType(ElevatedButton);

// ---------------------------------------------------------------------------
// Part 2 -- source inventory
// ---------------------------------------------------------------------------

/// A field set true in `setState`, awaited across, then reset IN THE SAME
/// METHOD -- i.e. a real "work is in flight" flag.
///
/// The same-method requirement is what separates a loading state from the two
/// shapes that look identical to a naive scan and are not loading states at
/// all: `pin_setup_screen._isConfirming` is a wizard STEP, set in the keypad
/// handler and cleared in `_verifyAndSave`, and `panic_button._isArmed` is a
/// press-and-hold gesture state, set on hold and cleared on pointer-up. Both
/// have an `await` somewhere after them and both are eventually set false, so a
/// windowed scan flags them; neither has a button waiting on I/O. Scoping to
/// one method is the fix. Suppressing them by name would have been the same
/// answer with the reasoning deleted.
final RegExp _setsTrue = RegExp(
  r'setState\(\s*\(\)\s*(?:=>|\{)[^;{}]*?\b(_\w+)\s*=\s*true',
);

/// The paywall tracks the in-flight package by identifier rather than a bool.
/// Same state, different type; excluding it would exempt the busiest surface.
final RegExp _setsIdentifier = RegExp(
  r'setState\(\s*\(\)\s*=>\s*(_\w+)\s*=\s*\w+\.identifier',
);

/// Flags that legitimately have no inline spinner. Each entry is a REASON, not
/// a suppression: if the reason stops being true the entry has to change.
const Map<String, String> kNoSpinnerJustified = <String, String>{
  'lib/core/widgets/safety_session_pin_gate.dart::_verificationInProgress':
      'The control is a dialog action, and its loading affordance is the '
      'dialog going inert: the TextField takes enabled: !_verificationInProgress '
      'and BOTH actions null their onPressed while the work runs, so the state '
      'is visible without a second indicator. The flag also blocks a double '
      'submit (_submit returns early while it is set). '
      'CORRECTED 2026-08-16 (CERT2-06): this entry used to claim the work was '
      '"not I/O with observable latency". That was false -- _submit awaits '
      'PinVerificationService.verify(), which reads flutter_secure_storage '
      'under an explicit .timeout(), and then awaits two more PinLockoutService '
      'reads and a write. The behaviour was always right; the recorded reason '
      'was not, and this map is contracted to hold reasons rather than '
      'suppressions.',
  'lib/screens/legal/consent_management_screen.dart::_loading':
      'The control is a Switch, not a button. Its loading affordance is the '
      'disabled state: both onTap and onChanged are nulled while the write is '
      'in flight, which is the correct Material affordance for a toggle.',
};

/// A class-member declaration at two-space indentation. Used only to decide
/// whether two assignments live in the same method body.
final RegExp _memberBoundary = RegExp(
  r'^  (?:@override\s*\n  )?(?:static\s+)?'
  r'(?:Future<[^>\n]*>|void|bool|Widget|String\??|int|double|[A-Z]\w*\??)\s+'
  r'_?\w+\s*\(',
  multiLine: true,
);

class AsyncFlag {
  const AsyncFlag(this.file, this.name);
  final String file;
  final String name;
  String get key => '$file::$name';
}

List<AsyncFlag> asyncInFlightFlags(
  String Function(String) read,
  List<String> files,
) {
  final out = <AsyncFlag>[];
  for (final file in files) {
    final source = read(file);
    for (final match in _setsTrue.allMatches(source)) {
      final name = match.group(1)!;
      // The window after the assignment: an await must happen inside it, and
      // the flag must be cleared, or this is a sticky state flag (a completed
      // step, an armed countdown) rather than work in flight.
      final end = match.end;
      final rest = source.substring(end);
      final clear = RegExp('${RegExp.escape(name)}\\s*=\\s*false').firstMatch(rest);
      if (clear == null) continue;
      final span = rest.substring(0, clear.start);
      if (!span.contains('await')) continue;
      // A member declaration between the two assignments means they sit in
      // different methods, so this is not one operation's in-flight window.
      if (_memberBoundary.hasMatch(span)) continue;
      out.add(AsyncFlag(file, name));
    }
    for (final match in _setsIdentifier.allMatches(source)) {
      out.add(AsyncFlag(file, match.group(1)!));
    }
  }
  final seen = <String>{};
  return out.where((f) => seen.add(f.key)).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
}

bool disablesItsControl(String source, String flag) => RegExp(
  'on(?:Pressed|Tap|Changed)\\s*:[^;]{0,200}?${RegExp.escape(flag)}',
  dotAll: true,
).hasMatch(source);

bool rendersInlineProgress(String source, String flag) => RegExp(
  '${RegExp.escape(flag)}[^;]{0,500}?CircularProgressIndicator',
  dotAll: true,
).hasMatch(source);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  group('MP-08-008 -- a button that is working says so', () {
    tearDown(() {
      if (serviceLocator.isRegistered<ConsentManager>()) {
        serviceLocator.unregister<ConsentManager>();
      }
    });

    testWidgets(
      'a non-paywall async button shows inline progress and refuses re-entry '
      'while its work is in flight',
      (tester) async {
        final consent = _ParkedConsentManager();
        if (serviceLocator.isRegistered<ConsentManager>()) {
          serviceLocator.unregister<ConsentManager>();
        }
        serviceLocator.registerSingleton<ConsentManager>(consent);

        var confirmed = 0;
        await _pumpDialog(tester, onOk: () => confirmed++);

        // Idle: no spinner inside the button.
        expect(
          find.descendant(
            of: _confirmButton(),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
          reason: 'an idle button must not render a progress indicator',
        );

        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
        expect(
          tester.widget<ElevatedButton>(_confirmButton()).onPressed,
          isNotNull,
          reason: 'the confirm button must be enabled once consent is ticked',
        );

        await tester.tap(_confirmButton());
        await tester.pump();

        expect(consent.grantCalls, 1);
        expect(
          find.descendant(
            of: _confirmButton(),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
          reason:
              'the in-flight frame must render progress INSIDE the button, not '
              'only as a full-screen overlay',
        );
        expect(
          tester.widget<ElevatedButton>(_confirmButton()).onPressed,
          isNull,
          reason: 'a loading button must be disabled while its action runs',
        );

        // Re-entry while busy must not start a second grant.
        await tester.tap(_confirmButton(), warnIfMissed: false);
        await tester.pump();
        expect(consent.grantCalls, 1);
        expect(confirmed, 0, reason: 'the callback fires only on completion');

        consent.gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(confirmed, 1);
      },
    );

    test('every async in-flight flag in lib/ disables its control, and every '
        'button-shaped one renders inline progress', () {
      final files =
          Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .map((f) => f.path)
              .where((p) => p.endsWith('.dart'))
              .toList()
            ..sort();
      String read(String p) => File(p).readAsStringSync();

      final flags = asyncInFlightFlags(read, files);
      expect(
        flags.length,
        greaterThanOrEqualTo(14),
        reason:
            'the inventory collapsed -- the detection regex probably stopped '
            'matching, which would make this contract silently vacuous',
      );

      final undisabled = <String>[];
      final silent = <String>[];
      for (final flag in flags) {
        final source = read(flag.file);
        if (!disablesItsControl(source, flag.name)) {
          undisabled.add(flag.key);
        }
        if (rendersInlineProgress(source, flag.name)) continue;
        if (kNoSpinnerJustified.containsKey(flag.key)) continue;
        silent.add(flag.key);
      }

      expect(
        undisabled,
        isEmpty,
        reason:
            'these controls stay live while their own async work runs, so a '
            'second tap starts a second operation',
      );
      expect(
        silent,
        isEmpty,
        reason:
            'these buttons run async work with no inline progress and no '
            'recorded justification. Add the affordance, or add an entry to '
            'kNoSpinnerJustified saying why this control does not need one.',
      );
    });

    test(
      'NEGATIVE CONTROL -- a button that forgets its loading state is caught',
      () {
        const bad = '''
class _X extends State<X> {
  bool _busy = false;
  Future<void> _go() async {
    setState(() => _busy = true);
    await something();
    setState(() => _busy = false);
  }
  Widget build(BuildContext c) => ElevatedButton(onPressed: _go, child: t);
}
''';
        String read(String _) => bad;
        final flags = asyncInFlightFlags(read, <String>['lib/_probe.dart']);
        expect(
          flags.map((f) => f.name),
          contains('_busy'),
          reason: 'the detector must recognise the in-flight signature',
        );
        expect(
          disablesItsControl(bad, '_busy'),
          isFalse,
          reason: 'the disable rule must fire on an unguarded onPressed',
        );
        expect(
          rendersInlineProgress(bad, '_busy'),
          isFalse,
          reason: 'the progress rule must fire on a button with no indicator',
        );

        // And the mirror image: a correct button must NOT be flagged, or the
        // rule is just an alarm that always rings.
        const good = '''
  bool _busy = false;
  Future<void> _go() async {
    setState(() => _busy = true);
    await something();
    setState(() => _busy = false);
  }
  Widget build(BuildContext c) => ElevatedButton(
        onPressed: _busy ? null : _go,
        child: _busy ? const CircularProgressIndicator() : t,
      );
''';
        expect(disablesItsControl(good, '_busy'), isTrue);
        expect(rendersInlineProgress(good, '_busy'), isTrue);
      },
    );
  });
}
