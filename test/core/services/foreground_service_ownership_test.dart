import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/foreground_service_ownership.dart';

void main() {
  test('one session cannot stop protection owned by another session', () {
    final registry = ForegroundServiceOwnership();

    expect(registry.acquire('check_in'), ForegroundServiceTransition.start);
    expect(registry.acquire('safe_walk'), ForegroundServiceTransition.none);
    expect(registry.release('check_in'), ForegroundServiceTransition.none);
    expect(registry.owners, {'safe_walk'});
    expect(registry.release('safe_walk'), ForegroundServiceTransition.stop);
    expect(registry.owners, isEmpty);
  });

  test('duplicate acquire and release are idempotent', () {
    final registry = ForegroundServiceOwnership();

    expect(registry.acquire('countdown'), ForegroundServiceTransition.start);
    expect(registry.acquire('countdown'), ForegroundServiceTransition.none);
    expect(registry.release('unknown'), ForegroundServiceTransition.none);
    expect(registry.release('countdown'), ForegroundServiceTransition.stop);
    expect(registry.release('countdown'), ForegroundServiceTransition.none);
  });
}
