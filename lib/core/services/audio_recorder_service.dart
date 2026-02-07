import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Service for recording audio evidence during emergencies.
class AudioRecorderService {
  static final AudioRecorderService _instance = AudioRecorderService._();
  static AudioRecorderService get instance => _instance;
  AudioRecorderService._();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  DateTime? _startTime;

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;
  Duration get recordingDuration =>
      _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;

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

  void dispose() {
    _recorder.dispose();
  }
}
