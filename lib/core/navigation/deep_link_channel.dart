import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Collects a link recorded by MainActivity.
///
/// Read-and-clear on the native side, exactly like the quick-access request:
/// Dart asks on init and on resume, and one incoming link must produce at most
/// one navigation. Never throws — a platform failure or a missing channel
/// resolves to null, which simply means "no link", because an app that cannot
/// read a link must still start.
abstract final class DeepLinkChannel {
  static const MethodChannel channel = MethodChannel(
    'com.poyrazoncel.korubeni/deep_link',
  );

  /// The same bound the Kotlin side applies. Neither side trusts the other's
  /// check: a channel is a boundary, and a boundary that validates once
  /// validates in only one direction.
  static const int maxLength = 512;

  static Future<Uri?> consume() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await channel.invokeMethod<String>('consumeDeepLink');
      return parseRaw(raw);
    } on PlatformException catch (e) {
      debugPrint('DeepLinkChannel: consume failed: ${e.code}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Turns a raw platform string into a Uri, or null.
  ///
  /// Visible for testing so the untrusted-input handling is provable without a
  /// device: a malformed string must produce null, not an exception that takes
  /// the app down on launch.
  @visibleForTesting
  static Uri? parseRaw(String? raw) {
    if (raw == null || raw.isEmpty || raw.length > maxLength) return null;
    return Uri.tryParse(raw);
  }
}
