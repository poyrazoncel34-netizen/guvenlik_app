import 'dart:async';
import 'dart:convert';
import 'dart:math' show min, pow;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Emergency repository removed (offline-first)
import 'connectivity_service.dart';

/// Offline event queue - stores events locally when offline,
/// syncs when connection is restored.
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._();
  static OfflineQueueService get instance => _instance;
  OfflineQueueService._();

  static const String _queueKey = 'offline_event_queue';
  static const int _maxQueueSize = 100;
  bool _initialized = false;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Initialize and listen for connectivity changes to auto-sync.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _connectivitySubscription = ConnectivityService.instance.onStatusChange.listen((online) {
      if (online) {
        syncPendingEvents();
      }
    });

    if (ConnectivityService.instance.isOnline) {
      await syncPendingEvents();
    }
  }

  /// Add an event to the offline queue. Drops oldest if at max size.
  Future<void> enqueue(OfflineEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _loadQueue(prefs);
    if (queue.length >= _maxQueueSize) {
      queue.removeAt(0);
      debugPrint('OfflineQueue: Queue full, dropped oldest event');
    }
    queue.add(event.toJson());
    await prefs.setStringList(
      _queueKey,
      queue.map((e) => jsonEncode(e)).toList(),
    );
    debugPrint('OfflineQueue: Event queued (${queue.length} pending)');
  }

  /// Sync all pending events.
  Future<void> syncPendingEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _loadQueue(prefs);
    if (queue.isEmpty) return;

    debugPrint('OfflineQueue: Syncing ${queue.length} pending events...');
    final failedEvents = <Map<String, dynamic>>[];

    for (final eventMap in queue) {
      try {
        final event = OfflineEvent.fromJson(eventMap);

        // Drop events after max retries
        if (event.retryCount >= 10) {
          debugPrint('OfflineQueue: Dropping event after 10 retries: ${event.title}');
          continue;
        }

        // Exponential backoff check
        if (event.retryCount > 0 && event.lastAttemptAt != null) {
          final backoffMs = min(60000, 1000 * pow(2, event.retryCount - 1).toInt());
          final elapsed = DateTime.now().difference(event.lastAttemptAt!).inMilliseconds;
          if (elapsed < backoffMs) {
            failedEvents.add(eventMap);
            continue;
          }
        }

        final success = await _processEvent(event);
        if (!success) {
          final updated = event.copyWith(
            retryCount: event.retryCount + 1,
            lastAttemptAt: DateTime.now(),
          );
          failedEvents.add(updated.toJson());
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        debugPrint('OfflineQueue: Failed to process event: $e');
        failedEvents.add(eventMap);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    // Save back only failed events
    await prefs.setStringList(
      _queueKey,
      failedEvents.map((e) => jsonEncode(e)).toList(),
    );
    debugPrint(
      'OfflineQueue: Sync complete. ${failedEvents.length} remaining.',
    );
  }

  /// Get pending event count.
  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadQueue(prefs).length;
  }

  List<Map<String, dynamic>> _loadQueue(SharedPreferences prefs) {
    final raw = prefs.getStringList(_queueKey) ?? [];
    return raw
        .map((s) {
          try {
            return Map<String, dynamic>.from(jsonDecode(s) as Map);
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  /// Process a single event - sync to Firebase when back online.
  Future<bool> _processEvent(OfflineEvent event) async {
    debugPrint('OfflineQueue: Processing ${event.type} - ${event.title}');

    if (event.type == 'emergency') {
      // Offline-first: Emergency events are handled locally only
      debugPrint('OfflineQueue: Emergency event (local only, no cloud sync)');
      try {
        final data = event.data ?? {};
        final message =
            data['message'] as String? ?? event.description ?? 'default_emergency_message'.tr();
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        
        debugPrint('Emergency queued for offline processing');
        
        return true;
      } catch (e) {
        debugPrint('OfflineQueue: Emergency sync failed: $e');
        return false;
      }
    }

    return true;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _initialized = false;
  }
}

/// Represents an event that can be queued for offline processing.
class OfflineEvent {
  final String type;
  final String title;
  final String? description;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastAttemptAt;

  OfflineEvent({
    required this.type,
    required this.title,
    this.description,
    this.data,
    DateTime? createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
  }) : createdAt = createdAt ?? DateTime.now();

  OfflineEvent copyWith({
    int? retryCount,
    DateTime? lastAttemptAt,
  }) {
    return OfflineEvent(
      type: type,
      title: title,
      description: description,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'description': description,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
  };

  factory OfflineEvent.fromJson(Map<String, dynamic> json) => OfflineEvent(
    type: json['type'] as String? ?? 'unknown',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    data: json['data'] as Map<String, dynamic>?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    retryCount: json['retryCount'] as int? ?? 0,
    lastAttemptAt: json['lastAttemptAt'] != null
        ? DateTime.tryParse(json['lastAttemptAt'] as String)
        : null,
  );
}
