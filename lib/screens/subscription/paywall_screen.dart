// ============================================================================
// PAYWALL SCREEN — Custom RevenueCat purchase UI
// ============================================================================

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../presentation/providers/subscription_provider.dart';

class PaywallScreen extends StatefulWidget {
  final String? lockedFeatureTitleKey;

  const PaywallScreen({super.key, this.lockedFeatureTitleKey});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String? _purchasingPackageId;
  bool _restoringPurchases = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SubscriptionProvider>().initialize();
    });
  }

  Future<void> _purchase(Package package) async {
    if (_purchasingPackageId != null || _restoringPurchases) return;
    setState(() => _purchasingPackageId = package.identifier);
    final provider = context.read<SubscriptionProvider>();
    final errorKey = await provider.purchasePackage(package);
    if (!mounted) return;
    setState(() => _purchasingPackageId = null);

    if (errorKey == null && provider.isPro) {
      _showSnack('subscription_purchase_success'.tr(), AppColors.success);
      Navigator.of(context).pop();
      return;
    }

    if (errorKey != null) {
      _showSnack(errorKey.tr(), AppColors.warning);
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoringPurchases || _purchasingPackageId != null) return;
    setState(() => _restoringPurchases = true);
    final provider = context.read<SubscriptionProvider>();
    final errorKey = await provider.restorePurchases();
    if (!mounted) return;
    setState(() => _restoringPurchases = false);

    if (errorKey != null) {
      _showSnack(errorKey.tr(), AppColors.warning);
      return;
    }

    if (provider.isPro) {
      _showSnack('subscription_restore_success'.tr(), AppColors.success);
      Navigator.of(context).pop();
    } else {
      _showSnack('subscription_restore_no_purchase'.tr(), AppColors.warning);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionProvider>();
    final monthly = subscription.monthlyPackage;
    final annual = subscription.annualPackage;
    final plansReady = subscription.hasRequiredPackages;
    final isInitialLoading =
        subscription.isLoading && subscription.offerings == null;

    return Scaffold(
      appBar: AppBar(title: Text('subscription_upgrade_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 20),
          _buildFeatureSummary(),
          const SizedBox(height: 20),
          if (isInitialLoading)
            _buildLoadingCard()
          else if (!plansReady || monthly == null || annual == null)
            _buildPlansUnavailableCard(subscription.isLoading)
          else ...[
            _buildPlanCard(
              package: annual,
              title: 'subscription_plan_annual'.tr(),
              subtitle: 'subscription_plan_annual_subtitle'.tr(),
              highlighted: true,
            ),
            const SizedBox(height: 12),
            _buildPlanCard(
              package: monthly,
              title: 'subscription_plan_monthly'.tr(),
              subtitle: 'subscription_plan_monthly_subtitle'.tr(),
            ),
          ],
          const SizedBox(height: 18),
          _buildRestoreButton(),
          const SizedBox(height: 12),
          Text(
            'subscription_footer_note'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardBg, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'subscription_paywall_title'.tr(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'subscription_paywall_subtitle'.tr(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.lockedFeatureTitleKey != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'subscription_locked_feature'.tr(
                  namedArgs: {'feature': widget.lockedFeatureTitleKey!.tr()},
                ),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureSummary() {
    final features = [
      'subscription_value_panic',
      'subscription_value_contacts',
      'subscription_value_walk',
      'subscription_value_history',
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: features.indexed.expand<Widget>((entry) {
          final (index, key) = entry;
          return [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      key.tr(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index < features.length - 1)
              Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5),
                indent: 58,
              ),
          ];
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'subscription_plans_loading'.tr(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansUnavailableCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'subscription_plans_unavailable_title'.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'subscription_plans_unavailable_body'.tr(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: isLoading
                ? null
                : () => context.read<SubscriptionProvider>().refreshOfferings(),
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text('retry_button'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required Package package,
    required String title,
    required String subtitle,
    bool highlighted = false,
  }) {
    final isBusy = _purchasingPackageId == package.identifier;
    final purchaseBlocked =
        _purchasingPackageId != null || _restoringPurchases || isBusy;
    final color = highlighted ? AppColors.accent : AppColors.primary;

    return InkWell(
      onTap: purchaseBlocked ? null : () => _purchase(package),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted
                ? AppColors.accent.withValues(alpha: 0.45)
                : AppColors.border,
            width: highlighted ? 1.2 : 1,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (highlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'subscription_plan_best_value'.tr(),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              package.storeProduct.priceString,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: purchaseBlocked ? null : () => _purchase(package),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: AppColors.background,
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textSecondary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'subscription_plan_choose'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton.icon(
      onPressed: _restoringPurchases || _purchasingPackageId != null
          ? null
          : _restorePurchases,
      icon: _restoringPurchases
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.restore_rounded, size: 18),
      label: Text('subscription_restore_title'.tr()),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
