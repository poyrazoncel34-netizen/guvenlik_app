// MP-05-025 — Turkish İ/i/ı/I case conversions.
//
// The hazard is real and asymmetric, so it is worth stating precisely.
//
// Turkish has FOUR letters where English has two: dotted i/İ and dotless ı/I.
// A Turkish-locale-aware lowercase turns "I" into "ı", not "i". That is correct
// for user text and CATASTROPHIC for machine identifiers: "XIAOMI".toLowerCase()
// under Turkish rules is "xıaomı", which does not contain "xiaomi", and the OEM
// battery-guide matcher would silently fall through to the generic guide on
// exactly the devices whose battery managers kill background work hardest.
//
// Dart's `String.toLowerCase()` is locale-INVARIANT (it implements the Unicode
// default case algorithm, not the Turkish tailoring). This app relies on that
// for every one of its casing sites — all of which operate on machine data:
// build flavour strings, HTTP header names, RevenueCat key prefixes, and
// Build.MANUFACTURER. None of them fold user-entered Turkish text.
//
// So this file asserts two things: that the invariant behaviour Dart gives us
// is the behaviour the matchers depend on, and that no user-facing text is
// case-folded anywhere (which is what would make the Turkish tailoring matter).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/oem_background_guide_service.dart';

void main() {
  group('Dart casing is locale-invariant, which is what the matchers need', () {
    test('dotted and dotless i round-trip the Unicode default way', () {
      // If Dart ever adopted Turkish tailoring by default, these change and the
      // OEM matcher below breaks. Pinned so that would be caught here first.
      expect('I'.toLowerCase(), 'i', reason: 'NOT "ı" — invariant, not Turkish');
      expect('i'.toUpperCase(), 'I', reason: 'NOT "İ" — invariant, not Turkish');
      // The genuinely Turkish characters still fold correctly.
      //
      // Measured, not assumed: Dart returns a bare 'i' for 'İ'.toLowerCase(),
      // NOT the Unicode-default 'i' + U+0307 combining dot. Recorded because a
      // future Dart change here would alter string LENGTH, and anything that
      // compares or truncates folded text would shift by a code unit.
      expect('İ'.toLowerCase(), 'i');
      expect('İ'.toLowerCase().length, 1);
      expect('ı'.toUpperCase(), 'I');
      expect('Ş'.toLowerCase(), 'ş');
      expect('Ğ'.toLowerCase(), 'ğ');
      expect('Ö'.toLowerCase(), 'ö');
      expect('Ü'.toLowerCase(), 'ü');
      expect('Ç'.toLowerCase(), 'ç');
    });

    test('the OEM matcher survives capitalised manufacturer strings', () {
      // Build.MANUFACTURER is reported upper-case by several vendors. Under
      // Turkish casing rules "XIAOMI" would lowercase to "xıaomı" and this
      // would fall through to generic — on the exact devices whose battery
      // managers are most aggressive.
      expect(
        OemBackgroundGuideService.vendorFrom('XIAOMI'),
        OemVendor.xiaomi,
        reason: 'the dotless-I trap, on the vendor that matters most here',
      );
      expect(OemBackgroundGuideService.vendorFrom('Xiaomi'), OemVendor.xiaomi);
      expect(OemBackgroundGuideService.vendorFrom('REDMI'), OemVendor.xiaomi);
      expect(OemBackgroundGuideService.vendorFrom('POCO'), OemVendor.xiaomi);
      expect(OemBackgroundGuideService.vendorFrom('HUAWEI'), OemVendor.huawei);
      expect(OemBackgroundGuideService.vendorFrom('HONOR'), OemVendor.huawei);
      expect(OemBackgroundGuideService.vendorFrom('SAMSUNG'), OemVendor.samsung);
      expect(OemBackgroundGuideService.vendorFrom('VIVO'), OemVendor.vivo);
      expect(OemBackgroundGuideService.vendorFrom('IQOO'), OemVendor.vivo);
      expect(
        OemBackgroundGuideService.vendorFrom('ONEPLUS'),
        OemVendor.oppoFamily,
      );
      // Harness precondition: the matcher must be able to say "generic", or
      // every assertion above could be a constant.
      expect(
        OemBackgroundGuideService.vendorFrom('Nothing'),
        OemVendor.generic,
      );
      expect(OemBackgroundGuideService.vendorFrom(''), OemVendor.generic);
      expect(OemBackgroundGuideService.vendorFrom('  '), OemVendor.generic);
    });

    test('Turkish letters in a manufacturer string do not crash the matcher',
        () {
      // Not expected in practice, but the matcher must not throw on any input
      // the platform hands it.
      for (final value in const ['ŞİRKET', 'ıIİi', 'ÇĞÖÜ']) {
        expect(
          () => OemBackgroundGuideService.vendorFrom(value),
          returnsNormally,
        );
      }
    });
  });

  test('no user-entered text is case-folded anywhere in lib/', () {
    // This is the guard that makes the invariant behaviour SAFE. Folding a
    // contact name or a search term would put the Turkish tailoring back on the
    // critical path, and Dart would then be doing the wrong thing.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(
        r'(\w+)\.to(?:Lower|Upper)Case\(\)',
      ).allMatches(source)) {
        final receiver = match.group(1)!;
        // The known machine-data receivers. Anything else is a new decision.
        const machineData = {
          'normalized', 'value', 'manufacturer', 'm', 'cacheControl',
          '_cachedManufacturer',
        };
        if (!machineData.contains(receiver)) {
          offenders.add('${entity.path}: ${match.group(0)}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'A new case-fold appeared. If its receiver is USER text, Dart\'s '
          'locale-invariant casing is wrong for Turkish (I -> i, not ı) and '
          'this needs a Turkish-aware comparison. If it is machine data, add '
          'the receiver to the allow-list above. Offenders: $offenders',
    );
  });
}
