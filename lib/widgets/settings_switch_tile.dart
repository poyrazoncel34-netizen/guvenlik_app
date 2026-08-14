import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/widgets/minimum_tap_target.dart';

/// One labelled on/off row in Settings.
///
/// Extracted from `settings_page.dart` when adding [MinimumTapTarget] pushed
/// that file to 812 lines and `source_file_size_ratchet_test.dart` caught it.
/// The ratchet's own message says the fix is extraction, not an entry in
/// `acceptedOversize` -- so this is the extraction.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
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
              child: Icon(icon, color: iconColor, size: 22),
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
            // The 0.85 transform shrank the switch's built-in 48 dp tap target
            // along with its pixels: measured 51.0 x 40.8 dp from the real
            // semantics tree on API 36. MinimumTapTarget restores the reachable
            // area without touching what is drawn; the row is already 72 dp tall
            // so nothing moves.
            MinimumTapTarget(
              onTap: () {
                HapticFeedback.lightImpact();
                onChanged(!value);
              },
              child: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: value,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    onChanged(val);
                  },
                  activeThumbColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
  }
}
