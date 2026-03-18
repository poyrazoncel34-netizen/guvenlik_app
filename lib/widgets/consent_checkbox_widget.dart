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
    return GestureDetector(
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
                activeColor:
                    isSpecialCategory ? AppColors.emergency : AppColors.primary,
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
                          horizontal: 8, vertical: 2),
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
                    style: TextStyle(
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
    );
  }
}
