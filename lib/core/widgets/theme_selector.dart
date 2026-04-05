import 'package:flutter/material.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key, required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [ThemeMode.system, ThemeMode.light, ThemeMode.dark].map((mode) {
        final isSelected = selected == mode;
        return Expanded(
          child: GestureDetector(
            key: ValueKey(mode),
            onTap: () => onChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  switch (mode) {
                    ThemeMode.system => 'theme_system',
                    ThemeMode.light => 'theme_light',
                    ThemeMode.dark => 'theme_dark',
                  },
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
