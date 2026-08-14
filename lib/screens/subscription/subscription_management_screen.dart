// ============================================================================
// SUBSCRIPTION MANAGEMENT SCREEN — KoruBeni Pro abonelik yönetimi
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/revenue_cat_service.dart';
import '../../presentation/providers/subscription_provider.dart';
import 'paywall_screen.dart';
import '../../core/design_tokens.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  bool _restoringPurchases = false;

  Future<void> _restorePurchases() async {
    setState(() => _restoringPurchases = true);
    final error = await context.read<SubscriptionProvider>().restorePurchases();
    if (!mounted) return;
    setState(() => _restoringPurchases = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final isPro = context.read<SubscriptionProvider>().isPro;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPro
                ? 'subscription_restore_success'.tr()
                : 'subscription_restore_no_purchase'.tr(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openCustomerCenter() async {
    final provider = context.read<SubscriptionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await RevenueCatUI.presentCustomerCenter();
      // Refresh state after customer center closes (user may have cancelled)
      if (mounted) {
        await provider.refresh();
      }
    } catch (e) {
      final fallbackOpened = await _openPlaySubscriptionsFallback();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              fallbackOpened
                  ? 'subscription_customer_center_fallback'.tr()
                  : 'subscription_customer_center_error'.tr(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _openPlaySubscriptionsFallback() async {
    try {
      return await launchUrl(
        Uri.parse(AppConstants.googlePlaySubscriptionsUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionProvider>();
    final isPro = subscription.isPro;
    final customerInfo = subscription.customerInfo;

    // Find active entitlement expiration date if available
    final activeEntitlement =
        customerInfo?.entitlements.active[RevenueCatService.entitlementId];
    final expiresDate = activeEntitlement?.expirationDate;

    return Scaffold(
      appBar: AppBar(title: Text('subscription_manage_title'.tr())),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          // ── Status banner ──
          _buildStatusBanner(isPro, expiresDate),
          const SizedBox(height: 28),

          if (isPro) ...[
            // ── Pro features section ──
            _buildSectionTitle('subscription_pro_features_title'.tr()),
            const SizedBox(height: 14),
            _buildProFeatureList(),
            const SizedBox(height: 28),

            // ── Manage subscription ──
            _buildSectionTitle('subscription_manage_section'.tr()),
            const SizedBox(height: 14),
            _buildCard([
              _buildActionTile(
                icon: Icons.manage_accounts_rounded,
                iconColor: AppColors.primary,
                title: 'subscription_customer_center_title'.tr(),
                subtitle: 'subscription_customer_center_subtitle'.tr(),
                onTap: _openCustomerCenter,
              ),
            ]),
            const SizedBox(height: 28),
          ] else ...[
            // ── Upgrade CTA ──
            _buildSectionTitle('subscription_upgrade_title'.tr()),
            const SizedBox(height: 14),
            _buildProFeatureList(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final provider = context.read<SubscriptionProvider>();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                  if (mounted) provider.refresh();
                },
                icon: const Icon(Icons.workspace_premium_rounded, size: IconSizes.action),
                label: Text(
                  'subscription_upgrade_btn'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // ── Restore purchases ──
          _buildSectionTitle('subscription_restore_section'.tr()),
          const SizedBox(height: 14),
          _buildCard([
            _buildActionTile(
              icon: Icons.restore_rounded,
              iconColor: AppColors.accent,
              title: 'subscription_restore_title'.tr(),
              subtitle: 'subscription_restore_subtitle'.tr(),
              onTap: _restoringPurchases ? null : _restorePurchases,
              trailing: _restoringPurchases
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ]),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _buildStatusBanner(bool isPro, String? expiresDate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPro
              ? [const Color(0xFF1A3A2A), const Color(0xFF122B1E)]
              : [AppColors.cardBg, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPro
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isPro
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPro
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_outline_rounded,
              size: 28,
              color: isPro ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPro
                      ? 'subscription_status_active'.tr()
                      : 'subscription_status_free'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isPro ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPro && expiresDate != null
                      ? 'subscription_expires'.tr(
                          namedArgs: {'date': expiresDate},
                        )
                      : isPro
                      ? 'subscription_lifetime_active'.tr()
                      : 'subscription_free_desc'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProFeatureList() {
    final features = [
      (Icons.security_rounded, AppColors.primary, 'subscription_feature_1'),
      (Icons.location_on_rounded, AppColors.info, 'subscription_feature_2'),
      (
        Icons.notifications_active_rounded,
        AppColors.warning,
        'subscription_feature_3',
      ),
      (Icons.support_agent_rounded, AppColors.accent, 'subscription_feature_4'),
    ];
    return _buildCard(
      features.indexed.expand<Widget>((e) {
        final (index, (icon, color, key)) = e;
        return [
          _buildFeatureTile(icon: icon, iconColor: color, title: key.tr()),
          if (index < features.length - 1)
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.5),
              indent: 60,
            ),
        ];
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: Shadows.raised,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: IconSizes.emphasis),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: IconSizes.action,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: IconSizes.emphasis),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: IconSizes.action,
          ),
        ],
      ),
    );
  }
}
