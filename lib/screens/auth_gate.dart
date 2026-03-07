// ============================================================================
// AUTH GATE - Offline-First: Always go to MainNavigation
// ============================================================================
// Firebase auth removed. App is offline-first, no cloud login.
// ============================================================================

import 'package:flutter/material.dart';
import 'main_navigation.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigation();
  }
}
