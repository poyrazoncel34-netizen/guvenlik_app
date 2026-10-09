// Y-14: the "protection degraded" notice on Check-In and Safe Walk is the one
// place a user sees that an armed session lost its exact alarms. It opens the
// exact-alarm settings, is announced as a button, and is a >=48 dp target.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/widgets/background_protection_tap.dart';

void main() {
  testWidgets('a tap opens the exact-alarm settings; it is a button', (
    tester,
  ) async {
    final calls = <String>[];
    const channel = MethodChannel('background-protection-tap');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackgroundProtectionTap(
            platform: EmergencyPlatformService.forTesting(
              methodChannel: channel,
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('degraded notice'),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('degraded notice')),
      containsSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'degraded notice',
      ),
    );
    final rect = tester.getRect(find.byType(BackgroundProtectionTap));
    expect(rect.height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('degraded notice'));
    await tester.pump();
    expect(calls, <String>['requestExactAlarmPermission']);
    semantics.dispose();
  });

  test('both safety-timer screens wrap their degraded notice in it', () {
    for (final path in <String>[
      'lib/screens/check_in_screen.dart',
      'lib/screens/safe_walk_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final notice = source.indexOf("'timer_scheduling_degraded'.tr()");
      final tap = source.lastIndexOf('BackgroundProtectionTap(', notice);
      expect(notice, isNot(-1), reason: path);
      expect(tap, isNot(-1), reason: '$path: the notice must open settings');
      // Enclosed, not merely nearby: the notice lies inside the wrapper's own
      // argument list (review M5 -- a distance check passed a wrapper that
      // closed before the notice).
      final open = tap + 'BackgroundProtectionTap'.length;
      expect(
        notice,
        inExclusiveRange(open, _closeOf(source, open)),
        reason: '$path: the wrapper must enclose the notice',
      );
    }
  });
}

/// Index just past the parenthesis matching the one at [open], skipping
/// string literals and line comments; -1 when unbalanced.
int _closeOf(String source, int open) {
  var depth = 0;
  String? quote;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (quote != null) {
      if (c == '\\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      final end = source.indexOf('\n', i);
      if (end == -1) return -1;
      i = end;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '(') {
      depth++;
    } else if (c == ')' && --depth == 0) {
      return i + 1;
    }
  }
  return -1;
}
