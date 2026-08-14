// Android state restoration -- POLICY cover.
//
// Restoration is a security-relevant feature in this app, in two directions,
// and this file pins both.
//
// 1. WHAT MUST BE RESTORABLE. Without a restoration bucket there is no root
//    for `RestorationMixin` to register against, every restorable property is
//    inert, and the app silently loses a half-typed emergency contact to any
//    OS-initiated process death. The behaviour cover in
//    `test/screens/state_restoration_test.dart` proves the loss; this file
//    stops the enabling scope from being deleted by accident.
//
//    Turning the root id on has a PRECONDITION: the Navigator's initial route
//    must survive, because `WidgetsApp` enables route restoration together with
//    everything else. Startup used to destroy it four times over with
//    `pushReplacement`/`pushAndRemoveUntil`, which bricked the app on resume.
//    `AppRoot` is the shell that fixed it; the rules below keep it that way and
//    `test/screens/state_restoration_navigator_precondition_test.dart` is the
//    executable proof.
//
// 2. WHAT MUST NOT BE RESTORABLE.
//
//    (a) PIN MATERIAL. This product's entire auth story is a local PIN chosen
//        precisely because it can be WITHHELD under duress (CLAUDE.md rule 2 --
//        biometrics are forbidden for the same reason). Persisting a partially
//        entered PIN into restoration data, which Android writes to the
//        activity's saved instance state, would put PIN digits somewhere they
//        have never been. The unlock screen keeps its digits in a plain
//        `String` field on purpose.
//
//    (b) ROUTES, above the unlock gate. This one is not obvious and is the
//        reason the app uses restorable STATE but not restorable ROUTES.
//        SplashScreen reaches AppUnlockScreen with `pushReplacement`, so it
//        replaces the route at the BOTTOM of the stack. A route restored from
//        the previous session is re-inserted ABOVE it. The user would come
//        back from a process death looking at the restored screen with the
//        unlock screen parked underneath -- the PIN gate defeated by a feature
//        meant to preserve typing. `bypassProof` below demonstrates the stack
//        arithmetic, and the source assertion keeps any `restorable*` push out
//        of `lib/`.
//
//    (c) THE DESTRUCTIVE-RESET CONFIRMATION. `AppResetHelper` asks for the PIN
//        before wiping all local data. Restoring that dialog's typed text
//        would re-arm a wipe across a process death the user never saw.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source files that handle PIN material or a destructive confirmation.
/// None of them may become restorable.
const List<String> kSecretBearingSources = <String>[
  'lib/screens/app_unlock_screen.dart',
  'lib/screens/pin_setup_screen.dart',
  'lib/core/utils/pin_settings_helper.dart',
  'lib/core/widgets/safety_session_pin_gate.dart',
  'lib/core/utils/app_reset_helper.dart',
];

/// Every restorable-push API. None may appear in `lib/` while the unlock gate
/// is reached with `pushReplacement`.
const List<String> kRestorableRouteApis = <String>[
  'restorablePush',
  'restorablePushNamed',
  'restorablePushReplacement',
  'restorablePushReplacementNamed',
  'restorablePushAndRemoveUntil',
  'restorableTransparentPush',
  'RestorableRouteFuture',
];

String read(String path) => File(path).readAsStringSync();

/// Strips `//` line comments so a rule can never be tripped -- or satisfied --
/// by prose. This file explains the policy in comments that name the very
/// identifiers it forbids; scanning raw text made `lib/main.dart` fail its own
/// rule for talking about it.
String code(String source) => source
    .split('\n')
    .map((line) {
      final marker = line.indexOf('//');
      return marker == -1 ? line : line.substring(0, marker);
    })
    .join('\n');

List<File> libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// The stack arithmetic that makes restorable routes unsafe here, expressed as
/// a pure function so it can be asserted rather than asserted-about.
///
/// [restoredRoutes] are routes Flutter re-inserts above the initial route when
/// the process is recreated. SplashScreen then calls `pushReplacement`, which
/// replaces the route it is ON -- the bottom one -- and leaves everything above
/// it in place.
List<String> bypassProof({required List<String> restoredRoutes}) {
  final stack = <String>['SplashScreen', ...restoredRoutes];
  // pushReplacement replaces the splash route in place; it does not clear the
  // stack above it.
  stack[0] = 'AppUnlockScreen';
  return stack;
}

void main() {
  group('restoration is enabled at the root', () {
    test('the root MaterialApp carries the restorationScopeId', () {
      final main = code(read('lib/main.dart'));
      expect(
        main.contains("restorationScopeId: 'korubeni'"),
        isTrue,
        reason:
            'Without a root bucket every RestorationMixin in the app is inert: '
            'registerForRestoration finds nothing, keeps its default value, '
            'and a half-typed emergency contact is lost to any OS-initiated '
            'process death.',
      );
    });

    test('`home:` is the AppRoot shell, not a screen that replaces itself', () {
      final main = code(read('lib/main.dart'));
      expect(
        main.contains('home: const AppRoot()'),
        isTrue,
        reason:
            'The root id above is only safe while the initial route survives. '
            'AppRoot swaps its top-level destination as STATE; a `home:` that '
            'replaces itself leaves the restored route history empty and '
            'assert(_history.isNotEmpty) bricks the app on resume.',
      );
    });

    test('no top-level destination is reached by destroying the route stack',
        () {
      // These four call sites are exactly the ones that used to remove the
      // initial route. Each now advances the AppRoot shell instead, and each
      // keeps its old navigation only as a fallback for being mounted alone.
      const startupSurfaces = <String>[
        'lib/screens/app_root.dart',
        'lib/screens/splash_screen.dart',
        'lib/screens/legal/unified_consent_screen.dart',
        'lib/screens/onboarding_screen.dart',
      ];
      for (final path in startupSurfaces) {
        final source = code(read(path));
        expect(
          source.contains('pushAndRemoveUntil((_) => false)'),
          isFalse,
          reason: '$path must not clear the whole stack',
        );
      }
      expect(
        code(read('lib/screens/app_root.dart')).contains('Navigator'),
        isFalse,
        reason:
            'AppRoot must swap destinations as STATE. The moment it navigates, '
            'the initial route is at risk again and root-level restoration '
            'stops being safe.',
      );
    });

    test('every RestorationMixin in lib/ declares a non-null restorationId',
        () {
      final offenders = <String>[];
      for (final file in libDartFiles()) {
        final source = code(file.readAsStringSync());
        if (!RegExp(r'with[^{;]*\bRestorationMixin\b').hasMatch(source)) {
          continue;
        }
        final match = RegExp(r'String\?\s+get\s+restorationId\s*=>\s*([^;]+);')
            .firstMatch(source);
        if (match == null || match.group(1)!.trim() == 'null') {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A RestorationMixin whose restorationId is null registers nothing '
            'and restores nothing, while still LOOKING like restoration is '
            'implemented. That is exactly the failure mode this suite exists '
            'to prevent.',
      );
    });
  });

  group('secrets are never restorable', () {
    for (final path in kSecretBearingSources) {
      test('$path holds no Restorable* property', () {
        final source = code(read(path));
        expect(
          source.contains('Restorable'),
          isFalse,
          reason:
              'This file handles PIN material or a destructive confirmation. '
              'Restoration data is handed to Android as saved instance state; '
              'putting PIN digits there would move the one secret this duress '
              'model depends on into storage it has never been in. Keep the '
              'plain String / plain TextEditingController.',
        );
      });
    }

    test('the unlock screen keeps its digits in a plain field', () {
      final source = read('lib/screens/app_unlock_screen.dart');
      expect(
        source.contains("String _pin = ''"),
        isTrue,
        reason:
            'The entered-PIN buffer must stay a plain String. If it is ever '
            'promoted to a RestorableString the digits become saved instance '
            'state.',
      );
    });
  });

  group('routes are not restorable while the unlock gate is a pushReplacement',
      () {
    test('a restored route would sit ABOVE the unlock screen', () {
      final stack = bypassProof(restoredRoutes: <String>['SafetyTimelineScreen']);
      expect(
        stack.last,
        'SafetyTimelineScreen',
        reason:
            'PROOF, not prose: after a process death the restored route is on '
            'top and AppUnlockScreen is underneath it. The user sees their '
            'data without entering a PIN. This is why lib/ uses restorable '
            'STATE (which cannot make a widget appear) and never a restorable '
            'ROUTE.',
      );
      expect(stack.first, 'AppUnlockScreen');
    });

    test('lib/ contains no restorable route API', () {
      final offenders = <String>[];
      for (final file in libDartFiles()) {
        final source = code(file.readAsStringSync());
        for (final api in kRestorableRouteApis) {
          if (source.contains(api)) {
            offenders.add('${file.path}: $api');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Adding a restorable route push re-opens the PIN bypass proved by '
            'the case above. If restorable routes are ever wanted, the unlock '
            'gate must first stop being a pushReplacement at the bottom of the '
            'stack -- change that FIRST, then this rule, and re-verify on '
            'device. Offenders: $offenders',
      );
    });
  });

  group('the restored surfaces are the intended ones', () {
    test('onboarding contact drafts and the two index surfaces are restorable',
        () {
      final expected = <String, String>{
        'lib/screens/onboarding/onboarding_contact_step.dart':
            "'onboarding_contact_step'",
        'lib/screens/onboarding_screen.dart': "'onboarding_screen'",
        'lib/screens/main_navigation.dart': "'main_navigation'",
      };
      expected.forEach((path, id) {
        final source = code(read(path));
        expect(
          RegExp(r'with[^{;]*\bRestorationMixin\b').hasMatch(source),
          isTrue,
          reason: '$path must remain restorable',
        );
        expect(
          source.contains(id),
          isTrue,
          reason:
              'The restoration id $id is part of the saved-state contract. '
              'Renaming it silently discards any state already saved under the '
              'old id on a user device.',
        );
      });
    });
  });
}
