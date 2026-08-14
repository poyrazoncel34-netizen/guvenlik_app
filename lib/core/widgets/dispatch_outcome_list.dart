import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../design_tokens.dart';
import '../services/dispatch_outcome.dart';

/// Renders one row per emergency dispatch target, with that target's own
/// outcome (MP-01-027).
///
/// Lives outside `emergency_call_screen.dart` because that screen sits at the
/// 800-line project limit, and because the same list is the honest surface for
/// any future dispatch entry point — the panic countdown and the Check-In
/// escalation already share it.
abstract final class DispatchOutcomeList {
  /// Returns the section widgets, or nothing at all.
  ///
  /// A dispatch in which every target was handed off says so in the header
  /// already; repeating a six-row all-green list there would bury the one case
  /// that matters. Anything else — partial, all-failed, or containing an
  /// unconfirmed target — is rendered.
  static List<Widget> build(DispatchOutcomeLedger? ledger) {
    if (ledger == null) return const <Widget>[];
    if (ledger.summary == DispatchOutcomeSummary.everyTargetReached) {
      return const <Widget>[];
    }
    final rows = ledger.results
        .where((r) => r.outcome != DispatchTargetOutcome.notAttempted)
        .toList(growable: false);
    if (rows.isEmpty) return const <Widget>[];

    return <Widget>[
      const SizedBox(height: Spacing.md),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'emergency_per_target_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: TypeScale.subtitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: Spacing.xxs),
            Text(
              ledger.isPartial
                  ? 'emergency_per_target_partial_body'.tr()
                  : 'emergency_per_target_body'.tr(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: TypeScale.body,
                height: 1.45,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            for (final row in rows) _row(row),
          ],
        ),
      ),
    ];
  }

  static Widget _row(DispatchTargetResult row) {
    final (icon, color) = switch (row.reachability) {
      DispatchReachability.reached => (
        Icons.check_circle_outline_rounded,
        AppColors.success,
      ),
      DispatchReachability.unknown => (
        Icons.help_outline_rounded,
        AppColors.warning,
      ),
      DispatchReachability.notReached => (
        Icons.cancel_rounded,
        AppColors.emergency,
      ),
      DispatchReachability.inapplicable => (
        Icons.remove_circle_outline_rounded,
        Colors.white38,
      ),
    };
    final label = row.target.labelKey.tr();
    final outcome = row.outcome.messageKey.tr();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
      child: Semantics(
        // One node per target, so a screen-reader user hears
        // "Acil durum bildirimi: Ayarlardan kapalı" as one phrase rather than
        // two disconnected fragments.
        label: '$label: $outcome',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: IconSizes.sm),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: TypeScale.bodyLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    outcome,
                    style: TextStyle(
                      color: color,
                      fontSize: TypeScale.body,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
