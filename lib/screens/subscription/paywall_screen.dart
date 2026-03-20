// ============================================================================
// PAYWALL SCREEN — RevenueCat paywall (PaywallView widget)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../presentation/providers/subscription_provider.dart';

/// Full-screen paywall rendered by RevenueCat UI SDK.
///
/// The paywall template and copy are configured entirely in the RevenueCat
/// dashboard — no code changes needed to update paywall appearance.
///
/// Usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
/// ```
///
/// Or for conditional display (skips the paywall when already Pro):
/// ```dart
/// await RevenueCatUI.presentPaywallIfNeeded(RevenueCatService.entitlementId);
/// ```
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PaywallView renders its own full-screen content — no AppBar needed.
      body: PaywallView(
        // Offering is resolved automatically from the RevenueCat dashboard
        // (the "current" offering). Pass a specific Offering to override.
        onPurchaseStarted: (Package package) {
          // Purchase flow started — PaywallView shows its own loading state.
        },
        onPurchaseCompleted: (
          CustomerInfo customerInfo,
          StoreTransaction transaction,
        ) {
          // Update local subscription state and close the paywall.
          context.read<SubscriptionProvider>().refresh();
          if (context.mounted) Navigator.of(context).pop();
        },
        onPurchaseError: (PurchasesError error) {
          // Show a brief error message; the paywall stays open so the user
          // can try again or dismiss.
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error.message.isNotEmpty
                      ? error.message
                      : 'subscription_error_purchase'.tr(),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onRestoreCompleted: (CustomerInfo customerInfo) {
          context.read<SubscriptionProvider>().refresh();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('subscription_restore_success'.tr()),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          }
        },
        onRestoreError: (PurchasesError error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('subscription_error_restore'.tr()),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onDismiss: () {
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}
