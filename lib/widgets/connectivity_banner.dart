// ============================================================================
// ÇEVRİMDIŞI MOD BANNER'I – Bağlantı kesildiğinde gösterilen ince banner
// ============================================================================

import '../core/design_tokens.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../core/services/connectivity_service.dart';
import '../core/motion.dart';
import '../core/widgets/escape_dismissible.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  StreamSubscription<bool>? _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _isOffline = !ConnectivityService.instance.isOnline;
    if (_isOffline) {
      _slideController.forward();
    }

    _subscription = ConnectivityService.instance.onStatusChange.listen((
      isOnline,
    ) {
      if (!mounted) return;
      setState(() => _isOffline = !isOnline);
      if (_isOffline) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The banner paints edge to edge, so its colour still runs behind the
    // status bar -- but its CONTENT and its tap area must not. Measured on an
    // API 36 emulator before this: the interactive node was [0,0][1080,63],
    // i.e. 411.4 x 24.0 dp entirely underneath the system status bar, and taps
    // injected at y = 10, 31, 55 and 62 ALL failed to open the dialog. The
    // banner was not merely an undersized target; it could not be activated at
    // all, and its label sat beside the system clock.
    //
    // `viewPadding` rather than `padding` on purpose: an ancestor SafeArea
    // consumes `padding`, which is why the SafeArea that used to wrap this
    // widget reported a zero inset and did nothing. `viewPadding` reports the
    // real, unconsumed inset.
    final double statusBarInset = MediaQuery.viewPaddingOf(context).top;
    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onTap: _showOfflineInfoDialog,
        child: AnimatedContainer(
          duration: Motion.base,
          width: double.infinity,
          // 12 + content + 12 puts >= 48 dp of reachable height BELOW the
          // status bar, which is both the Android minimum and the first
          // version of this control a thumb can actually hit.
          padding: EdgeInsets.only(
            top: statusBarInset + 12,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.white,
                size: IconSizes.dense,
              ),
              const SizedBox(width: 8),
              Text(
                'offline_banner_text'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: IconSizes.inline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOfflineInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => EscapeDismissible(
        child: AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.warning,
              size: IconSizes.emphasis,
            ),
            const SizedBox(width: 10),
            Text(
              'offline_info_title'.tr(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _offlineFeatureRow(
              Icons.check_circle_rounded,
              AppColors.success,
              'offline_feature_alarm'.tr(),
            ),
            _offlineFeatureRow(
              Icons.check_circle_rounded,
              AppColors.success,
              'offline_feature_siren'.tr(),
            ),
            _offlineFeatureRow(
              Icons.check_circle_rounded,
              AppColors.success,
              'offline_feature_fakecall'.tr(),
            ),
            _offlineFeatureRow(
              Icons.check_circle_rounded,
              AppColors.success,
              'offline_feature_safewalk'.tr(),
            ),
            const SizedBox(height: 10),
            _offlineFeatureRow(
              Icons.warning_rounded,
              AppColors.warning,
              'offline_feature_location'.tr(),
            ),
            _offlineFeatureRow(
              Icons.warning_rounded,
              AppColors.warning,
              'offline_feature_sync'.tr(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'btn_ok'.tr(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _offlineFeatureRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: IconSizes.dense),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
