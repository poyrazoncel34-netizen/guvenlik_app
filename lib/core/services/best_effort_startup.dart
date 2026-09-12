import 'dart:async';

/// Bounds the wait for optional startup work without changing critical boot
/// authorization. Timeout does not cancel plugin work; its eventual failure is
/// still consumed, and it cannot change the critical bootstrap decision.
Future<void> initializeBestEffortServices(
  Iterable<Future<void> Function()> operations, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  await Future.wait(
    operations.map((operation) async {
      try {
        await Future<void>.sync(operation).timeout(timeout);
      } catch (_) {
        // Optional feature degradation must not suppress the first app frame.
        // Raw plugin exceptions may contain personal data; do not log them.
      }
    }),
  );
}
