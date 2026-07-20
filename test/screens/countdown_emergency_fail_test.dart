// CountdownScreen fail-safe kaynak kontratı: arama akışı başarısız olduğunda
// (callResult.isFailed) bloklayıcı "elle ara" diyaloğu gösterilmeli; sessiz
// SnackBar + Navigator.pop ASLA. Bu dosya, F1 denetimi kapsamında sabit-bool
// karşılaştıran totolojik halinden gerçek kaynak kontratına çevrildi.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Directory.current.path.endsWith('test')
      ? Directory.current.parent.path
      : Directory.current.path;

  late String source;
  late String executeBody;
  late String makeCallBody;

  setUpAll(() {
    source = File('$base/lib/screens/countdown_screen.dart').readAsStringSync();
    final makeStart = source.indexOf('Future<void> _makeEmergencyCall()');
    final execStart = source.indexOf('Future<void> _executeEmergency()');
    final execEnd = source.indexOf('Future<void> _showBlockingFailure(');
    expect(makeStart, isNot(-1), reason: '_makeEmergencyCall must exist');
    expect(execStart, isNot(-1), reason: '_executeEmergency must exist');
    expect(execEnd, isNot(-1), reason: '_showBlockingFailure must exist');
    makeCallBody = source.substring(makeStart, execStart);
    executeBody = source.substring(execStart, execEnd);
  });

  group('CountdownScreen — acil çağrı başarısız durumu', () {
    test('isFailed dalı bloklayıcı fail-safe diyaloğunu çağırır', () {
      final failedIdx = executeBody.indexOf('if (callResult.isFailed)');
      expect(
        failedIdx,
        isNot(-1),
        reason: '_executeEmergency must branch on callResult.isFailed',
      );
      final failSafeIdx = executeBody.indexOf(
        '_showBlockingFailure',
        failedIdx,
      );
      final branchEnd = executeBody.indexOf('return;', failedIdx);
      expect(failSafeIdx, isNot(-1));
      expect(branchEnd, isNot(-1));
      expect(
        failSafeIdx < branchEnd,
        isTrue,
        reason:
            'fail dalı return etmeden ÖNCE bloklayıcı diyaloğu '
            'göstermeli — sessiz çıkış yasak',
      );
    });

    test('fail dalında sessiz Navigator.pop yok', () {
      final failedIdx = executeBody.indexOf('if (callResult.isFailed)');
      final branchEnd = executeBody.indexOf('return;', failedIdx);
      final branch = executeBody.substring(failedIdx, branchEnd);
      expect(
        branch.contains('Navigator.pop'),
        isFalse,
        reason:
            'Başarısızlıkta kullanıcı "uygulama kapandı" sanmamalı; '
            'pop yerine bloklayıcı diyalog gösterilir',
      );
    });

    test('catch-all fail-safe: dispatch çökse bile diyalog gösterilir', () {
      final catchIdx = makeCallBody.indexOf('catch (');
      expect(
        catchIdx,
        isNot(-1),
        reason: '_makeEmergencyCall must have a catch-all guard',
      );
      final failSafeIdx = makeCallBody.indexOf(
        '_showBlockingFailure',
        catchIdx,
      );
      expect(
        failSafeIdx,
        isNot(-1),
        reason: 'Beklenmeyen exception da bloklayıcı fail-safe ile bitmeli',
      );
      expect(
        makeCallBody.contains(
          r"debugPrint('CountdownScreen: Emergency execution crashed: $e')",
        ),
        isFalse,
        reason: 'Raw exception details must not reach local debug output.',
      );
    });
  });
}
