// Android 48 dp minimum interactive size -- REGRESSION cover for the controls
// that were measured under it on a real device.
//
// HOW THE NUMBERS WERE OBTAINED, and why this file measures rather than infers.
// Each control below was first read from the RENDERED SEMANTICS TREE on an API
// 36 emulator (`adb shell uiautomator dump`, density 420 / dpr 2.625) --
// never from its icon size, which is how the previous pass under-reported them:
//
//   readiness status chip .................. 90.7 x 30.9 dp
//   rehearsal line ......................... 329.1 x 38.1 dp
//   consent checkbox (nested node) .......... 24.0 x 24.0 dp
//   contact-consent dialog checkbox ......... 22.1 x 22.1 dp
//   settings switch ......................... 51.0 x 40.8 dp
//   consent-management switch (compact) ..... 51.0 x 28.2 dp
//
// This file re-measures the same thing WITHOUT a device, from the semantics
// rect Flutter actually produces (`tester.getSemantics().rect`), so a
// regression is caught in CI instead of on the next emulator pass. The device
// remains the ground truth the harness was calibrated against; see
// docs/audit/device-verification-2026-08-14-touch-targets.md.
//
// THE CLIPPING TRAP, recorded because it invented a defect once. uiautomator
// reports the CLIPPED rect, so a control at the edge of a scroll viewport reads
// short: the consent screen's "Detayi Gor" button measured 115.8 x 26.3 dp at
// the viewport edge and 115.8 x 48.0 dp after a 300 px scroll -- same widget,
// same build, same run. Widget tests do not have that failure mode, which is
// exactly why the regression bar lives here.

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/widgets/minimum_tap_target.dart';
import 'package:guvenlik_app/core/widgets/readiness_card.dart';
import 'package:guvenlik_app/widgets/consent_checkbox_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android's recommended minimum interactive dimension.
const double kMinTapDp = 48.0;

class _MapAssetLoader extends AssetLoader {
  const _MapAssetLoader(this._data);
  final Map<String, Map<String, dynamic>> _data;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final key = locale.countryCode != null
        ? '${locale.languageCode}-${locale.countryCode}'
        : locale.languageCode;
    return _data[key] ?? {};
  }
}

const _tr = <String, String>{
  'ready': 'Kurulum tamam',
  'system_ready_desc': 'Acil kisin kayitli, arama izni acik.',
  'setup_incomplete': 'Kuruluma {count} adim kaldi',
  'setup_incomplete_desc': 'Once acil kisini ekleyelim.',
  'readiness_almost_title': 'Kurulumun buyuk bolumu tamam',
  'readiness_almost_desc': 'Tek eksik: {item}.',
  'readiness_background_note': 'Ekran kapaliyken zamanlayicilar gecikebilir.',
  'readiness_auto_call_note': 'Bu cihaz aramayi kendi baslatamiyor.',
  'readiness_last_rehearsal': 'Son prova: {date}',
  'readiness_no_rehearsal': 'Henuz prova yapmadin.',
  'call_permission_fallback_note': 'Izin verilmedi',
  'emergency_contact': 'Acil kisi',
  'phone_call_permission': 'Telefon Aramasi',
  'background_readiness': 'Arka Plan Hazirligi',
  'location': 'Konum',
  'contacts': 'Rehber',
};

/// The rendered INTERACTIVE rect in GLOBAL (screen) coordinates.
///
/// The global part is not pedantry, it is the whole measurement.
/// `SemanticsNode.rect` is expressed in the node's OWN coordinate space, so a
/// control inside `Transform.scale(scale: 0.85)` reports its untransformed
/// 48 dp there while the user's thumb -- and every accessibility service --
/// sees 40.8 dp. This harness initially read that local rect and cheerfully
/// declared the shipped 0.85-scaled switch compliant; the device, via
/// `uiautomator dump`, said 40.8 dp. The device was right.
///
/// `tester.getRect` returns the render object's rect already transformed into
/// the global coordinate space, which is what both a touch and uiautomator
/// resolve against, so that is what is graded here.
Size interactiveSize(WidgetTester tester, Finder finder) =>
    tester.getRect(finder).size;

void expectAtLeastMinimum(
  WidgetTester tester,
  Finder finder, {
  required String what,
  bool widthToo = true,
}) {
  final Size size = interactiveSize(tester, finder);
  expect(
    size.height,
    greaterThanOrEqualTo(kMinTapDp),
    reason:
        '$what is ${size.width.toStringAsFixed(1)} x '
        '${size.height.toStringAsFixed(1)} dp. Android asks for '
        '$kMinTapDp dp. Grow the INTERACTIVE box (MinimumTapTarget or padding), '
        'not the artwork.',
  );
  if (widthToo) {
    expect(
      size.width,
      greaterThanOrEqualTo(kMinTapDp),
      reason:
          '$what is only ${size.width.toStringAsFixed(1)} dp wide.',
    );
  }
}

PlatformReadinessSnapshot _snapshot() => const PlatformReadinessSnapshot(
      supportedOs: true,
      telephonyCalling: true,
      telecomAvailable: true,
      dialHandlerAvailable: true,
      batteryOptimizationWhitelisted: true,
      exactAlarmPermission: true,
      callPermission: true,
      notificationPermission: true,
      alertChannelHigh: true,
    );

Future<void> _pumpLocalized(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const <Locale>[Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: const _MapAssetLoader(<String, Map<String, dynamic>>{
        'tr-TR': _tr,
      }),
      fallbackLocale: const Locale('tr', 'TR'),
      startLocale: const Locale('tr', 'TR'),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  group('MinimumTapTarget', () {
    testWidgets('grows a small control to 48 dp without repainting it larger',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MinimumTapTarget(
                onTap: () {},
                child: Container(
                  key: const Key('artwork'),
                  width: 20,
                  height: 20,
                  color: const Color(0xFF00FF00),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('artwork'))),
        const Size(20, 20),
        reason:
            'THE POINT OF THE WIDGET: the artwork must not grow. A fix that '
            'enlarges the visual element is a redesign, not an accessibility '
            'fix.',
      );
      expectAtLeastMinimum(
        tester,
        find.byType(MinimumTapTarget),
        what: 'MinimumTapTarget box',
      );
      handle.dispose();
    });

    testWidgets('taps in the enlarged margin reach the callback', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MinimumTapTarget(
                onTap: () => taps++,
                child: const SizedBox(width: 20, height: 20),
              ),
            ),
          ),
        ),
      );

      // A point inside the 48 dp box but OUTSIDE the 20 dp artwork. Before the
      // fix this pixel hit nothing at all.
      final Rect box = tester.getRect(find.byType(MinimumTapTarget));
      await tester.tapAt(Offset(box.left + 3, box.top + 3));
      await tester.pump();
      expect(
        taps,
        1,
        reason:
            'the enlarged area must be genuinely interactive, not merely '
            'declared: a Semantics-only fix would pass a size assertion while '
            "the user's thumb still missed.",
      );
    });

    testWidgets(
        'NEGATIVE CONTROL: the same artwork without the wrapper is under 48 dp',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  key: Key('bare'),
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ),
        ),
      );
      final Size size = interactiveSize(tester, find.byKey(const Key('bare')));
      expect(
        size.height,
        lessThan(kMinTapDp),
        reason:
            'NEGATIVE CONTROL: if a bare 20 dp control measured >= 48 dp, the '
            'measurement above would be reading something other than the '
            'control and every assertion in this file would be vacuous.',
      );
      handle.dispose();
    });
  });

  group('readiness card (home screen)', () {
    testWidgets('every status chip is at least 48 dp tall', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpLocalized(
        tester,
        ReadinessCard(
          locationGranted: false,
          contactsGranted: false,
          hasEmergencyContact: false,
          readiness: _snapshot(),
          lastRehearsalAt: null,
          onFixEmergencyContact: () {},
          onFixCallPermission: () {},
          onFixBackground: () {},
          onFixLocation: () {},
          onFixContacts: () {},
          onRunRehearsal: () {},
        ),
      );

      final Finder chips = find.byType(MinimumTapTarget);
      expect(
        chips,
        findsNWidgets(5),
        reason:
            'harness precondition: the card shows five permission shortcuts. '
            'If this count changes, the new chip needs covering too.',
      );
      for (var i = 0; i < 5; i++) {
        expectAtLeastMinimum(tester, chips.at(i), what: 'status chip $i');
      }
      handle.dispose();
    });

    testWidgets('the rehearsal shortcut is at least 48 dp tall', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpLocalized(
        tester,
        ReadinessCard(
          locationGranted: true,
          contactsGranted: true,
          hasEmergencyContact: true,
          readiness: _snapshot(),
          lastRehearsalAt: null,
          onFixEmergencyContact: () {},
          onFixCallPermission: () {},
          onFixBackground: () {},
          onFixLocation: () {},
          onFixContacts: () {},
          onRunRehearsal: () {},
        ),
      );
      expectAtLeastMinimum(
        tester,
        find.ancestor(
          of: find.textContaining('prova'),
          matching: find.byType(InkWell),
        ),
        what: 'rehearsal shortcut',
      );
      handle.dispose();
    });
  });

  group('scaled switches', () {
    // `Transform.scale` scales the HIT REGION with the pixels, so Material's
    // built-in 48 dp switch target was being shrunk to 40.8 dp (51.0 x 40.8 dp
    // measured on device; 51.0 x 28.2 dp for the compact variant). Both cases
    // below render the exact composition the two call sites use.
    Widget scaledSwitch({required bool wrapped}) {
      final Widget artwork = Transform.scale(
        scale: 0.85,
        child: Switch(value: true, onChanged: (_) {}),
      );
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: wrapped
                ? MinimumTapTarget(onTap: () {}, child: artwork)
                : artwork,
          ),
        ),
      );
    }

    testWidgets('NEGATIVE CONTROL: a bare 0.85-scaled switch is under 48 dp',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(scaledSwitch(wrapped: false));
      final Size size = interactiveSize(tester, find.byType(Switch));
      expect(
        size.height,
        lessThan(kMinTapDp),
        reason:
            'NEGATIVE CONTROL: this is the shipped defect. If it ever passes, '
            'Flutter changed how Transform interacts with the switch tap '
            'target and the wrapper below may no longer be needed -- verify on '
            'device before removing it.',
      );
      handle.dispose();
    });

    testWidgets('wrapped in MinimumTapTarget it reaches 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(scaledSwitch(wrapped: true));
      expectAtLeastMinimum(
        tester,
        find.byType(MinimumTapTarget),
        what: 'scaled switch',
      );
      handle.dispose();
    });

    test('both switch call sites are wrapped', () {
      // settings_page.dart's row was extracted to its own widget when adding
      // the wrapper pushed that file past the 800-line ratchet.
      const sites = <String>[
        'lib/widgets/settings_switch_tile.dart',
        'lib/screens/legal/consent_management_screen.dart',
      ];
      for (final path in sites) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('Transform.scale'),
          isTrue,
          reason: 'harness precondition: $path still scales its switch',
        );
        expect(
          source.contains('MinimumTapTarget'),
          isTrue,
          reason:
              '$path scales a Switch by 0.85, which shrinks its 48 dp tap '
              'target to 40.8 dp. Wrap it in MinimumTapTarget.',
        );
      }
    });
  });

  group('consent checkbox', () {
    testWidgets(
        'exposes ONE node the size of the row, not a 24 dp checkbox beside it',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConsentCheckboxWidget(
              label: 'Kullanim sozlesmesini okudum.',
              value: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.byType(Checkbox),
        findsOneWidget,
        reason: 'harness precondition: the artwork is still a real Checkbox',
      );
      expect(
        tester.getSize(find.byType(Checkbox)),
        const Size(24, 24),
        reason:
            'the 24 dp box is the VISUAL affordance and must not grow -- only '
            'its separate semantic node had to go.',
      );

      // The row is the target. Its rendered rect is what a thumb hits...
      expectAtLeastMinimum(
        tester,
        find.byType(ConsentCheckboxWidget),
        what: 'merged consent row',
      );
      // ...and the merge is what stops a SECOND, 24 dp node being advertised
      // beside it. Before the merge the device reported both a 371.4 x 82.3 dp
      // row and a 24.0 x 24.0 dp checkbox, each announcing the same sentence.
      final SemanticsNode row =
          tester.getSemantics(find.byType(ConsentCheckboxWidget));
      // A merged child still exists in the Dart-side tree; what matters is
      // whether it is handed to the PLATFORM as its own node. `isMergedIntoParent`
      // is that distinction, and it is the one uiautomator reflected: after the
      // merge the device dump showed a single 371.4 x 82.3 dp node carrying the
      // CheckBox role, and no 24 dp sibling.
      final List<SemanticsNode> unmergedTappableChildren = <SemanticsNode>[];
      row.visitChildren((SemanticsNode child) {
        if (!child.isMergedIntoParent &&
            child.getSemanticsData().hasAction(SemanticsAction.tap)) {
          unmergedTappableChildren.add(child);
        }
        return true;
      });
      expect(
        unmergedTappableChildren,
        isEmpty,
        reason:
            'the row must reach the platform as ONE tappable node. An '
            'unmerged tappable child is exactly the 24 dp target that was '
            'measured on the device.',
      );
      handle.dispose();
    });

    test('the emergency-contact consent dialog merges its checkbox too', () {
      final source = File(
        'lib/widgets/emergency_contact_consent_dialog.dart',
      ).readAsStringSync();
      expect(
        source.contains('MergeSemantics'),
        isTrue,
        reason:
            'Its checkbox was the smallest interactive node in the app at '
            '22.1 x 22.1 dp. Merging leaves one node the size of the row -- '
            'measured 283.4 x 77.0 dp on device afterwards.',
      );
    });
  });
}
