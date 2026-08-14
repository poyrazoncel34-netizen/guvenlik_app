/// The ONE validated destination model for every external entry into this app.
///
/// Why one model
/// -------------
/// A deep link, a notification tap and a quick-access surface all answer the
/// same question — "where should the app end up?" — and each of them is an
/// input an attacker or a mistake can supply. Giving them three routers would
/// give them three chances to disagree about which gate applies, and the gate
/// that matters here is a PIN in a duress model. So there is one allowlist, one
/// parser, and one place that decides when a destination may finally be shown.
///
/// What this model deliberately CANNOT express
/// -------------------------------------------
/// There is no destination that arms, dials, cancels, or unlocks. An external
/// link may put the user in front of a surface; it may never perform a safety
/// action on their behalf. `SubscriptionGate`, `PanicArmPolicy` and the PIN
/// gate stay exactly where they are, and a link arrives after them, never
/// instead of them.
library;

import '../constants/feature_access_matrix.dart';

/// Where an external entry point may ask the app to go.
///
/// Every member maps to a surface the user can already reach by tapping. A
/// destination that has no in-app equivalent would be a second navigation
/// architecture, which is the thing this file exists to prevent.
enum AppDestination {
  /// The panic surface. Shows it; never arms it.
  home,

  /// Live location / map tab.
  map,

  /// Emergency contacts tab.
  contacts,

  /// Settings tab.
  settings,

  /// The user's safety timeline, pushed from Home.
  safetyTimeline,

  /// The check-in surface, pushed from Home.
  checkIn,

  /// The subscription/paywall surface.
  subscription;

  /// The path segment that names this destination in a link.
  String get slug => switch (this) {
    AppDestination.home => 'home',
    AppDestination.map => 'map',
    AppDestination.contacts => 'contacts',
    AppDestination.settings => 'settings',
    AppDestination.safetyTimeline => 'timeline',
    AppDestination.checkIn => 'check-in',
    AppDestination.subscription => 'subscription',
  };

  /// The tab this destination lives on, or null when it is a pushed screen.
  int? get tabIndex => switch (this) {
    AppDestination.home => 0,
    AppDestination.map => 1,
    AppDestination.contacts => 2,
    AppDestination.settings => 3,
    _ => null,
  };

  /// The entitlement this destination sits behind, or null when it is free.
  ///
  /// The link layer does NOT decide entitlement -- `SubscriptionGate.ensureAccess`
  /// does, with exactly this feature. Naming the feature here rather than
  /// carrying a boolean is what stops the link path from developing its own
  /// second opinion about who may see what.
  PremiumFeature? get gatedFeature => switch (this) {
    AppDestination.safetyTimeline => PremiumFeature.timeline,
    AppDestination.checkIn => PremiumFeature.checkIn,
    AppDestination.contacts => PremiumFeature.contacts,
    _ => null,
  };

  static AppDestination? fromSlug(String slug) {
    for (final destination in AppDestination.values) {
      if (destination.slug == slug) return destination;
    }
    return null;
  }
}

/// Why a link was refused. Every refusal is named, because "the link did
/// nothing" and "the link was hostile" must not look the same in a log.
enum DeepLinkRejection {
  /// Not this app's scheme or host.
  foreignUri,

  /// The path names no allowlisted destination.
  unknownDestination,

  /// The URI carries a parameter this destination does not accept.
  unknownParameter,

  /// A parameter's value failed validation.
  malformedParameter,

  /// The URI is longer than any legitimate link this app emits.
  oversized,

  /// The path has more segments than any destination uses.
  pathTooDeep,
}

/// The outcome of parsing one incoming URI.
sealed class DeepLinkResult {
  const DeepLinkResult();
}

class DeepLinkAccepted extends DeepLinkResult {
  const DeepLinkAccepted(this.destination, {this.parameters = const {}});

  final AppDestination destination;

  /// Validated parameters only. A parameter that survives to here has already
  /// passed the destination's own rule.
  final Map<String, String> parameters;

  @override
  bool operator ==(Object other) =>
      other is DeepLinkAccepted &&
      other.destination == destination &&
      other.parameters.length == parameters.length &&
      other.parameters.entries.every((e) => parameters[e.key] == e.value);

  @override
  int get hashCode => Object.hash(destination, parameters.length);

  @override
  String toString() => 'DeepLinkAccepted(${destination.slug}, $parameters)';
}

class DeepLinkRejected extends DeepLinkResult {
  const DeepLinkRejected(this.reason, {this.detail});

  final DeepLinkRejection reason;

  /// Never the raw URI: an incoming link is untrusted text and this value
  /// reaches local logs.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is DeepLinkRejected &&
      other.reason == reason &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(reason, detail);

  @override
  String toString() => 'DeepLinkRejected(${reason.name}, $detail)';
}
