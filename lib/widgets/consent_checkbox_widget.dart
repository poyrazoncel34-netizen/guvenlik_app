// ============================================================================
// CONSENT CHECKBOX WIDGET — Rıza onay kutusu bileşeni
// ============================================================================

import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class ConsentCheckboxWidget extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool isSpecialCategory;
  final String? sublabel;

  const ConsentCheckboxWidget({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isSpecialCategory = false,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    // MERGED ON PURPOSE. The row itself is the target and is 371 dp wide by
    // 69-198 dp tall, but the Checkbox inside it was ALSO exposed as its own
    // interactive node -- measured 24.0 x 24.0 dp from the real semantics tree
    // on API 36 (density 420 / dpr 2.625), five times over on the consent
    // screen. Both nodes carried the SAME label, so a screen-reader user heard
    // the consent sentence twice and the second time on a target half the
    // recommended size.
    //
    // Merging collapses them into one node the size of the row. Nothing moves
    // on screen: the fix is to stop advertising a small target that was never
    // the one users needed to hit, not to grow the artwork.
    return MergeSemantics(
      child: GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSpecialCategory
              ? AppColors.emergency.withValues(alpha: 0.07)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSpecialCategory
                ? (value
                      ? AppColors.emergency
                      : AppColors.emergency.withValues(alpha: 0.4))
                : (value ? AppColors.primary : AppColors.border),
            width: isSpecialCategory ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: isSpecialCategory
                    ? AppColors.emergency
                    : AppColors.primary,
                side: BorderSide(
                  color: isSpecialCategory
                      ? AppColors.emergency.withValues(alpha: 0.6)
                      : AppColors.border,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSpecialCategory) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.emergency.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'ÖZEL NİTELİKLİ VERİ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emergency,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
