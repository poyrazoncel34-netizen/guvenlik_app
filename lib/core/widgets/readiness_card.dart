import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/emergency_platform_service.dart';

/// One readiness item, in the order the user should fix them.
class ReadinessItem {
  const ReadinessItem({
    required this.label,
    required this.isOk,
    required this.onTap,
  });

  final String label;
  final bool isOk;
  final VoidCallback onTap;
}

/// The home screen's persistent setup state.
///
/// Two deliberate choices here:
///
/// 1. The headline is *factual and forward-looking* ("2 steps left"), never
///    evaluative ("setup incomplete"). This is a fear product; a red verdict at
///    the top of the first screen adds anxiety without adding a next action.
/// 2. The chips are ordered by consequence, not alphabetically. With no
///    emergency contact there is literally nothing to dial, so it comes first;
///    location and contacts are conveniences and come last.
class ReadinessCard extends StatelessWidget {
  const ReadinessCard({
    super.key,
    required this.locationGranted,
    required this.contactsGranted,
    required this.hasEmergencyContact,
    required this.readiness,
    required this.lastRehearsalAt,
    required this.onFixEmergencyContact,
    required this.onFixCallPermission,
    required this.onFixBackground,
    required this.onFixLocation,
    required this.onFixContacts,
    required this.onRunRehearsal,
    this.subscriptionVerificationStale = false,
  });

  final bool locationGranted;
  final bool contactsGranted;
  final bool hasEmergencyContact;
  final PlatformReadinessSnapshot? readiness;
  final DateTime? lastRehearsalAt;
  final VoidCallback onFixEmergencyContact;
  final VoidCallback onFixCallPermission;
  final VoidCallback onFixBackground;
  final VoidCallback onFixLocation;
  final VoidCallback onFixContacts;
  final VoidCallback onRunRehearsal;

  /// True when entitlement cannot be verified because the device is offline.
  ///
  /// Deliberately calm copy: under the IR-04 policy the emergency action keeps
  /// working in this state, so alarming the user would be both frightening and
  /// factually wrong. The notice exists so a subscriber is not surprised later,
  /// not to pressure them.
  final bool subscriptionVerificationStale;

  bool get _callPermissionOk => readiness?.callPermission ?? false;

  /// The call chip tracks [PlatformReadinessSnapshot.automaticCallReady], not
  /// just the permission: a granted permission on a device with no telephony or
  /// no dial handler still cannot place the call. Together with the background
  /// chip this makes "all chips green" equivalent to `criticalSafetyReady`, so
  /// the card can never report a complete setup the platform cannot honour.
  bool get _automaticCallReady => readiness?.automaticCallReady ?? false;
  bool get _backgroundOk => readiness?.backgroundAlertReady ?? false;
  bool get _criticalSafetyReady => readiness?.criticalSafetyReady ?? false;

  List<ReadinessItem> _items() => [
    ReadinessItem(
      label: 'emergency_contact'.tr(),
      isOk: hasEmergencyContact,
      onTap: onFixEmergencyContact,
    ),
    ReadinessItem(
      label: 'phone_call_permission'.tr(),
      isOk: _automaticCallReady,
      onTap: onFixCallPermission,
    ),
    ReadinessItem(
      label: 'background_readiness'.tr(),
      isOk: _backgroundOk,
      onTap: onFixBackground,
    ),
    ReadinessItem(
      label: 'location'.tr(),
      isOk: locationGranted,
      onTap: onFixLocation,
    ),
    ReadinessItem(
      label: 'contacts'.tr(),
      isOk: contactsGranted,
      onTap: onFixContacts,
    ),
  ];

  /// Plain dd.MM.yyyy: unambiguous in TR and free of locale data, so the card
  /// cannot fail to render because an intl locale was not loaded.
  static String formatRehearsalDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final missing = items.where((item) => !item.isOk).toList();
    // Belt and braces: the chips already cover it, but reading the snapshot's
    // own verdict means a future chip edit cannot quietly widen "complete".
    final allReady = missing.isEmpty && _criticalSafetyReady;

    final String title;
    final String subtitle;
    if (allReady) {
      title = 'ready'.tr();
      subtitle = 'system_ready_desc'.tr();
    } else if (missing.length == 1) {
      title = 'readiness_almost_title'.tr();
      subtitle = 'readiness_almost_desc'.tr(
        namedArgs: {'item': missing.first.label},
      );
    } else {
      title = 'setup_incomplete'.tr(
        namedArgs: {'count': missing.length.toString()},
      );
      subtitle = 'setup_incomplete_desc'.tr();
    }

    final staleNotice = subscriptionVerificationStale
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              container: true,
              label:
                  '${'subscription_verification_stale_title'.tr()}. '
                  '${'subscription_verification_stale_body'.tr()}',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 18,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'subscription_verification_stale_title'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'subscription_verification_stale_body'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (allReady ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allReady
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color: allReady ? AppColors.success : AppColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                _StatusChip(
                  label: item.label,
                  isOk: item.isOk,
                  onTap: item.onTap,
                ),
            ],
          ),
          if (!_callPermissionOk) ...[
            const SizedBox(height: 8),
            _note('call_permission_fallback_note'.tr()),
          ] else if (!_automaticCallReady) ...[
            const SizedBox(height: 8),
            _note('readiness_auto_call_note'.tr()),
          ],
          if (!_backgroundOk) ...[
            const SizedBox(height: 8),
            _note('readiness_background_note'.tr()),
          ],
          const SizedBox(height: 10),
          _RehearsalLine(
            lastRehearsalAt: lastRehearsalAt,
            onRunRehearsal: onRunRehearsal,
          ),
          staleNotice,
        ],
      ),
    );
  }

  Widget _note(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      height: 1.35,
      color: AppColors.textSecondary,
    ),
  );
}

/// The record, not a verdict: a date the user can check, or an honest "not yet"
/// that routes straight to the rehearsal instead of scolding them.
class _RehearsalLine extends StatelessWidget {
  const _RehearsalLine({
    required this.lastRehearsalAt,
    required this.onRunRehearsal,
  });

  final DateTime? lastRehearsalAt;
  final VoidCallback onRunRehearsal;

  @override
  Widget build(BuildContext context) {
    final recorded = lastRehearsalAt;
    final text = recorded == null
        ? 'readiness_no_rehearsal'.tr()
        : 'readiness_last_rehearsal'.tr(
            namedArgs: {'date': ReadinessCard.formatRehearsalDate(recorded)},
          );

    return InkWell(
      onTap: onRunRehearsal,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.isOk,
    required this.onTap,
  });

  final String label;
  final bool isOk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isOk ? AppColors.success : AppColors.warning;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
