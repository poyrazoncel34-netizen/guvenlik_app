import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../services/arm_remedy.dart';
import '../services/emergency_platform_service.dart';
import '../services/emergency_readiness_service.dart';
import 'arm_remedy_launcher.dart';

/// The blocked-arm dialog's fix button (2026-11-02).
///
/// It looks exactly like the exact-alarm button it replaces (Y-11). What is
/// new is that it reads readiness itself. The dialog stays up while the user
/// is in Settings, so the refusal code it was opened with is stale the moment
/// they fix it: for a device capability the button shows the FIRST one still
/// missing in native order, and nothing once all four are on. The manual call
/// beside it stays either way.
class ArmRemedyButton extends StatefulWidget {
  const ArmRemedyButton({
    super.key,
    required this.remedy,
    this.launcher = const ArmRemedyLauncher(),
    this.readiness,
  });

  /// The fix for the refusal the dialog was opened with.
  final ArmRemedy remedy;
  final ArmRemedyLauncher launcher;

  /// Injected in tests; production uses the singleton.
  final EmergencyReadinessService? readiness;

  @override
  State<ArmRemedyButton> createState() => _ArmRemedyButtonState();
}

class _ArmRemedyButtonState extends State<ArmRemedyButton>
    with WidgetsBindingObserver {
  /// Only snapshots that arrived after this button appeared. The service's
  /// cached state may predate the refusal (it said "granted" while native
  /// refused), and a superseded probe returns that cached state.
  PlatformReadinessSnapshot? _live;

  EmergencyReadinessService get _readiness =>
      widget.readiness ?? EmergencyReadinessService.instance;

  bool get _tracksReadiness => widget.remedy.isCapability;

  @override
  void initState() {
    super.initState();
    if (!_tracksReadiness) return;
    WidgetsBinding.instance.addObserver(this);
    _readiness.addListener(_onReadiness);
    unawaited(_readiness.checkReadiness());
  }

  @override
  void dispose() {
    if (_tracksReadiness) {
      _readiness.removeListener(_onReadiness);
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  void _onReadiness() {
    if (mounted) setState(() => _live = _readiness.lastState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Settings. The Activity result says nothing reliable about a
    // toggle, so the platform is asked again.
    if (state == AppLifecycleState.resumed) {
      unawaited(_readiness.checkReadiness());
    }
  }

  ArmRemedy? get _current {
    final live = _live;
    if (!_tracksReadiness || live == null || !live.isKnown) {
      return widget.remedy;
    }
    final missing = ArmRemedy.missingCapabilities(live);
    return missing.isEmpty ? null : missing.first;
  }

  Future<void> _apply(ArmRemedy remedy) async {
    await widget.launcher.apply(context, remedy);
    // A runtime permission dialog may not pause the app at all.
    if (mounted && _tracksReadiness) unawaited(_readiness.checkReadiness());
  }

  @override
  Widget build(BuildContext context) {
    final remedy = _current;
    if (remedy == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _apply(remedy),
        icon: const Icon(Icons.settings_rounded, size: IconSizes.listItem),
        label: Text(remedy.labelKey.tr()),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
