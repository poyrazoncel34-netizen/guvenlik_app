import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../motion.dart';

/// Whether the privacy mask should cover the app for a given lifecycle state.
///
/// Masks as soon as Android reports [AppLifecycleState.inactive]. Waiting for
/// paused/hidden is too late: Flutter disables frames in those states, so the
/// overlay's state change cannot be painted before Android captures the
/// recents thumbnail. The app content behind a system dialog is intentionally
/// masked as the privacy-safe tradeoff. [AppLifecycleState.detached] is
/// teardown and is excluded.
bool privacyShieldShouldMask(AppLifecycleState state) =>
    state == AppLifecycleState.inactive ||
    state == AppLifecycleState.paused ||
    state == AppLifecycleState.hidden;

class AppPrivacyShield extends StatefulWidget {
  final Widget child;

  /// Which stacking layer this shield occupies.
  ///
  /// [ZLayer] named five layers and, when measured, had ZERO consumers -- so
  /// "nothing renders above the shield" was a comment, not an invariant. Taking
  /// the layer as a parameter makes the claim checkable: the assert below fails
  /// if anyone ever mounts this at a layer that something else can sit above.
  final int layer;

  const AppPrivacyShield({
    super.key,
    required this.child,
    this.layer = ZLayer.shield,
  }) : assert(
         layer >= ZLayer.notice,
         'the privacy shield must sit above every notice surface',
       );

  @override
  State<AppPrivacyShield> createState() => _AppPrivacyShieldState();
}

class _AppPrivacyShieldState extends State<AppPrivacyShield>
    with WidgetsBindingObserver {
  bool _masked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldMask = privacyShieldShouldMask(state);
    if (_masked != shouldMask && mounted) {
      setState(() => _masked = shouldMask);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_masked,
          child: AnimatedOpacity(
            opacity: _masked ? 1 : 0,
            // Never animate *into* the privacy state. A fade leaves one or
            // more sensitive frames available to Android's recents snapshot.
            // The reveal may stay animated because it happens only after the
            // app is foreground-visible again.
            duration: _masked ? Duration.zero : Motion.fast,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ],
    );
  }
}
