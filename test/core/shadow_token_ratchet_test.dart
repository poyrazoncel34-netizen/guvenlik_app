// MP-03-009 -- the shadow system, as a token rather than a convention.
//
// WHAT WAS MEASURED FIRST. 27 `BoxShadow(` sites in lib/, with FOURTEEN distinct
// blur radii (20 x6, 8 x4, 6 x4, 24 x2, 12 x2, then 60, 40, 30, 28, 18, 15, 14
// and 10 once each) and five distinct offsets. `elevation:` was already
// consistent -- 29 sites, two values -- which is why MP-03-010 passed while
// MP-03-009 did not: depth in this app is drawn by hand, not by Material.
//
// WHAT THE SCALE IS NOT. It is not an exercise in reducing the count. Seven of
// those shadows are ANIMATED: they compute blur and spread from an animation
// value every frame (`blurRadius: 30 + (glowValue * 30)`). A static rung cannot
// express an interpolation, and collapsing them would delete motion the app
// deliberately has -- the splash logo's breath, the onboarding icon pulse, the
// panic button's ring, the siren's colour lerp. They are exempt BY NAME below,
// each with the reason, so the exemption cannot quietly grow.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/app_colors.dart';
import 'package:guvenlik_app/core/design_tokens.dart';

/// Files still building a `BoxShadow` by hand, and why each is allowed to.
///
/// This is an allow-list with reasons, not a suppression: a new file appearing
/// here has to justify itself in review.
const Map<String, String> kHandRolledShadowReasons = <String, String>{
  'lib/core/design_tokens.dart':
      'The scale itself has to construct the shadows it defines.',
  'lib/screens/splash_screen.dart':
      'ANIMATED. Two stacked glows whose blur and spread are driven by the '
      'logo breathing animation (blur 30 + glow*30 and 60 + glow*40).',
  'lib/screens/onboarding_screen.dart':
      'ANIMATED. Icon pulse: blur 20 + pulse*20, spread pulse*5.',
  'lib/widgets/panic_button.dart':
      'ANIMATED. The arming ring grows with the hold progress '
      '(blur 15 + value*10).',
  'lib/widgets/siren_dialog.dart':
      'ANIMATED. The glow colour is a Color.lerp driven by the siren cycle.',
  'lib/screens/emergency_call_screen.dart':
      'ANIMATED. Header glow keyed to the call state.',
  'lib/screens/battery_optimization_wizard.dart':
      'The colour is computed per step from the step status, so the shadow is '
      'data-driven rather than a fixed rung.',
  'lib/screens/countdown_screen.dart':
      'One animated ring plus one neutral shadow at a deliberately reduced '
      'alpha (AppColors.shadow @0.2) so it reads on the countdown backdrop.',
  'lib/screens/map_page.dart':
      'Shadows over photographic map tiles: three remaining neutral-alpha '
      'shadows tuned against tile imagery rather than the app background.',
  'lib/screens/home_page.dart':
      'Quick-action card tint at blur 12 / alpha 0.06 -- a real near-miss of '
      'Shadows.tintedCard (blur 14 / alpha 0.08). Left alone deliberately: '
      'moving it would change a rendered value on the primary screen for a '
      '2 px gain. Recorded rather than smoothed.',
  'lib/screens/safe_walk_screen.dart':
      'Accent glow at blur 12 vs Shadows.brandGlow blur 20 -- too far apart to '
      'migrate without a visible change. Same treatment as home_page.',
};

List<File> libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  group('the scale exists and is a scale', () {
    test('every static rung is a single, distinct shadow', () {
      expect(Shadows.staticScale, hasLength(3));
      final Set<String> signatures = Shadows.staticScale
          .map((List<BoxShadow> rung) => rung.single)
          .map((BoxShadow s) => '${s.color}|${s.blurRadius}|${s.offset}')
          .toSet();
      expect(
        signatures,
        hasLength(3),
        reason: 'two rungs with identical values would not be a scale',
      );
    });

    test('the rungs ascend', () {
      expect(
        Shadows.resting.single.blurRadius,
        lessThan(Shadows.raised.single.blurRadius),
      );
      expect(
        Shadows.raised.single.blurRadius,
        lessThan(Shadows.overlay.single.blurRadius),
      );
      expect(
        Shadows.raised.single.offset.dy,
        lessThan(Shadows.overlay.single.offset.dy),
        reason:
            'depth is carried by offset as well as blur; an "overlay" that sat '
            'closer to the surface than a "raised" card would invert the '
            'visual hierarchy the scale exists to express.',
      );
    });

    test('the tinted builders carry the tint and stay softer than the glow',
        () {
      final BoxShadow glow = Shadows.brandGlow(AppColors.primary).single;
      final BoxShadow tint = Shadows.tintedCard(AppColors.primary).single;
      expect(glow.color.a, greaterThan(tint.color.a),
          reason: 'a CTA glow must read stronger than a card tint');
      expect(glow.blurRadius, greaterThan(tint.blurRadius));
    });
  });

  group('migration', () {
    test('the token is actually used, not merely defined', () {
      final int users = libDartFiles()
          .where((File f) => !f.path.endsWith('design_tokens.dart'))
          .where((File f) => f.readAsStringSync().contains('Shadows.'))
          .length;
      expect(
        users,
        greaterThanOrEqualTo(8),
        reason:
            'A token nobody references is a worse outcome than the convention '
            'it replaced: it looks like a system while the shadows stay ad hoc.',
      );
    });

    test('no file builds a hand-rolled BoxShadow without a recorded reason',
        () {
      final List<String> unlisted = <String>[];
      for (final File file in libDartFiles()) {
        if (!file.readAsStringSync().contains('BoxShadow(')) continue;
        if (!kHandRolledShadowReasons.containsKey(file.path)) {
          unlisted.add(file.path);
        }
      }
      expect(
        unlisted,
        isEmpty,
        reason:
            'Use Shadows.resting / raised / overlay / brandGlow / tintedCard, '
            'or add the file to kHandRolledShadowReasons WITH the reason. '
            'Unlisted: $unlisted',
      );
    });

    test('the allow-list stays honest', () {
      for (final MapEntry<String, String> entry
          in kHandRolledShadowReasons.entries) {
        final File file = File(entry.key);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'stale entry: ${entry.key} no longer exists',
        );
        expect(
          file.readAsStringSync().contains('BoxShadow('),
          isTrue,
          reason:
              '${entry.key} no longer hand-rolls a shadow; remove the '
              'exemption so it does not outlive its reason.',
        );
      }
    });
  });
}
