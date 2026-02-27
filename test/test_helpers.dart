// Test helpers for widgets that use EasyLocalization.
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Wraps [child] with EasyLocalization and MaterialApp so .tr() works in widget tests.
Widget buildLocalizedApp(Widget child) {
  return EasyLocalization(
    path: 'assets/translations',
    supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
    fallbackLocale: const Locale('tr', 'TR'),
    startLocale: const Locale('tr', 'TR'),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: child,
      ),
    ),
  );
}
