import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../design_tokens.dart';

class ResponsiveContactsHeader extends StatelessWidget {
  const ResponsiveContactsHeader({
    super.key,
    required this.hasContacts,
    required this.onSelectEmergencyContact,
  });

  final bool hasContacts;
  final VoidCallback onSelectEmergencyContact;

  @override
  Widget build(BuildContext context) {
    final usesStackedLayout = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return Flex(
      direction: usesStackedLayout ? Axis.vertical : Axis.horizontal,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: usesStackedLayout
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          'contacts_network_title'.tr(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        TextButton.icon(
          onPressed: hasContacts ? onSelectEmergencyContact : null,
          icon: const Icon(Icons.shield_rounded, size: IconSizes.listItem),
          label: Text('contacts_select_emergency'.tr()),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
