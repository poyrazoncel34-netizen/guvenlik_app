import 'app_destination.dart';

/// Strict parser for incoming links.
///
/// Deliberately a pure function over a [Uri]: no storage, no navigation, no
/// entitlement lookup. That is what makes the whole surface testable against
/// hostile input without a running app, and it is why the security decisions
/// live one layer up, in [PendingDestinationService] and the gates it defers
/// to.
///
/// ## Why a custom scheme and not an Android App Link
///
/// An `autoVerify` HTTPS App Link requires `/.well-known/assetlinks.json` at
/// the DOMAIN ROOT. This project's public pages are a GitHub Pages *project*
/// site (`<user>.github.io/guvenlik_app`), so the root belongs to github.io and
/// is not ours to serve — the association could not be published no matter how
/// much work went into it. That is a fact about the hosting, not a difficulty,
/// and inventing an assetlinks proof would be exactly the fabricated evidence
/// this audit exists to catch. A custom scheme claims no domain ownership and
/// needs no external verification, so the whole surface is provable here.
abstract final class DeepLinkParser {
  /// The app's own scheme. Registered in AndroidManifest.xml on MainActivity.
  static const String scheme = 'korubeni';

  /// Links are `korubeni://open/<destination>`. The fixed host keeps the
  /// destination in the PATH, so a host typo cannot silently become a
  /// destination.
  static const String host = 'open';

  /// No legitimate link this app emits is longer. A bound before parsing keeps
  /// a hostile URI from becoming a memory question.
  static const int maxUriLength = 512;

  /// `open/<destination>` — one segment beyond the host.
  static const int maxPathSegments = 1;

  /// Parameters each destination accepts, with the rule each value must pass.
  /// A destination absent from this map accepts NO parameters.
  static final Map<AppDestination, Map<String, bool Function(String)>>
  _allowedParameters = <AppDestination, Map<String, bool Function(String)>>{
    AppDestination.safetyTimeline: <String, bool Function(String)>{
      // The event a notification refers to. Opaque id, bounded and charset-
      // restricted; the timeline looks it up and simply shows the list if it
      // no longer exists.
      'event': _isSafeId,
    },
    AppDestination.subscription: <String, bool Function(String)>{
      // Which surface sent the user to the paywall. Diagnostics only; never
      // used to decide entitlement.
      'from': _isSafeId,
    },
  };

  static bool _isSafeId(String value) =>
      value.isNotEmpty &&
      value.length <= 64 &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);

  static DeepLinkResult parse(Uri? uri) {
    if (uri == null) {
      return const DeepLinkRejected(DeepLinkRejection.foreignUri, detail: 'null');
    }
    if (uri.toString().length > maxUriLength) {
      return const DeepLinkRejected(DeepLinkRejection.oversized);
    }
    if (uri.scheme != scheme || uri.host != host) {
      return DeepLinkRejected(
        DeepLinkRejection.foreignUri,
        // The scheme is safe to record; the rest of the URI is not.
        detail: uri.scheme.isEmpty ? 'noScheme' : uri.scheme,
      );
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.length > maxPathSegments) {
      return const DeepLinkRejected(DeepLinkRejection.pathTooDeep);
    }
    if (segments.isEmpty) {
      // `korubeni://open` is the app's front door, which is Home.
      return _withParameters(AppDestination.home, uri);
    }

    final destination = AppDestination.fromSlug(segments.first);
    if (destination == null) {
      return const DeepLinkRejected(DeepLinkRejection.unknownDestination);
    }
    return _withParameters(destination, uri);
  }

  static DeepLinkResult _withParameters(
    AppDestination destination,
    Uri uri,
  ) {
    final rules =
        _allowedParameters[destination] ?? const <String, bool Function(String)>{};
    final validated = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      final rule = rules[entry.key];
      if (rule == null) {
        return DeepLinkRejected(
          DeepLinkRejection.unknownParameter,
          detail: entry.key,
        );
      }
      if (!rule(entry.value)) {
        return DeepLinkRejected(
          DeepLinkRejection.malformedParameter,
          detail: entry.key,
        );
      }
      validated[entry.key] = entry.value;
    }
    return DeepLinkAccepted(destination, parameters: validated);
  }

  /// Builds a link this app can emit. Used by the notification layer so the
  /// producer and the consumer cannot drift apart.
  static Uri build(
    AppDestination destination, {
    Map<String, String> parameters = const <String, String>{},
  }) => Uri(
    scheme: scheme,
    host: host,
    pathSegments: <String>[destination.slug],
    queryParameters: parameters.isEmpty ? null : parameters,
  );
}
