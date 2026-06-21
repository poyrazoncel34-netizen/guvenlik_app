import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// D5: the offline banner could stick because ConnectivityService read
/// connectivity once at cold start and only updated on a *change* event. The
/// service must re-validate when the app returns to the foreground so a stale
/// offline reading self-corrects.
void main() {
  test('ConnectivityService re-checks connectivity on resume', () {
    final src = File(
      'lib/core/services/connectivity_service.dart',
    ).readAsStringSync();
    expect(
      src.contains('with WidgetsBindingObserver'),
      isTrue,
      reason: 'service must observe the app lifecycle',
    );
    expect(
      src.contains('didChangeAppLifecycleState'),
      isTrue,
    );
    expect(
      src.contains('AppLifecycleState.resumed'),
      isTrue,
      reason: 'must re-validate on resume',
    );
    // resume handler must re-query connectivity
    final resumeIdx = src.indexOf('AppLifecycleState.resumed');
    final refreshAfterResume = src.indexOf('_refresh()', resumeIdx);
    expect(
      refreshAfterResume,
      isNot(-1),
      reason: 'resume must trigger a connectivity refresh',
    );
    expect(src.contains('addObserver(this)'), isTrue);
    expect(src.contains('removeObserver(this)'), isTrue);
  });
}
