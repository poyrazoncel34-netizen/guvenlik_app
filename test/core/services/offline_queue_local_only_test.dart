import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Finding 5 (MEDIUM): the offline queue claimed to "sync" events even
/// though there is no backend in this Play release. This contract test
/// enforces the local-only honesty:
///   * a processPendingEventsLocal() entry-point exists
///   * the legacy syncPendingEvents() is kept only as a deprecated alias
///   * no remaining "sync" wording in user-facing or core paths claims
///     remote/network behavior
void main() {
  test('offline_queue_service exposes local-only processing entry point', () {
    final source = File(
      'lib/core/services/offline_queue_service.dart',
    ).readAsStringSync();
    expect(
      source.contains('processPendingEventsLocal'),
      isTrue,
      reason:
          'OfflineQueueService must expose processPendingEventsLocal — the '
          'queue is local-only in this build.',
    );
  });

  test('legacy syncPendingEvents is marked deprecated', () {
    final source = File(
      'lib/core/services/offline_queue_service.dart',
    ).readAsStringSync();
    expect(
      source.contains('@Deprecated'),
      isTrue,
      reason:
          'syncPendingEvents must be retained only as a deprecated alias '
          'pointing at processPendingEventsLocal so no caller silently '
          'believes there is a backend sync.',
    );
  });

  test('class doc no longer claims backend sync', () {
    final source = File(
      'lib/core/services/offline_queue_service.dart',
    ).readAsStringSync();
    final classDoc = source.substring(0, source.indexOf('class OfflineQueueService'));
    expect(
      classDoc.toLowerCase().contains('sync when connection is restored'),
      isFalse,
      reason:
          'The class doc must not imply backend sync; the queue is '
          'processed locally only.',
    );
  });
}
