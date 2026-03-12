import 'package:flutter/material.dart';

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
    final shouldMask =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
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
