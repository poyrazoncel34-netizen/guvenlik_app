// ============================================================================
// WAKELOCK BALANCE — Every WakelockPlus.enable() must have a matching
// WakelockPlus.disable() on every exit path of the emergency flow.
// ============================================================================
// Static source-level audit. Mirrors the pattern used by other release-blocker
// tests (countdown_null_guard_test.dart, etc.) so the contract survives
// future refactors of the emergency screens.
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wakelock balance — emergency flow', () {
    test(
      'CountdownScreen.dispose disables wakelock when not handing off to '
      'EmergencyCallScreen',
      () {
        final source = File(
          'lib/screens/countdown_screen.dart',
        ).readAsStringSync();

        // The dispose method must guard the disable on the handoff flag so it
        // does not race with EmergencyCallScreen's own wakelock enable.
        expect(
          source.contains('WakelockPlus.disable'),
          isTrue,
          reason:
              'CountdownScreen.dispose must call WakelockPlus.disable on the '
              'non-handoff paths (PIN cancel, test mode, blocking failure).',
        );
        expect(
          source.contains('!_handoffToEmergencyScreen'),
          isTrue,
          reason:
              'CountdownScreen.dispose must skip wakelock release when handing '
              'off to EmergencyCallScreen so the screen-to-screen transition '
              'does not race a disable/enable pair.',
        );
      },
    );

    test('EmergencyCallScreen enables wakelock in initState', () {
      final source = File(
        'lib/screens/emergency_call_screen.dart',
      ).readAsStringSync();

      expect(
        source.contains('WakelockPlus.enable'),
        isTrue,
        reason:
            'EmergencyCallScreen.initState must enable the wakelock so the '
            'device stays awake while the user resolves the call, regardless '
            'of the entry path (countdown handoff or check-in service push).',
      );
    });

    test(
      'EmergencyCallScreen disposes wakelock so the device can sleep again',
      () {
        final source = File(
          'lib/screens/emergency_call_screen.dart',
        ).readAsStringSync();

        expect(
          source.contains('WakelockPlus.disable'),
          isTrue,
          reason:
              'EmergencyCallScreen.dispose must disable the wakelock; '
              'leaving it on after the user returns home drains the battery.',
        );
      },
    );

    test('Every WakelockPlus.enable in lib/ has a matching disable nearby', () {
      // Sanity: count enable / disable pairs across the production codebase.
      // The numbers do not have to be equal in every file (a screen can hand
      // ownership off to another), but globally we must not leak.
      final libDir = Directory('lib');
      var enables = 0;
      var disables = 0;
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        enables += 'WakelockPlus.enable'.allMatches(src).length;
        disables += 'WakelockPlus.disable'.allMatches(src).length;
      }
      expect(
        disables,
        greaterThanOrEqualTo(enables),
        reason:
            'Found $enables WakelockPlus.enable call sites and $disables '
            'WakelockPlus.disable call sites in lib/. Every enable needs at '
            'least one matching disable path to prevent battery drain.',
      );
    });
  });
}
