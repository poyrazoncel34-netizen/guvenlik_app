import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import 'emergency_platform_service.dart';
import 'local_database_service.dart';

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

class AudioRecorderService {
  static final AudioRecorderService _instance = AudioRecorderService._();
  static AudioRecorderService get instance => _instance;
  AudioRecorderService._();

  static const int maxDurationMinutes = 30;
  static const int maxRecordings = 50;
  static const int maxStorageBytes = 1024 * 1024 * 1024;
  static const String _audioKeyStorageKey = 'recordings_encryption_key';

  final AudioRecorder _recorder = AudioRecorder();
  final SecureStorage _secureStorage = serviceLocator<SecureStorage>();
  final LocalDatabaseService _databaseService =
      serviceLocator<LocalDatabaseService>();

  bool _isRecording = false;
  String? _currentPath;
  DateTime? _startTime;
  Timer? _maxDurationTimer;

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;
  Duration get recordingDuration => _startTime != null
      ? DateTime.now().difference(_startTime!)
      : Duration.zero;

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('AudioRecorder permission check failed: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    if (_isRecording) return true;

    try {
      final hasPerms = await hasPermission();
      if (!hasPerms) return false;

      await _migrateLegacyRecordings();
      await _enforceRecordingLimit();
      await EmergencyPlatformService.instance.startRecordingSession();

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${dir.path}/evidence_raw_$timestamp.m4a';

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

      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(
        const Duration(minutes: maxDurationMinutes),
        () async {
          if (_isRecording) {
            await stopRecording();
          }
        },
      );

      return true;
    } catch (e) {
      debugPrint('AudioRecorder start failed: $e');
      _isRecording = false;
      await EmergencyPlatformService.instance.stopRecordingSession();
      return false;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    try {
      final rawPath = await _recorder.stop() ?? _currentPath;
      _isRecording = false;
      _startTime = null;
      await EmergencyPlatformService.instance.stopRecordingSession();

      if (rawPath == null || rawPath.isEmpty) {
        return null;
      }

      return _encryptAndStore(rawPath);
    } catch (e) {
      debugPrint('AudioRecorder stop failed: $e');
      _isRecording = false;
      _startTime = null;
      await EmergencyPlatformService.instance.stopRecordingSession();
      return null;
    }
  }

  Future<List<RecordingEntry>> getRecordings() async {
    await _migrateLegacyRecordings();
    final db = await _databaseService.database;
    final rows = await db.query('recordings', orderBy: 'created_at DESC');
    return rows
        .map(
          (row) => RecordingEntry(
            path: row['encrypted_path']?.toString() ?? '',
            fileName: row['file_name']?.toString() ?? '',
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            sizeBytes: row['size_bytes'] as int? ?? 0,
          ),
        )
        .where((entry) => entry.path.isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> deleteRecording(String path) async {
    try {
      final db = await _databaseService.database;
      await db.delete(
        'recordings',
        where: 'encrypted_path = ?',
        whereArgs: [path],
      );
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      debugPrint('AudioRecorder deleteRecording failed: $e');
      return false;
    }
  }

  Future<int> getStorageUsedBytes() async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) AS total FROM recordings',
    );
    return rows.first['total'] as int? ?? 0;
  }

  Future<String?> prepareShareFile(RecordingEntry entry) async {
    try {
      final encryptedFile = File(entry.path);
      if (!await encryptedFile.exists()) {
        return null;
      }

      final bytes = await encryptedFile.readAsBytes();
      if (bytes.length <= 12) {
        return null;
      }

      final ivBytes = Uint8List.sublistView(bytes, 0, 12);
      final cipherBytes = Uint8List.sublistView(bytes, 12);
      final key = await _getOrCreateEncryptionKey();
      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(key, mode: encrypt_lib.AESMode.gcm),
      );
      final decrypted = encrypter.decryptBytes(
        encrypt_lib.Encrypted(cipherBytes),
        iv: encrypt_lib.IV(ivBytes),
      );

      final tempDir = await getTemporaryDirectory();
      final sharePath =
          '${tempDir.path}/share_${entry.fileName.replaceAll('.kbe', '.m4a')}';
      final shareFile = File(sharePath);
      await shareFile.writeAsBytes(decrypted, flush: true);
      return shareFile.path;
    } catch (e) {
      debugPrint('AudioRecorder prepareShareFile failed: $e');
      return null;
    }
  }

  Future<String> _encryptAndStore(String rawPath) async {
    final rawFile = File(rawPath);
    final rawBytes = await rawFile.readAsBytes();
    final key = await _getOrCreateEncryptionKey();
    final iv = encrypt_lib.IV.fromSecureRandom(12);
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.gcm),
    );
    final encrypted = encrypter.encryptBytes(rawBytes, iv: iv);

    final encryptedBytes = Uint8List(iv.bytes.length + encrypted.bytes.length)
      ..setAll(0, iv.bytes)
      ..setAll(iv.bytes.length, encrypted.bytes);

    final encryptedPath = rawPath
        .replaceAll('evidence_raw_', 'evidence_')
        .replaceAll('.m4a', '.kbe');
    final encryptedFile = File(encryptedPath);
    await encryptedFile.writeAsBytes(encryptedBytes, flush: true);
    await rawFile.delete();

    final db = await _databaseService.database;
    await db.insert('recordings', {
      'encrypted_path': encryptedPath,
      'file_name': encryptedFile.uri.pathSegments.last,
      'created_at': DateTime.now().toIso8601String(),
      'size_bytes': await encryptedFile.length(),
    });

    await _enforceRecordingLimit();
    return encryptedPath;
  }

  Future<encrypt_lib.Key> _getOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _audioKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return encrypt_lib.Key.fromBase64(existing);
    }

    final random = Random.secure();
    final bytes = Uint8List(32);
    for (var index = 0; index < bytes.length; index++) {
      bytes[index] = random.nextInt(256);
    }
    final encoded = base64Encode(bytes);
    await _secureStorage.write(key: _audioKeyStorageKey, value: encoded);
    return encrypt_lib.Key.fromBase64(encoded);
  }

  Future<void> _migrateLegacyRecordings() async {
    final dir = await getApplicationDocumentsDirectory();
    final legacyFiles = dir
        .listSync()
        .whereType<File>()
        .where(
          (file) =>
              file.path.contains('evidence_') && file.path.endsWith('.m4a'),
        )
        .toList(growable: false);
    if (legacyFiles.isEmpty) {
      return;
    }

    final db = await _databaseService.database;
    final knownRows = await db.query('recordings', columns: ['encrypted_path']);
    final knownPaths = knownRows
        .map((row) => row['encrypted_path']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .toSet();
    for (final legacyFile in legacyFiles) {
      final encryptedPath = legacyFile.path
          .replaceAll('.m4a', '.kbe')
          .replaceAll('evidence_raw_', 'evidence_');
      if (knownPaths.contains(encryptedPath)) {
        continue;
      }
      try {
        await _encryptAndStore(legacyFile.path);
      } catch (e) {
        debugPrint('AudioRecorder migrate legacy failed: $e');
      }
    }
  }

  Future<void> _enforceRecordingLimit() async {
    final recordings = await getRecordings();
    var totalSize = recordings.fold<int>(
      0,
      (sum, entry) => sum + entry.sizeBytes,
    );
    final overflow = <RecordingEntry>[];

    if (recordings.length > maxRecordings) {
      overflow.addAll(recordings.sublist(maxRecordings));
    }

    for (final entry in recordings) {
      if (totalSize <= maxStorageBytes) {
        break;
      }
      if (overflow.contains(entry)) {
        continue;
      }
      overflow.add(entry);
      totalSize -= entry.sizeBytes;
    }

    for (final entry in overflow.toSet()) {
      await deleteRecording(entry.path);
    }
  }

  void dispose() {
    _maxDurationTimer?.cancel();
    _recorder.dispose();
  }
}
