import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/settings_provider.dart';

/// Wraps [child] in a [MaterialApp] whose [themeMode] is driven by
/// [SettingsProvider], so theme-mode changes from settings are reflected app-wide.
class AppThemeModeWrapper extends StatelessWidget {
  final Widget child;

  const AppThemeModeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<SettingsProvider>().themeMode;
    return MaterialApp(
      themeMode: themeMode,
      home: child,
    );
  }
}
