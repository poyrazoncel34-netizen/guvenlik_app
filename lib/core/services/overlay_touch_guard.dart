import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the window should do about touches arriving under another app's overlay.
///
/// The two active policies are NOT interchangeable, and the split is the point:
///
/// - [warn] is for GATEWAY surfaces -- the unlock PIN pad and the consent flow.
///   The user must get past them to reach the app at all, panic button included.
///   Discarding touches there could lock an owner out of their own safety app,
///   and "PIN'imi unuttum" is a touch too, so there would be no escape.
/// - [block] is for surfaces that are not gateways -- data export and local-data
///   reset. Refusing the action there is a safe answer.
///
/// `View.setFilterTouchesWhenObscured` (what [block] turns on) discards obscured
/// touches with NO opacity threshold, which is stricter than Android 12+'s own
/// untrusted-touch blocking. Screen dimmers and blue-light filters are the
/// overlays that difference reaches, and minSdk here is 29, where the platform
/// does none of it. That asymmetry is why gateways only warn.
enum OverlayTouchPolicy {
  off('off'),
  warn('warn'),
  block('block');

  const OverlayTouchPolicy(this.wire);

  final String wire;

  /// Higher wins when several surfaces are stacked.
  int get strength => switch (this) {
    OverlayTouchPolicy.off => 0,
    OverlayTouchPolicy.warn => 1,
    OverlayTouchPolicy.block => 2,
  };
}

/// Reference-counted overlay policy for the surfaces currently on screen.
///
/// Leases rather than a single setter, following
/// [ForegroundServiceOwnership]'s model: a dialog can open over a guarded
/// screen, and the dialog closing must not drop the screen's own protection.
/// The strongest live lease wins.
class OverlayTouchGuard {
  OverlayTouchGuard({MethodChannel? channel, bool? isAndroid})
    : _channel = channel ?? const MethodChannel(channelName),
      _isAndroid = isAndroid ?? Platform.isAndroid {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const String channelName = 'com.poyrazoncel.korubeni/overlay_guard';

  static final OverlayTouchGuard instance = OverlayTouchGuard();

  final MethodChannel _channel;
  final bool _isAndroid;
  final Map<String, OverlayTouchPolicy> _leases =
      <String, OverlayTouchPolicy>{};

  /// Raised when a touch arrived while an overlay covered this window, at most
  /// once per surface activation. Listeners show the user a warning; nothing
  /// here decides whether the touch landed.
  final ValueNotifier<OverlayTouchPolicy?> lastObscuredTouch =
      ValueNotifier<OverlayTouchPolicy?>(null);

  @visibleForTesting
  Map<String, OverlayTouchPolicy> get leases =>
      Map<String, OverlayTouchPolicy>.unmodifiable(_leases);

  /// The policy the window should be on, given every live lease.
  OverlayTouchPolicy get effectivePolicy => _leases.values.fold(
    OverlayTouchPolicy.off,
    (strongest, policy) =>
        policy.strength > strongest.strength ? policy : strongest,
  );

  /// Claims [owner]'s lease and pushes the resulting policy to the window.
  Future<void> acquire(String owner, OverlayTouchPolicy policy) async {
    if (owner.isEmpty || policy == OverlayTouchPolicy.off) return;
    _leases[owner] = policy;
    await _push();
  }

  /// Drops [owner]'s lease. Other owners keep theirs.
  Future<void> release(String owner) async {
    if (_leases.remove(owner) == null) return;
    await _push();
  }

  Future<void> _push() async {
    if (!_isAndroid) return;
    final policy = effectivePolicy;
    try {
      await _channel.invokeMethod<bool>('setPolicy', <String, Object?>{
        'policy': policy.wire,
      });
    } on PlatformException catch (e) {
      // A refused policy leaves the window as it was. It must not take down a
      // consent screen or a PIN pad: the guard is defence in depth, never the
      // reason a user cannot reach their safety app.
      debugPrint('OverlayTouchGuard: setPolicy refused: ${e.code}');
    } on MissingPluginException {
      // Host without the channel (tests, a future platform). Nothing to guard.
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onObscuredTouch') return;
    // The native side sends the policy that was in force. An unrecognised value
    // is still an overlay observation, so it is reported rather than dropped --
    // but it is not allowed to invent a policy.
    lastObscuredTouch.value = OverlayTouchPolicy.values
        .cast<OverlayTouchPolicy?>()
        .firstWhere(
          (policy) => policy?.wire == call.arguments,
          orElse: () => OverlayTouchPolicy.warn,
        );
  }

  @visibleForTesting
  Future<void> handleNativeCallForTesting(MethodCall call) =>
      _handleNativeCall(call);

  @visibleForTesting
  void resetForTesting() {
    _leases.clear();
    lastObscuredTouch.value = null;
  }
}
