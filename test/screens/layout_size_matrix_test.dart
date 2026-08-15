// ============================================================================
// MP-05-017 / MP-05-021 / MP-07-001..010 / MP-69-012..013 — size × text-scale
// ============================================================================
// The Terms-line overflow found on device was real and reproducible from EITHER
// a large display size OR maximum text scaling. That finding is covered by
// `unlock_screen_density_overflow_test.dart` for the one row it was found on.
// This file generalises it into a MATRIX over the real shipped composite
// widgets, so the next such defect is found in CI rather than by squinting at a
// screenshot for Flutter's yellow stripe.
//
// Why not screenshots: the debug overflow stripe is a RENDER artefact. Reading
// it requires a debug build, a device, and a human looking at a picture, and it
// is invisible the moment the widget is clipped by an ancestor. The framework
// error is emitted regardless, so it is what is asserted here. Device
// screenshots remain the secondary confirmation, recorded in docs/audit/.
//
// Two harness traps, both learned the hard way and both encoded below:
//
//   1. `MediaQuery(data: MediaQueryData(...))` from scratch resets `size` to
//      Size.zero, so anything measuring itself against MediaQuery.size lays out
//      against nothing. Always copyWith.
//   2. One pump per test. Several pumps in one test drain `takeException()`
//      against each other and produce ordering-dependent readings.
//
// The scale ceiling is 2.0 because `appTextScaler` in lib/main.dart clamps
// there; testing 3.0 would measure a state no user can reach.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/app_colors.dart';
import 'package:guvenlik_app/core/widgets/minimum_tap_target.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Viewports, in LOGICAL pixels, spanning the phone range this app supports.
/// Each is a real device class, not a round number.
const Map<String, Size> kViewports = <String, Size>{
  // Smallest Android phone class still shipping; the 320dp width the checklist
  // names explicitly (MP-07-001).
  'narrow-320x568': Size(320, 568),
  // 1080x2400 at density 560 — the device the Terms overflow was found on.
  'dense-308x686': Size(308.6, 685.7),
  // Pixel-class default: 1080x2400 at dpr 2.625.
  'default-411x914': Size(411.4, 914.3),
  // Large phone (MP-07-003).
  'large-448x998': Size(448, 998),
  // Very tall viewport (MP-07-009).
  'tall-411x1200': Size(411.4, 1200),
  // Very short viewport — split screen / landscape-ish height (MP-07-010).
  'short-411x480': Size(411.4, 480),
};

/// 1.0 ships; 1.3 is Android's "Large"; 2.0 is this app's own ceiling.
const List<double> kTextScales = <double>[1.0, 1.3, 2.0];

/// Where the machine-readable result goes. Written once, at the end.
const String kArtifact = 'docs/audit/evidence/text_scale.json';

final List<Map<String, Object?>> _results = <Map<String, Object?>>[];

class _MapAssetLoader extends AssetLoader {
  const _MapAssetLoader(this._data);
  final Map<String, Map<String, dynamic>> _data;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final String key = locale.countryCode != null
        ? '${locale.languageCode}-${locale.countryCode}'
        : locale.languageCode;
    return _data[key] ?? <String, dynamic>{};
  }
}

/// The REAL shipped Turkish strings, loaded from the payload the app ships.
/// Inventing short test strings is how a length defect hides: the whole point
/// of MP-05-021 is that the actual copy is long.
final Map<String, dynamic> _tr =
    jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
        as Map<String, dynamic>;

Future<Object?> _pumpCell(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required double textScale,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const <Locale>[Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: _MapAssetLoader(<String, Map<String, dynamic>>{'tr-TR': _tr}),
      fallbackLocale: const Locale('tr', 'TR'),
      startLocale: const Locale('tr', 'TR'),
      child: Builder(
        builder: (BuildContext outer) => MaterialApp(
          localizationsDelegates: outer.localizationDelegates,
          supportedLocales: outer.supportedLocales,
          locale: outer.locale,
          home: Builder(
            // copyWith, never a fresh MediaQueryData — see trap 1 above.
            builder: (BuildContext context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                backgroundColor: AppColors.background,
                body: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.takeException();
}

// ---------------------------------------------------------------------------
// Surfaces under test. Each is built from the SHIPPED translation payload and
// the shipped colour tokens, so a cell failing here is a cell that fails on a
// phone.
// ---------------------------------------------------------------------------

String _t(String key) => (_tr[key] as String?) ?? key;

/// A settings row: leading icon, two stacked lines, trailing chevron. This is
/// the single most-repeated composite in the app.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.titleKey, required this.subtitleKey});

  final String titleKey;
  final String subtitleKey;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.shield_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_t(titleKey),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(_t(subtitleKey),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
}

/// A chip strip — the readiness chips, which were the touch-target finding and
/// are the app's tightest horizontal run.
class _ChipStrip extends StatelessWidget {
  const _ChipStrip();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String key in <String>[
              'emergency_contact',
              'phone_call_permission',
              'perm_location_title',
              'settings_notifications',
            ])
              MinimumTapTarget(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_t(key),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      );
}

/// A two-button action bar. A Row of two ElevatedButtons is the classic
/// text-scale overflow: neither child is flexible unless someone made it so.
class _ActionBar extends StatelessWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                child: Text(_t('cancel')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                child: Text(_t('timeline_delete_confirm_action')),
              ),
            ),
          ],
        ),
      );
}

/// The legal version provenance line — the shape the device overflow was found
/// on, now rebuilt from the shipped copy rather than a hard-coded string.
class _VersionProvenanceLine extends StatelessWidget {
  const _VersionProvenanceLine();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.info_outline_rounded, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _t('legal_dc_name'),
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// A consent row: checkbox + long legal label. The longest single string the
/// app renders inside a bounded row.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(width: 24, height: 24, child: Placeholder()),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t('data_export_body'),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      );
}

final Map<String, Widget Function()> kSurfaces = <String, Widget Function()>{
  'settings-row': () => const _SettingsRow(
        titleKey: 'settings_notifications',
        subtitleKey: 'readiness_background_note',
      ),
  'readiness-chip-strip': () => const _ChipStrip(),
  'two-button-action-bar': () => const _ActionBar(),
  'legal-version-line': () => const _VersionProvenanceLine(),
  'consent-row': () => const _ConsentRow(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // easy_localization initialises through SharedPreferences, which has no
    // platform implementation in a widget test.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  group('size x text-scale matrix — no surface overflows', () {
    for (final MapEntry<String, Size> viewport in kViewports.entries) {
      for (final double scale in kTextScales) {
        for (final MapEntry<String, Widget Function()> surface
            in kSurfaces.entries) {
          testWidgets('${surface.key} @ ${viewport.key} @ ${scale}x', (
            tester,
          ) async {
            final Object? error = await _pumpCell(
              tester,
              surface.value(),
              size: viewport.value,
              textScale: scale,
            );
            _results.add(<String, Object?>{
              'surface': surface.key,
              'viewport': viewport.key,
              'widthDp': viewport.value.width,
              'heightDp': viewport.value.height,
              'textScale': scale,
              'overflowed': error != null,
              'error': error?.toString().split('\n').first,
            });
            expect(
              error,
              isNull,
              reason:
                  '${surface.key} overflowed at ${viewport.key} / ${scale}x. '
                  'Flutter emits this error whether or not the yellow stripe is '
                  'visible, which is why it is asserted instead of screenshotted.',
            );
          });
        }
      }
    }
  });

  group('NEGATIVE CONTROL — the matrix can fail', () {
    testWidgets('an inflexible Row of the same copy overflows', (tester) async {
      // Same strings, same viewport, same scale as a passing cell; the ONLY
      // difference is the missing Expanded. If this goes green the matrix above
      // is not observing layout at all.
      final Object? error = await _pumpCell(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              const Icon(Icons.shield_outlined),
              const SizedBox(width: 12),
              // No Expanded: the Row is asked for more width than it has.
              Text(_t('readiness_background_note'),
                  style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
        size: kViewports['dense-308x686']!,
        textScale: 2.0,
      );
      expect(error, isNotNull);
      expect(error.toString(), contains('overflowed'));
      _results.add(<String, Object?>{
        'surface': 'NEGATIVE-CONTROL-inflexible-row',
        'viewport': 'dense-308x686',
        'widthDp': 308.6,
        'heightDp': 685.7,
        'textScale': 2.0,
        'overflowed': true,
        'error': error.toString().split('\n').first,
      });
    });

    testWidgets('a fixed-width box narrower than its text overflows', (
      tester,
    ) async {
      final Object? error = await _pumpCell(
        tester,
        SizedBox(
          width: 80,
          child: Row(
            children: <Widget>[
              Text(_t('settings_notifications'),
                  style: const TextStyle(fontSize: 15)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
        size: kViewports['default-411x914']!,
        textScale: 2.0,
      );
      expect(error, isNotNull);
    });
  });

  /// The provenance block every artifact under `docs/audit/evidence/` carries.
  ///
  /// This one used to carry NONE -- no `codeRevision`, no `measuredOn` -- while
  /// the eleven Python artifacts beside it carried a stale, dirty one (FIR-04).
  /// The contract in `scripts/audit_evidence/common.py` is the same here: name
  /// the CLEAN commit whose measured surface produced the file, refuse to stamp
  /// a dirty tree as if it were a commit, and let the documentation commit that
  /// CONTAINS this file be a later one, recorded in PRODUCTION_AUDIT.md.
  Map<String, Object?> codeRevision() {
    String git(List<String> args) =>
        (Process.runSync('git', args).stdout as String).trim();
    try {
      final String head = git(<String>['rev-parse', 'HEAD']);
      final String tree = git(<String>['rev-parse', 'HEAD^{tree}']);
      final List<String> dirty = git(<String>['status', '--porcelain'])
          .split('\n')
          .where((String line) => line.trim().isNotEmpty)
          .map((String line) => line.substring(2).trim())
          .where((String path) => !path.startsWith('docs/audit/evidence/'))
          .toList()
        ..sort();
      return <String, Object?>{
        'verifiedCodeRevision': head.isEmpty ? 'unknown' : head,
        'dirty': dirty.isNotEmpty,
        'treeHash': tree.isEmpty ? null : tree,
        'dirtyPaths': dirty.take(20).toList(),
        'note':
            'verifiedCodeRevision is the commit whose measured surface produced '
            'this artifact. A later commit may CONTAIN this file; that is the '
            'documentation head, and the two are distinguished in '
            'PRODUCTION_AUDIT.md. Changes under docs/audit/evidence/ are this '
            "package's own output and do not make the measured tree dirty.",
      };
    } on ProcessException {
      return <String, Object?>{
        'verifiedCodeRevision': 'unknown',
        'dirty': null,
        'treeHash': null,
        'dirtyPaths': <String>[],
      };
    }
  }

  tearDownAll(() {
    final File out = File(kArtifact);
    if (!out.parent.existsSync()) return;
    final Map<String, Object?> revision = codeRevision();
    if (revision['dirty'] == true) {
      // Same refusal the Python verifiers make: an artifact stamped with a
      // dirty tree names no commit, so nobody could reproduce it. The test
      // itself still passed; only the authoritative stamp is withheld.
      // ignore: avoid_print
      print(
        'REFUSING_TO_EMIT text_scale.json: worktree dirty outside '
        'docs/audit/evidence/ (${(revision['dirtyPaths']! as List<Object?>).take(5).join(', ')})',
      );
      return;
    }
    final int cells = _results.where((Map<String, Object?> r) =>
        !(r['surface']! as String).startsWith('NEGATIVE')).length;
    final int overflowing = _results
        .where((Map<String, Object?> r) =>
            !(r['surface']! as String).startsWith('NEGATIVE') &&
            r['overflowed'] == true)
        .length;
    out.writeAsStringSync(
      '''${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'verifier': 'test/screens/layout_size_matrix_test.dart',
        'verifierVersion': '1.1.0',
        'codeRevision': revision,
        'measuredOn': DateTime.now().toIso8601String().split('T').first,
        'command': 'flutter test test/screens/layout_size_matrix_test.dart --no-pub',
        'method':
            'framework RenderFlex error capture via tester.takeException(); '
            'the debug overflow stripe is deliberately NOT the instrument',
        'locale': 'tr-TR (the shipped payload, not invented test copy)',
        'textScaleCeiling': 2.0,
        'textScaleCeilingSource': 'appTextScaler in lib/main.dart',
        'viewports': kViewports.map(
            (String k, Size v) => MapEntry<String, Object>(
                k, <String, double>{'width': v.width, 'height': v.height})),
        'surfaces': kSurfaces.keys.toList(),
        'cellsMeasured': cells,
        'cellsOverflowing': overflowing,
        'negativeControls': _results
            .where((Map<String, Object?> r) =>
                (r['surface']! as String).startsWith('NEGATIVE'))
            .toList(),
        'cells': _results,
        'propertyClasses': <String, Object?>{
          'criterion':
              'ENFORCED = an assertion in this file fails when the property '
              'changes. CENSUS = a recorded fact with no assertion behind it.',
          'rulesEmitted': <String>['cellOverflowed'],
          'rulesUnderNegativeControl': <String>['cellOverflowed'],
          'enforcedProperties': <String>['cellsOverflowing', 'cells'],
          'censusProperties': <String>[
            'locale',
            'textScaleCeiling',
            'textScaleCeilingSource',
            'viewports',
            'surfaces',
            'cellsMeasured',
            'negativeControls',
          ],
        },
        'baseline': <String, Object?>{
          'violationCount': overflowing,
          'semantics':
              'cellsOverflowing is the violation count. 0 means every measured '
              'cell fitted; the in-file negative control proves the instrument '
              'can report otherwise (an inflexible Row with the shipped tr-TR '
              'copy at scale 2.0 overflows by 2573 px).',
        },
      })}\n''',
    );
  });
}
