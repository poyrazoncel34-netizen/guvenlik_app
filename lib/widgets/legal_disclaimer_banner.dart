// ============================================================================
// LEGAL DISCLAIMER BANNER — Özellik bazlı sorumluluk reddi banner'ı
// ============================================================================

import 'package:flutter/material.dart';
import '../core/design_tokens.dart';
import '../core/app_colors.dart';

enum LegalBannerContext {
  home,
  fakeCall,
  safeWalk,
  emergencyContact,
  panicButton,
}

class LegalDisclaimerBanner extends StatelessWidget {
  final LegalBannerContext bannerContext;
  final bool dismissible;

  const LegalDisclaimerBanner({
    super.key,
    required this.bannerContext,
    this.dismissible = false,
  });

  String get _message {
    switch (bannerContext) {
      case LegalBannerContext.home:
        return 'KoruBeni profesyonel bir güvenlik hizmeti DEĞİLDİR. Acil durumlarda her zaman 112\'yi arayın.';
      case LegalBannerContext.fakeCall:
        return 'Bu özellik yalnızca kişisel güvenlik amaçlıdır. Kötüye kullanımdan doğan tüm sorumluluk kullanıcıya aittir.';
      case LegalBannerContext.safeWalk:
        return 'Bu özellik yardımcı bir araçtır; güvenliğinizi garanti etmez. Tehlike durumunda 112\'yi arayın.';
      case LegalBannerContext.emergencyContact:
        return 'Bu kişiyi uygulamaya eklediğinizi ve acil durumda aranabileceğini ilgili kişiye bildirmeniz gerekmektedir.';
      case LegalBannerContext.panicButton:
        return 'Panik akışı geri sayım bitmeden arama başlatmaz. Acil durumlarda 112\'yi de arayın.';
    }
  }

  IconData get _icon {
    switch (bannerContext) {
      case LegalBannerContext.home:
        return Icons.info_outline_rounded;
      case LegalBannerContext.fakeCall:
      case LegalBannerContext.panicButton:
        return Icons.warning_amber_rounded;
      case LegalBannerContext.safeWalk:
        return Icons.shield_outlined;
      case LegalBannerContext.emergencyContact:
        return Icons.person_outline_rounded;
    }
  }

  Color get _color {
    switch (bannerContext) {
      case LegalBannerContext.home:
        return AppColors.info;
      case LegalBannerContext.fakeCall:
        return AppColors.warning;
      case LegalBannerContext.panicButton:
        return AppColors.emergency;
      case LegalBannerContext.safeWalk:
        return AppColors.success;
      case LegalBannerContext.emergencyContact:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _color, size: IconSizes.listItem),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message,
              style: TextStyle(
                fontSize: 12,
                color: _color.withValues(alpha: 0.9),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
