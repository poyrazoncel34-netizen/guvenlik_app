// ============================================================================
// QUICK PANIC REQUEST SERVICE
// ============================================================================
// Reads a panic request submitted by a quick-access surface (home-screen
// widget, Quick Settings tile) while Flutter was not attached.
//
// This is a hand-off, NOT a dispatch path. The surfaces carry no contact, no
// deadline and no entitlement decision; consuming a request only tells the app
// to walk the one arm path it already has (SubscriptionGate -> CountdownScreen
// -> PanicArmPolicy -> emergency_platform_service). Building a second way to
// arm would be the thing this design exists to avoid.
//
// Kept out of emergency_platform_service.dart deliberately: that file is on its
// size ratchet, and its channel is the safety kernel's. A read-and-clear of a
// UI hand-off does not belong on the kernel channel.
// ============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Which surface asked for a countdown.
enum QuickPanicSource { widget, tile }

abstract final class QuickPanicRequestService {
  static const MethodChannel channel = MethodChannel(
    'com.poyrazoncel.korubeni/quick_panic',
  );

  /// Reads and clears a pending request.
  ///
  /// Read-and-clear on the native side, so one press yields at most one
  /// countdown even though the host asks on both init and resume.
  ///
  /// Never throws: a platform failure or a missing channel resolves to null,
  /// which simply means "no quick-access request".
  static Future<QuickPanicSource?> consume() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await channel.invokeMethod<String>('consumePanicRequest');
      return _sourceFrom(raw);
    } on PlatformException catch (e) {
      debugPrint('QuickPanicRequest: consume failed: ${e.code}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Maps the native source label. An unrecognised value is discarded rather
  /// than treated as a request: platform-channel data is not trusted blindly.
  @visibleForTesting
  static QuickPanicSource? sourceFrom(String? raw) => _sourceFrom(raw);

  static QuickPanicSource? _sourceFrom(String? raw) {
    switch (raw) {
      case 'widget':
        return QuickPanicSource.widget;
      case 'tile':
        return QuickPanicSource.tile;
      default:
        return null;
    }
  }
}
