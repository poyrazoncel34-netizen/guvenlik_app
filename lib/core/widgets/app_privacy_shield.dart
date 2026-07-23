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

/// Shared, process-local pixel barrier. Backgrounding closes it synchronously;
/// only the lifecycle authentication coordinator may reopen it. This prevents
/// the resumed frame from racing ahead of the async PIN-route decision.
class AppPrivacyBarrierController extends ValueNotifier<bool> {
  AppPrivacyBarrierController._() : super(false);

  static final AppPrivacyBarrierController instance =
      AppPrivacyBarrierController._();

  @visibleForTesting
  AppPrivacyBarrierController.forTesting() : super(false);

  void obscure() {
    if (!value) value = true;
  }

  void reveal() {
    if (value) value = false;
  }
}

class AppPrivacyShield extends StatefulWidget {
  final Widget child;
  final AppPrivacyBarrierController? controller;

  const AppPrivacyShield({super.key, required this.child, this.controller});

  @override
  State<AppPrivacyShield> createState() => _AppPrivacyShieldState();
}

class _AppPrivacyShieldState extends State<AppPrivacyShield>
    with WidgetsBindingObserver {
  late final AppPrivacyBarrierController _controller =
      widget.controller ?? AppPrivacyBarrierController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (privacyShieldShouldMask(state)) _controller.obscure();
    // Resumed deliberately does not reveal. AppLifecycleHandler first decides
    // whether a PIN route is required and then opens this barrier.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller,
      builder: (context, masked, _) => Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          IgnorePointer(
            ignoring: !masked,
            child: AnimatedOpacity(
              opacity: masked ? 1 : 0,
              duration: masked
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
