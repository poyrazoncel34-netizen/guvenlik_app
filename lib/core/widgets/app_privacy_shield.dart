import 'package:flutter/material.dart';

/// Whether the privacy mask should cover the app for a given lifecycle state.
///
/// Masks ONLY for genuine backgrounding — paused/hidden, which the recents /
/// app-switcher thumbnail routes through. Deliberately does NOT mask on
/// [AppLifecycleState.inactive]: that fires while a view is still visible
/// (system dialogs, the screenshot/overlay capture flow, split-screen, an
/// incoming call), and masking there would black out screenshots and dialogs.
/// [AppLifecycleState.detached] is teardown and is also excluded.
bool privacyShieldShouldMask(AppLifecycleState state) =>
    state == AppLifecycleState.paused || state == AppLifecycleState.hidden;

class AppPrivacyShield extends StatefulWidget {
  final Widget child;

  const AppPrivacyShield({super.key, required this.child});

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
            duration: const Duration(milliseconds: 120),
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ],
    );
  }
}
