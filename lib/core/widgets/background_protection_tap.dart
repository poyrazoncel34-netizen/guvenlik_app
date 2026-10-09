import 'dart:async';

import 'package:flutter/material.dart';

import '../services/emergency_platform_service.dart';

/// Makes a "protection degraded" notice open the exact-alarm settings (Y-14).
///
/// Revoking exact-alarm access during an armed Check-In killed the app and
/// deleted the session's exact alarms; the screen kept showing a protected
/// countdown. The notice now says so, and this is how the user turns the
/// protection back on: re-granting reschedules the exact alarms natively.
class BackgroundProtectionTap extends StatelessWidget {
  const BackgroundProtectionTap({
    super.key,
    required this.child,
    this.platform,
  });

  final Widget child;
  final EmergencyPlatformService? platform;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => unawaited(
        (platform ?? EmergencyPlatformService.instance)
            .requestExactAlarmPermission(),
      ),
      child: child,
    ),
  );
}
