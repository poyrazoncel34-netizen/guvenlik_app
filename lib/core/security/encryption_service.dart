import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// AES-CBC encryption service with random IV per encrypt call.
/// IV is prepended to ciphertext so decrypt can extract it.
class EncryptionService {
  encrypt_lib.Encrypter? _encrypter;
  bool _ready = false;

  static const int _ivLength = 16;

  EncryptionService() {
    final keyBase64 = AppConstants.encryptionKeyBase64;
    if (keyBase64.isEmpty) {
      debugPrint('WARNING: ENCRYPTION_KEY not set. Encryption disabled.');
      return;
    }
    try {
      final key = encrypt_lib.Key.fromBase64(keyBase64);
      _encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(key));
      _ready = true;
    } catch (e) {
      debugPrint('EncryptionService init failed: $e');
    }
  }

  bool get isReady => _ready;

  /// Generate a cryptographically secure random IV.
  encrypt_lib.IV _generateRandomIV() {
    final random = Random.secure();
    final bytes = Uint8List(_ivLength);
    for (int i = 0; i < _ivLength; i++) {
      bytes[i] = random.nextInt(256);
    }
    return encrypt_lib.IV(bytes);
  }

  /// Encrypts [value] with a random IV prepended to the output.
  /// Output format: base64(IV + ciphertext)
  String encrypt(String value) {
    if (!_ready || _encrypter == null) {
      return base64Encode(utf8.encode(value));
    }
    final iv = _generateRandomIV();
    final encrypted = _encrypter!.encrypt(value, iv: iv);
    // Prepend IV bytes to ciphertext bytes
    final combined = Uint8List(_ivLength + encrypted.bytes.length);
    combined.setRange(0, _ivLength, iv.bytes);
    combined.setRange(_ivLength, combined.length, encrypted.bytes);
    return base64Encode(combined);
  }

  /// Decrypts [encrypted] by extracting the prepended IV.
  /// Also handles legacy data encrypted with static IV (plain base64 ciphertext).
  String decrypt(String encrypted) {
    if (!_ready || _encrypter == null) {
      try {
        return utf8.decode(base64Decode(encrypted));
      } catch (_) {
        return encrypted;
      }
    }
    try {
      final combined = base64Decode(encrypted);
      if (combined.length <= _ivLength) {
        // Too short to contain IV + ciphertext, return as-is
        return utf8.decode(combined);
      }
      // Extract IV from first 16 bytes
      final ivBytes = Uint8List.sublistView(combined, 0, _ivLength);
      final cipherBytes = Uint8List.sublistView(combined, _ivLength);
      final iv = encrypt_lib.IV(ivBytes);
      final decrypted = _encrypter!.decrypt(
        encrypt_lib.Encrypted(cipherBytes),
        iv: iv,
      );
      return decrypted;
    } catch (_) {
      // Fallback: try legacy static IV decryption for backward compatibility
      try {
        final legacyIV = encrypt_lib.IV.fromLength(_ivLength);
        final decrypted = _encrypter!.decrypt(
          encrypt_lib.Encrypted.fromBase64(encrypted),
          iv: legacyIV,
        );
        return decrypted;
      } catch (_) {
        // Last resort: try plain base64
        try {
          return utf8.decode(base64Decode(encrypted));
        } catch (_) {
          return encrypted;
        }
      }
    }
  }
}
