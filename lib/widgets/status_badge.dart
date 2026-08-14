import 'package:flutter/material.dart';
import '../core/design_tokens.dart';

/// Durum göstergesi badge widget'ı.
/// Online/offline, aktif/pasif gibi durumları kompakt şekilde gösterir.
class StatusBadge extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.label,
    required this.isActive,
    this.activeColor,
    this.inactiveColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? Colors.greenAccent)
        : (inactiveColor ?? Colors.grey);

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          if (icon != null) ...[
            Icon(icon, size: IconSizes.inline, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: badge);
    }
    return badge;
  }
}
