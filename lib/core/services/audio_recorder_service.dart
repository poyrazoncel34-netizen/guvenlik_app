import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A single recording entry with metadata.
class RecordingEntry {
  final String path;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  RecordingEntry({
    required this.path,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Service for recording audio evidence during emergencies.
class AudioRecorderService {
  static final AudioRecorderService _instance = AudioRecorderService._();
  static AudioRecorderService get instance => _instance;
  AudioRecorderService._();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  DateTime? _startTime;
  Timer? _maxDurationTimer;

  /// Maximum recording duration in minutes.
  static const int maxDurationMinutes = 30;

  /// Maximum number of stored recordings (oldest auto-deleted).
  static const int maxRecordings = 20;

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;
  Duration get recordingDuration => _startTime != null
      ? DateTime.now().difference(_startTime!)
      : Duration.zero;

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('AudioRecorder permission check failed: $e');
      return false;
    }
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    if (_isRecording) return true;

    try {
      final hasPerms = await hasPermission();
      if (!hasPerms) return false;

      // Enforce max recordings limit before starting a new one
      await _enforceRecordingLimit();

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${dir.path}/evidence_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentPath!,
      );

      _isRecording = true;
      _startTime = DateTime.now();

      // Auto-stop after max duration
      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(
        const Duration(minutes: maxDurationMinutes),
        () async {
          if (_isRecording) {
            debugPrint('AudioRecorder: max duration reached, auto-stopping');
            await stopRecording();
          }
        },
      );

      return true;
    } catch (e) {
      debugPrint('AudioRecorder start failed: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _startTime = null;
      return path ?? _currentPath;
    } catch (e) {
      debugPrint('AudioRecorder stop failed: $e');
      _isRecording = false;
      _startTime = null;
      return null;
    }
  }

  /// List all saved recordings, sorted newest first.
  Future<List<RecordingEntry>> getRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('evidence_') && f.path.endsWith('.m4a'))
          .toList();

      final entries = <RecordingEntry>[];
      for (final file in files) {
        final stat = await file.stat();
        entries.add(RecordingEntry(
          path: file.path,
          fileName: file.uri.pathSegments.last,
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ));
      }

      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (e) {
      debugPrint('AudioRecorder getRecordings failed: $e');
      return [];
    }
  }

  /// Delete a recording by path.
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('AudioRecorder deleteRecording failed: $e');
      return false;
    }
  }

  /// Get total storage used by recordings in bytes.
  Future<int> getStorageUsedBytes() async {
    final recordings = await getRecordings();
    return recordings.fold<int>(0, (sum, r) => sum + r.sizeBytes);
  }

  /// Enforce the max recordings limit by deleting oldest files.
  Future<void> _enforceRecordingLimit() async {
    final recordings = await getRecordings();
    if (recordings.length >= maxRecordings) {
      // Delete oldest first (list is sorted newest-first)
      for (int i = maxRecordings - 1; i < recordings.length; i++) {
        await deleteRecording(recordings[i].path);
      }
    }
  }

  void dispose() {
    _maxDurationTimer?.cancel();
    _recorder.dispose();
  }
}
