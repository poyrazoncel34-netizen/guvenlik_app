import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../constants/app_constants.dart';
import '../design_tokens.dart';

/// Tells a subscriber that erasing local data does NOT cancel their Play
/// subscription, and hands them the place that does (MP-23-015).
///
/// Why this is a truth problem and not a copy problem
/// --------------------------------------------------
/// The deletion screen lists what it erases: profile, contacts, consent log,
/// settings, PIN, location history. Every item on that list is local, and the
/// page reads as a complete account teardown. A Google Play subscription is
/// billed by Google, lives in the user's Play account and survives both the
/// erase and an uninstall — so a user who deletes everything in good faith
/// keeps getting charged. Saying nothing there is not a neutral omission; the
/// surrounding list makes the silence read as "and the subscription too".
///
/// Deliberately NOT a cancel button: this app cannot cancel a Play
/// subscription, and a control that looked like it could would be a worse lie
/// than the silence. It links to the Play screen that actually can.
class SubscriptionDeletionNotice extends StatelessWidget {
  const SubscriptionDeletionNotice({super.key, this.compact = false});

  /// Dialog variant: the sentence without the surrounding card, because a
  /// second card inside an AlertDialog reads as a different app.
  final bool compact;

  static Future<bool> openPlaySubscriptions() async {
    try {
      return await launchUrl(
        Uri.parse(AppConstants.googlePlaySubscriptionsUrl),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      // The user is mid-deletion. A failure to open a browser must not become
      // an exception on that path; the sentence has already told them where to
      // go, and it names Google Play rather than relying on the link.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Text(
      'subscription_survives_deletion_body'.tr(),
      style: TextStyle(
        fontSize: compact ? TypeScale.bodySmall : TypeScale.body,
        color: compact ? AppColors.textSecondary : Colors.white70,
        height: 1.45,
      ),
    );

    if (compact) return body;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.credit_card_rounded,
                color: AppColors.warning,
                size: IconSizes.dense,
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  'subscription_survives_deletion_title'.tr(),
                  style: const TextStyle(
                    fontSize: TypeScale.bodyLarge,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xxs),
          body,
          const SizedBox(height: Spacing.xs),
          Semantics(
            button: true,
            label: 'subscription_survives_deletion_action'.tr(),
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: openPlaySubscriptions,
                borderRadius: BorderRadius.circular(Radii.sm),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.xs,
                    vertical: Spacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'subscription_survives_deletion_action'.tr(),
                        style: const TextStyle(
                          fontSize: TypeScale.bodyLarge,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: Spacing.xxs),
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: AppColors.warning,
                        size: IconSizes.inline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
