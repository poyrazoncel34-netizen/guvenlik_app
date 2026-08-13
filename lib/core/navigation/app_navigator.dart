import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// The messenger the app-level surfaces post to.
///
/// `EmergencyTriggerHost` sits ABOVE `MaterialApp`, so
/// `ScaffoldMessenger.maybeOf(hostContext)` is always null there. Without this
/// key a rejected quick-access panic press had nowhere to say so and simply
/// disappeared (INDEPENDENT_REVIEW_ROUND_2.md R2-03).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
