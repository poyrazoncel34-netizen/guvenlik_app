import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Salted, iterated hash for the safety PIN.
///
/// The PIN used to be stored so that it could be read back. Platform-backed
/// encryption protects it at rest, but anything running as this app's UID (a
/// rooted device, a forensic extraction, malware with keystore access) then
/// recovers the PIN itself — and users commonly reuse their device PIN.
/// A one-way hash removes that: the app only ever needs to *verify*.
///
/// Honest limit: the secret is 4 digits, so the search space is ~10k
/// candidates. The work factor buys time and denies instant reuse disclosure;
/// it is not secrecy against a determined offline attacker. The duress model
/// still rests on the PIN never being written down or spoken.
///
/// [iterations] is chosen from measurement, not folklore: PBKDF2-HMAC-SHA256
/// in pure Dart costs ~172 ms per derivation at 100k on a 2024 laptop, so
/// roughly half a second on a mid-range phone. Verification sits on the
/// cancel-an-armed-session path, where seconds are a safety cost — this is the
/// ceiling that path can absorb, not the highest number available.
class PinHasher {
  PinHasher._();

  static const String _prefix = 'pbkdf2_sha256';
  static const int defaultIterations = 100000;
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  /// True when [stored] is a raw PIN written by a pre-hash build.
  static bool isLegacyPlaintext(String stored) =>
      stored.isNotEmpty && !stored.startsWith('$_prefix\$');

  static String encode(
    String pin, {
    List<int>? salt,
    int iterations = defaultIterations,
  }) {
    final effectiveSalt = salt ?? _randomSalt();
    final derived = _pbkdf2(
      utf8.encode(pin),
      effectiveSalt,
      iterations,
      _keyLength,
    );
    return <String>[
      _prefix,
      '$iterations',
      base64Url.encode(effectiveSalt),
      base64Url.encode(derived),
    ].join(r'$');
  }

  /// Constant-time verification. Returns false for any malformed record
  /// rather than throwing: a corrupt PIN record must read as "does not
  /// match", never as an unhandled failure on the unlock screen.
  static bool matches({required String stored, required String candidate}) {
    if (candidate.isEmpty || stored.isEmpty) return false;
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _prefix) return false;

    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) return false;

    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64Url.decode(parts[2]);
      expected = base64Url.decode(parts[3]);
    } on FormatException {
      return false;
    }
    if (salt.isEmpty || expected.isEmpty) return false;

    final derived = _pbkdf2(
      utf8.encode(candidate),
      salt,
      iterations,
      expected.length,
    );
    return _constantTimeEquals(derived, expected);
  }

  /// Length-independent, early-exit-free comparison.
  static bool _constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final leftByte = index < left.length ? left[index] : 0;
      final rightByte = index < right.length ? right[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }

  static List<int> _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(_saltLength, (_) => random.nextInt(256));
  }

  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int length,
  ) {
    final hmac = Hmac(sha256, password);
    final output = BytesBuilder();
    var blockIndex = 1;
    while (output.length < length) {
      final block = <int>[
        ...salt,
        (blockIndex >> 24) & 0xff,
        (blockIndex >> 16) & 0xff,
        (blockIndex >> 8) & 0xff,
        blockIndex & 0xff,
      ];
      var current = hmac.convert(block).bytes;
      final accumulator = List<int>.from(current);
      for (var round = 1; round < iterations; round++) {
        current = hmac.convert(current).bytes;
        for (var i = 0; i < accumulator.length; i++) {
          accumulator[i] ^= current[i];
        }
      }
      output.add(accumulator);
      blockIndex++;
    }
    return Uint8List.fromList(output.toBytes().sublist(0, length));
  }
}
