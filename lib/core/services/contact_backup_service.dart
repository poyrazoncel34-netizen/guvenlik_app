import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'contact_service.dart';
import '../utils/emergency_number_validator.dart';

/// Why a contact backup could not be made or read. The UI maps each value to
/// one translated message; nothing here carries file or contact content.
enum ContactBackupFailure {
  passwordTooShort,
  noContacts,
  tooLarge,
  notABackup,
  unsupportedVersion,
  wrongPasswordOrDamaged,
  invalidContent,
  writeFailed,
}

class ContactBackupException implements Exception {
  const ContactBackupException(this.failure);

  final ContactBackupFailure failure;

  @override
  String toString() => 'ContactBackupException(${failure.name})';
}

/// User-held, password-encrypted copy of the emergency contacts.
///
/// The manifest sets allowBackup=false and excludes every domain from cloud
/// backup and device transfer, deliberately (docs/release/dr_and_key_custody.md):
/// under the duress model a cloud copy is a liability. This file is the one
/// way across to a new phone, and the user holds it.
///
/// What it carries is an allowlist: name, phone and the primary flag of each
/// contact, nothing else. The PIN, lockout counters, consent log, fake-call
/// data and history never enter it -- the payload is built from
/// [EmergencyContact] fields only, and [decode] refuses any other key.
///
/// The password is NOT the app PIN. A 4-6 digit PIN guarding a file that can
/// be copied off the device falls to an offline search in seconds; the backup
/// password has a length floor and goes through PBKDF2-HMAC-SHA256 into
/// AES-256-GCM. The whole header is authenticated data, so an edited
/// iteration count or salt fails the tag instead of being trusted.
class ContactBackupService {
  const ContactBackupService({
    this.iterations = defaultIterations,
    this.minAcceptedIterations = minimumIterations,
  });

  static const String formatTag = 'korubeni-contact-backup';
  static const int formatVersion = 1;
  static const int minPasswordLength = 8;

  /// OWASP's 2023 floor for PBKDF2-HMAC-SHA256. The derivation runs in a
  /// background isolate, so the cost is a short wait, never a frozen screen.
  static const int defaultIterations = 310000;

  /// The floor a file may ask for, pinned apart from [defaultIterations] so a
  /// later raise of the default does not lock users out of older backups.
  static const int minimumIterations = 310000;

  /// Upper bound on what a file may ask for. Without it a crafted header could
  /// keep the uncancellable derivation busy for minutes before the tag check
  /// ever runs; about three times the default bounds that wait.
  static const int maxAcceptedIterations = 1000000;

  /// Control and invisible formatting characters (C0/C1 controls, zero-width
  /// marks, bidi embeddings/overrides/isolates, BOM). A name carrying them can
  /// render as a different name in the contact list, so a file holding one is
  /// refused rather than cleaned.
  static final RegExp _hiddenCharacters = RegExp(
    '[\\u0000-\\u001F\\u007F-\\u009F\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2069\\uFEFF]',
  );

  /// A real backup of five contacts is well under 2 KiB; anything near this
  /// is not one, and is refused before it is parsed.
  static const int maxFileBytes = 64 * 1024;

  static const String _kdfName = 'pbkdf2-hmac-sha256';
  static const String _cipherName = 'aes-256-gcm';
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const int _maxNameLength = 200;
  static const int _maxPhoneLength = 32;

  final int iterations;
  final int minAcceptedIterations;

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Encrypts the contacts currently stored on this device.
  Future<Uint8List> exportCurrentContacts(String password) async {
    _checkPassword(password);
    final contacts = await ContactService.getContactRecords();
    if (contacts.isEmpty) {
      throw const ContactBackupException(ContactBackupFailure.noContacts);
    }
    return _seal(_payloadOf(contacts), password);
  }

  static Map<String, Object?> _payloadOf(List<EmergencyContact> contacts) {
    return {
      'contacts': [
        for (final c in contacts)
          {
            'name': c.name.trim(),
            'phone': c.phone.trim(),
            'isPrimary': c.isPrimary,
          },
      ],
    };
  }

  Future<Uint8List> _seal(Object payload, String password) async {
    final random = Random.secure();
    final salt = _randomBytes(random, _saltLength);
    final nonce = _randomBytes(random, _nonceLength);
    final header = <String, Object?>{
      'format': formatTag,
      'version': formatVersion,
      'kdf': {
        'name': _kdfName,
        'iterations': iterations,
        'salt': base64Encode(salt),
      },
      'cipher': {'name': _cipherName, 'nonce': base64Encode(nonce)},
    };
    final aad = _aadOf(header);
    final clear = utf8.encode(jsonEncode(payload));
    final rounds = iterations;
    final sealed = await Isolate.run(() async {
      final key = await _deriveKey(password, salt, rounds);
      final box = await AesGcm.with256bits().encrypt(
        clear,
        secretKey: key,
        nonce: nonce,
        aad: aad,
      );
      return [
        Uint8List.fromList(box.cipherText),
        Uint8List.fromList(box.mac.bytes),
      ];
    });
    final file = <String, Object?>{
      ...header,
      'cipher': {
        'name': _cipherName,
        'nonce': base64Encode(nonce),
        'mac': base64Encode(sealed[1]),
      },
      'ciphertext': base64Encode(sealed[0]),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(file)));
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Authenticates, decrypts and validates [bytes]. Touches no storage: a file
  /// that fails anywhere here leaves the device exactly as it was.
  Future<List<EmergencyContact>> decode(
    Uint8List bytes,
    String password,
  ) async {
    final payload = await _open(bytes, password);
    return _validatedContacts(payload);
  }

  Future<Object?> _open(Uint8List bytes, String password) async {
    if (bytes.length > maxFileBytes) {
      throw const ContactBackupException(ContactBackupFailure.tooLarge);
    }
    final envelope = _parseEnvelope(bytes);
    final clear = await Isolate.run(() async {
      final key = await _deriveKey(
        password,
        envelope.salt,
        envelope.iterations,
      );
      try {
        return await AesGcm.with256bits().decrypt(
          SecretBox(
            envelope.cipherText,
            nonce: envelope.nonce,
            mac: Mac(envelope.mac),
          ),
          secretKey: key,
          aad: envelope.aad,
        );
      } on SecretBoxAuthenticationError {
        return null;
      }
    });
    if (clear == null) {
      throw const ContactBackupException(
        ContactBackupFailure.wrongPasswordOrDamaged,
      );
    }
    try {
      return jsonDecode(utf8.decode(clear));
    } on FormatException {
      throw const ContactBackupException(ContactBackupFailure.invalidContent);
    }
  }

  _Envelope _parseEnvelope(Uint8List bytes) {
    const notABackup = ContactBackupException(ContactBackupFailure.notABackup);
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw notABackup;
    }
    if (json is! Map<String, dynamic> || json['format'] != formatTag) {
      throw notABackup;
    }
    if (json['version'] != formatVersion) {
      throw const ContactBackupException(
        ContactBackupFailure.unsupportedVersion,
      );
    }
    final kdf = json['kdf'];
    final cipher = json['cipher'];
    final cipherText = json['ciphertext'];
    if (kdf is! Map<String, dynamic> ||
        cipher is! Map<String, dynamic> ||
        cipherText is! String ||
        kdf['name'] != _kdfName ||
        cipher['name'] != _cipherName) {
      throw notABackup;
    }
    final rounds = kdf['iterations'];
    if (rounds is! int ||
        rounds < minAcceptedIterations ||
        rounds > maxAcceptedIterations) {
      throw notABackup;
    }
    final salt = _base64OrNull(kdf['salt']);
    final nonce = _base64OrNull(cipher['nonce']);
    final mac = _base64OrNull(cipher['mac']);
    final body = _base64OrNull(cipherText);
    if (salt == null ||
        salt.length != _saltLength ||
        nonce == null ||
        nonce.length != _nonceLength ||
        mac == null ||
        mac.length != _macLength ||
        body == null ||
        body.isEmpty) {
      throw notABackup;
    }
    final header = <String, Object?>{
      'format': formatTag,
      'version': formatVersion,
      'kdf': {'name': _kdfName, 'iterations': rounds, 'salt': kdf['salt']},
      'cipher': {'name': _cipherName, 'nonce': cipher['nonce']},
    };
    return _Envelope(
      salt: salt,
      nonce: nonce,
      mac: mac,
      cipherText: body,
      iterations: rounds,
      aad: _aadOf(header),
    );
  }

  /// All-or-nothing: one bad entry refuses the whole file. A partial import
  /// would leave the user believing their list came across when it did not.
  static List<EmergencyContact> _validatedContacts(Object? payload) {
    const invalid = ContactBackupException(ContactBackupFailure.invalidContent);
    if (payload is! Map<String, dynamic> ||
        payload.length != 1 ||
        payload['contacts'] is! List) {
      throw invalid;
    }
    final items = payload['contacts'] as List<dynamic>;
    if (items.isEmpty || items.length > AppConstants.maxEmergencyContacts) {
      throw invalid;
    }
    final contacts = <EmergencyContact>[];
    for (final item in items) {
      if (item is! Map<String, dynamic> ||
          item.length != 3 ||
          item['name'] is! String ||
          item['phone'] is! String ||
          item['isPrimary'] is! bool) {
        throw invalid;
      }
      final name = (item['name'] as String).trim();
      final phone = (item['phone'] as String).trim();
      if (name.isEmpty ||
          name.length > _maxNameLength ||
          _hiddenCharacters.hasMatch(name) ||
          phone.length > _maxPhoneLength) {
        throw invalid;
      }
      final callable = EmergencyNumberValidator.normalizedCallableTargetOrNull(
        phone,
      );
      if (callable == null || contacts.any((c) => c.matchesPhone(callable))) {
        throw invalid;
      }
      contacts.add(
        EmergencyContact(
          name: name,
          phone: phone,
          isPrimary: item['isPrimary'] as bool,
        ),
      );
    }
    if (contacts.where((c) => c.isPrimary).length > 1) throw invalid;
    return List.unmodifiable(contacts);
  }

  /// Replaces the stored contacts with [contacts] (from [decode]) and confirms
  /// the result against secure storage, not against the write's return.
  ///
  /// On any failure the previous list -- an empty one included -- is written
  /// back before the failure is reported, so an interrupted restore does not
  /// leave a half-imported list behind a "restore failed" message.
  Future<int> restore(List<EmergencyContact> contacts) async {
    final List<EmergencyContact> previous;
    try {
      previous = await ContactService.getContactRecords();
    } on Exception {
      throw const ContactBackupException(ContactBackupFailure.writeFailed);
    }
    try {
      await _write(contacts);
      // Drop the warm cache so the check reads secure storage itself: a write
      // that "succeeded" without landing still reads back from the cache.
      ContactService.resetCache();
      final stored = await ContactService.getContactRecords();
      if (!_sameList(stored, contacts)) {
        throw const ContactBackupException(ContactBackupFailure.writeFailed);
      }
      return stored.length;
    } on ContactBackupException {
      await _rollBack(previous);
      rethrow;
    } on Exception {
      // PlatformException from the keystore, or anything else the store
      // raises: same answer, the old list goes back.
      await _rollBack(previous);
      throw const ContactBackupException(ContactBackupFailure.writeFailed);
    }
  }

  /// ContactService has no single "replace with these flags" write: the list
  /// write keeps the CURRENT primary, and the primary is set by a second write.
  /// The order is chosen for the moment between them, should the process die
  /// there. Primary first: the device then holds the old list plus the
  /// backup's primary AS primary, so a panic still has the number the user
  /// chose. List first would leave the new list with no primary at all, and a
  /// safety flow without a selected primary does not call.
  static Future<void> _write(List<EmergencyContact> contacts) async {
    final primary = contacts.where((c) => c.isPrimary).firstOrNull;
    if (primary == null) {
      await ContactService.saveContactRecords(contacts);
      await ContactService.clearPrimaryEmergencyContact();
      return;
    }
    await ContactService.savePrimaryEmergencyContact(
      name: primary.name,
      phone: primary.phone,
    );
    // The primary set above is now the current one, so the list write keeps
    // it and lands the final state in one step.
    await ContactService.saveContactRecords(contacts);
  }

  static Future<void> _rollBack(List<EmergencyContact> previous) async {
    try {
      await _write(previous);
    } on Exception {
      // The store refused the restore AND the roll-back. Nothing further can
      // be done from here; the caller reports writeFailed and the contacts
      // screen shows whatever secure storage now holds.
    } finally {
      ContactService.resetCache();
    }
  }

  /// Order, names, callable numbers and the primary flag must all match.
  static bool _sameList(
    List<EmergencyContact> stored,
    List<EmergencyContact> wanted,
  ) {
    final expected = [
      ...wanted.where((c) => c.isPrimary),
      ...wanted.where((c) => !c.isPrimary),
    ];
    if (stored.length != expected.length) return false;
    for (var i = 0; i < stored.length; i++) {
      if (stored[i].name != expected[i].name ||
          !stored[i].matchesPhone(expected[i].phone) ||
          stored[i].isPrimary != expected[i].isPrimary) {
        return false;
      }
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static void _checkPassword(String password) {
    if (password.length < minPasswordLength) {
      throw const ContactBackupException(ContactBackupFailure.passwordTooShort);
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int rounds,
  ) {
    return Pbkdf2.hmacSha256(
      iterations: rounds,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  static List<int> _aadOf(Map<String, Object?> header) =>
      utf8.encode(jsonEncode(header));

  static Uint8List _randomBytes(Random random, int length) =>
      Uint8List.fromList(
        List<int>.generate(length, (_) => random.nextInt(256)),
      );

  static Uint8List? _base64OrNull(Object? value) {
    if (value is! String) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }

  @visibleForTesting
  Future<Uint8List> encryptPayloadForTesting(Object payload, String password) =>
      _seal(payload, password);

  @visibleForTesting
  Future<Map<String, dynamic>> decryptPayloadForTesting(
    Uint8List bytes,
    String password,
  ) async => (await _open(bytes, password)) as Map<String, dynamic>;
}

class _Envelope {
  const _Envelope({
    required this.salt,
    required this.nonce,
    required this.mac,
    required this.cipherText,
    required this.iterations,
    required this.aad,
  });

  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List mac;
  final Uint8List cipherText;
  final int iterations;
  final List<int> aad;
}
