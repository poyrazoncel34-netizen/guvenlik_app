// ============================================================================
// NETWORK ERROR + RETRY UI - Tutarlı ağ hatası mesajları ve tekrar dene butonu
// ============================================================================

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/design_tokens.dart';
import '../core/app_colors.dart';

/// Ağ hatası durumunda gösterilen widget. Mesaj + Tekrar Dene butonu.
class NetworkErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const NetworkErrorRetry({
    super.key,
    this.message = 'connection_failed',
    required this.onRetry,
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final msg = message.tr();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: IconSizes.feature, color: AppColors.warning),
            ),
            const SizedBox(height: 20),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: IconSizes.action),
              label: Text("retry_button".tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ScaffoldMessenger ile SnackBar gösterir, retry aksiyonu varsa buton ekler.
void showNetworkErrorSnackBar(
  BuildContext context, {
  required String message,
  VoidCallback? onRetry,
}) {
  final content = Row(
    children: [
      const Icon(Icons.wifi_off_rounded, color: Colors.white, size: IconSizes.action),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      if (onRetry != null)
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            onRetry();
          },
          child: Text(
            "retry_button".tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ],
  );
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: content,
      backgroundColor: AppColors.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 5),
    ),
  );
}
