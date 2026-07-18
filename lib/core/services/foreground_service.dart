// ============================================================================
// ACTIVE SAFETY SESSION STATUS (legacy filename kept to avoid import churn)
// ============================================================================
// The old implementation started a generic plugin foreground service whose
// Android code leaked a static partial wakelock and allowed one safety session
// to stop another. Deadline reliability now comes from native exact + inexact
// AlarmManager paths. This class only owns the user-visible ongoing status
// notification, with reference-counted session leases.
// ============================================================================

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'foreground_service_ownership.dart';
import 'notification_service.dart';

const String kForegroundChannelId = kServiceStatusChannelId;
const int kForegroundNotificationId = 7777;
const String _kFallbackBrand = 'KoruBeni';

class _StatusCopy {
  const _StatusCopy(this.title, this.body);

  final String title;
  final String body;
}

/// Reference-counted ongoing notification for active safety sessions.
///
/// Despite the legacy class/file name, this deliberately does not start an
/// Android foreground service and does not acquire a partial wakelock. Native
/// alarms own deadline delivery. Each caller must release the same [owner]
/// token that it acquired.
class KoruBeniForegroundService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final ForegroundServiceOwnership _ownership =
      ForegroundServiceOwnership();
  static final Map<String, _StatusCopy> _copyByOwner = <String, _StatusCopy>{};
  static Future<void> _operations = Future<void>.value();
  static bool _isConfigured = false;

  static Future<void> configure() async {
    if (kIsWeb || _isConfigured) return;
    try {
      final channel = AndroidNotificationChannel(
        kForegroundChannelId,
        _safeTr('notification_channel_service_name', _kFallbackBrand),
        description: _safeTr(
          'notification_channel_service_desc',
          _kFallbackBrand,
        ),
        importance: Importance.low,
      );
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      _isConfigured = true;
    } catch (e) {
      debugPrint('ActiveSafetyStatus: configure failed: $e');
    }
  }

  static Future<void> start({required String owner}) async {
    if (kIsWeb || owner.isEmpty) return;
    if (!_isConfigured) await configure();
    _ownership.acquire(owner);
    _copyByOwner.putIfAbsent(owner, _defaultCopy);
    await _enqueue(_refreshNotification);
  }

  static Future<void> stop({required String owner}) async {
    if (kIsWeb || owner.isEmpty) return;
    _ownership.release(owner);
    _copyByOwner.remove(owner);
    await _enqueue(_refreshNotification);
  }

  static Future<bool> isRunning() async => _ownership.owners.isNotEmpty;

  static void updateNotification({
    required String owner,
    required String title,
    required String content,
  }) {
    if (kIsWeb || !_ownership.owners.contains(owner)) return;
    _copyByOwner.remove(owner);
    _copyByOwner[owner] = _StatusCopy(title, content);
    unawaited(_enqueue(_refreshNotification));
  }

  static _StatusCopy _defaultCopy() => _StatusCopy(
    _safeTr('foreground_active_title', _kFallbackBrand),
    _safeTr('foreground_active_body', _kFallbackBrand),
  );

  static Future<void> _refreshNotification() async {
    try {
      if (_ownership.owners.isEmpty) {
        await _notifications.cancel(kForegroundNotificationId);
        return;
      }

      final activeCopy = _copyByOwner.values.isEmpty
          ? _defaultCopy()
          : _copyByOwner.values.last;
      await _notifications.show(
        kForegroundNotificationId,
        activeCopy.title,
        activeCopy.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            kForegroundChannelId,
            _safeTr('notification_channel_service_name', _kFallbackBrand),
            channelDescription: _safeTr(
              'notification_channel_service_desc',
              _kFallbackBrand,
            ),
            icon: 'ic_bg_service_small',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            visibility: NotificationVisibility.private,
            category: AndroidNotificationCategory.service,
          ),
        ),
      );
    } catch (e) {
      // POST_NOTIFICATIONS denial is an expected degraded state. Native alarm
      // delivery remains armed and readiness exposes the missing capability.
      debugPrint('ActiveSafetyStatus: notification update failed: $e');
    }
  }

  static Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operations.then<void>(
      (_) => operation(),
      onError: (_) => operation(),
    );
    _operations = next.catchError((Object _) {});
    return next;
  }
}

String _safeTr(String key, String fallback) {
  try {
    final translated = key.tr();
    if (translated == key || translated.isEmpty) return fallback;
    return translated;
  } catch (_) {
    return fallback;
  }
}
