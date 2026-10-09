// A-03 follow-up (closure 2026-10-09): the Safe Walk intro said the emergency
// flow is prepared "while the app is open". Safe Walk is a native session
// (CheckInService.safeWalk): when the time runs out a grace period starts, a
// warning is ATTEMPTED (best effort -- owner decision A-03), and the call flow
// starts when the grace ends, with the app open or not. The intro must say
// that, with the grace the code actually uses.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _catalogue(String locale) =>
    jsonDecode(File('assets/translations/$locale.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final grace = RegExp(
    r'static const int _gracePeriodSeconds = (\d+);',
  ).firstMatch(
    File('lib/core/services/check_in_service.dart').readAsStringSync(),
  )!.group(1)!;

  test('the Safe Walk intro names the grace and the best-effort warning, '
      'and no longer ties the flow to an open app', () {
    final tr = _catalogue('tr-TR')['safe_walk_desc'] as String;
    final en = _catalogue('en-US')['safe_walk_desc'] as String;
    final trFlat = tr.replaceAll('\n', ' ');
    final enFlat = en.replaceAll('\n', ' ');

    expect(trFlat, isNot(contains('açıkken')));
    expect(enFlat, isNot(contains('while the app is open')));
    expect(trFlat, contains('$grace saniyelik ek süre'));
    expect(enFlat, contains('$grace-second grace period'));
    expect(trFlat, contains('gösterilmeye çalışılır'));
    expect(enFlat, contains('warning is attempted'));
    expect(trFlat, contains('acil arama akışı başlatılır'));
    expect(enFlat, contains('emergency call flow starts'));
  });
}
