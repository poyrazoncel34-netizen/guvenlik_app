// MP-72-005 / 007 / 008 / 009 / 011 / 012 / 013 / 014 — the visual-polish
// checks that are decidable WITHOUT looking at a screen.
//
// The audit had these as "verified by eye on one device at one density, on a
// subset of screens", which is not evidence. Several of them are not really
// eye checks at all — icon family, asset resolution, image fit and corner
// radius are facts about the codebase, and facts can be asserted. The ones that
// genuinely need pixels (baseline alignment, shadow clipping, gradient banding)
// are verified on the emulator across densities and recorded in
// docs/audit/device-verification-2026-08-13-r2.md.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('MP-72-009 / MP-72-008: icons come from one family', () {
    final rounded = <String>[];
    final outlined = <String>[];
    final sharp = <String>[];
    final base = <String>[];

    for (final file in dartFiles()) {
      for (final match
          in RegExp(r'Icons\.([A-Za-z0-9_]+)').allMatches(file.readAsStringSync())) {
        final name = match.group(1)!;
        if (name.endsWith('_rounded')) {
          rounded.add(name);
        } else if (name.endsWith('_outlined')) {
          outlined.add(name);
        } else if (name.endsWith('_sharp')) {
          sharp.add(name);
        } else {
          base.add(name);
        }
      }
    }

    // Harness precondition: icons must actually have been found.
    expect(rounded.length, greaterThan(100));

    expect(
      sharp,
      isEmpty,
      reason: 'the sharp family is not used anywhere; mixing three families is '
          'the stroke/weight mismatch this row is about',
    );
    // Rounded is the house family and must stay dominant. The outlined and
    // base uses below are deliberate, not drift.
    expect(
      rounded.length / (rounded.length + outlined.length + base.length),
      greaterThan(0.9),
      reason: 'rounded must remain the house icon family',
    );

    // The deliberate exceptions, enumerated so a NEW one has to be justified
    // rather than absorbed.
    const allowedOutlined = {
      // Material's own selected/unselected nav convention.
      'home_outlined', 'map_outlined', 'settings_outlined',
      // Keypad backspace, identical across all three PIN surfaces.
      'backspace_outlined',
      // Lighter-weight glyphs where a filled shape would read as a warning.
      'shield_outlined', 'description_outlined', 'verified_user_outlined',
      'notifications_outlined', 'phone_outlined', 'photo_library_outlined',
    };
    expect(
      outlined.toSet().difference(allowedOutlined),
      isEmpty,
      reason:
          'a new outlined icon must either join the house family or be added '
          'here with a reason',
    );

    const allowedBase = {
      'info_outline', 'call', 'copy', 'my_location',
      'radio_button_checked', 'radio_button_off',
    };
    expect(outlined.toSet().difference(allowedOutlined), isEmpty);
    expect(base.toSet().difference(allowedBase), isEmpty);
  });

  test('MP-72-011 / MP-72-012: the only image is cropped, not distorted', () {
    final imageSites = <String>[];
    for (final file in dartFiles()) {
      final source = file.readAsStringSync();
      for (final match in RegExp(
        r'Image\.(file|asset|network|memory)',
      ).allMatches(source)) {
        imageSites.add('${file.path}: ${match.group(0)}');
      }
    }
    expect(
      imageSites,
      hasLength(1),
      reason:
          'This app renders exactly one image: the fake-call avatar. A new '
          'image site needs its own aspect-ratio and cropping decision.',
    );
    expect(imageSites.single, contains('fake_call_screen.dart'));

    final fakeCall =
        File('lib/screens/fake_call_screen.dart').readAsStringSync();
    expect(
      fakeCall,
      contains('fit: BoxFit.cover'),
      reason:
          'cover crops to fill; contain or fill would letterbox or STRETCH a '
          'user-chosen photo, which is the distortion this row is about',
    );
    expect(
      fakeCall,
      contains('ClipOval('),
      reason: 'the avatar is circular, so the crop must be circular too',
    );
    // Square target box: a non-square box inside a ClipOval crops unevenly.
    expect(fakeCall, contains('width: 130,'));
    expect(fakeCall, contains('height: 130,'));
  });

  test('MP-72-013 / MP-72-014: shipped assets are high-resolution sources', () {
    // Flutter generates the density buckets from these, so what matters is that
    // the SOURCE is large enough that no bucket has to upscale.
    final icon = File('assets/icon/app_icon.png');
    final splash = File('assets/icon/splash_shield.png');
    expect(icon.existsSync(), isTrue);
    expect(splash.existsSync(), isTrue);

    // PNG header: width/height are big-endian 32-bit ints at offsets 16 and 20.
    ({int width, int height}) pngSize(File f) {
      final bytes = f.readAsBytesSync();
      expect(
        bytes.length,
        greaterThan(24),
        reason: 'harness precondition: ${f.path} is not a readable PNG',
      );
      int at(int o) =>
          (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3];
      return (width: at(16), height: at(20));
    }

    final iconSize = pngSize(icon);
    final splashSize = pngSize(splash);

    // xxxhdpi launcher icons are 192px; 512 is the Play listing requirement.
    expect(
      iconSize.width,
      greaterThanOrEqualTo(512),
      reason: 'a launcher icon source below 512px upscales on Play and xxxhdpi',
    );
    expect(iconSize.width, iconSize.height, reason: 'launcher icons are square');
    expect(
      splashSize.width,
      greaterThanOrEqualTo(768),
      reason: 'the splash mark is centred on the largest screens too',
    );
    expect(splashSize.width, splashSize.height);
  });

  test('MP-72-005: corner radius consistency is enforced, not eyeballed', () {
    // The real answer to "inconsistent corner radius" is the token ratchet.
    final ratchet =
        File('test/core/design_token_ratchet_test.dart').readAsStringSync();
    expect(ratchet, contains("kind: 'radius'"));
    expect(ratchet, contains('Radii.scale.toSet()'));
    // And the theme, which decides the radius for every themed component.
    final theme = File('lib/core/app_theme.dart').readAsStringSync();
    expect(theme, contains('Radii.'));
  });
}
