import 'package:flutter/material.dart';

import '../../models/consent_record.dart';
import '../utils/permission_helper.dart';
import 'consent_gate_service.dart';

/// One place that answers "may this screen acquire the user's location?".
///
/// Two things have to agree, and they can disagree for a long time: the OS
/// permission, and the in-app KVKK consent. Withdrawing consent does not revoke
/// the OS grant, so a screen that only asked PermissionHelper kept acquiring GPS
/// from a user who had said no. MapPage did exactly that.
///
/// Lives here rather than in the screen because map_page.dart is on the file
/// size ratchet: the rule for those files is to extract, not to grow.
///
/// NEVER call this on the panic / SOS / check-in path. An emergency call runs
/// regardless of consent state (CLAUDE.md rule 1, and ConsentGateService's own
/// contract).
abstract final class LocationConsentGate {
  /// True when the user has both consented in-app and granted the OS
  /// permission. Shows the standard consent SnackBar when consent is missing,
  /// and the platform prompt when only the permission is missing.
  static Future<bool> ensureAllowed(BuildContext context) async {
    if (!ConsentGateService.requireConsent(
      context,
      ConsentRecord.typeLocation,
    )) {
      return false;
    }
    if (!context.mounted) return false;
    return PermissionHelper.requestLocationPermission(context);
  }
}
