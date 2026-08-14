import 'package:flutter/foundation.dart';

import 'app_destination.dart';
import 'deep_link_parser.dart';

/// Where an external entry point came from. Recorded so a rejection can be
/// attributed, and so the notification and link surfaces cannot silently
/// become indistinguishable in a log.
enum ExternalEntrySource { deepLink, notification, quickAccess }

/// Holds ONE validated destination between "an external entry point asked" and
/// "every gate has legitimately completed".
///
/// ## The security shape
///
/// A deep link must not bypass the PIN gate, consent, onboarding, or the
/// subscription rules. The mechanism is not a check inside the link handler —
/// a check there is one refactor away from being skipped. Instead the link
/// handler cannot navigate at all: it can only PARK a destination. The park is
/// consumed by [MainNavigation], which `SplashScreen` builds only after consent,
/// onboarding and the PIN gate have each been satisfied. So the ordering is a
/// property of who constructs whom, not of a conditional someone must remember
/// to write.
///
/// ## Why exactly one
///
/// A queue would let a rapid burst of links (or a hostile app firing them in a
/// loop) accumulate work that fires after unlock. The park holds the LATEST
/// validated destination and nothing else: fifty links leave one destination,
/// which is also what a user pressing a notification repeatedly means.
class PendingDestinationService extends ChangeNotifier {
  PendingDestinationService();

  static final PendingDestinationService instance = PendingDestinationService();

  DeepLinkAccepted? _pending;
  ExternalEntrySource? _source;

  /// Rejections seen this session, newest last, bounded. Kept in memory only:
  /// an incoming URI is untrusted text and never reaches durable storage.
  final List<DeepLinkRejected> _rejections = <DeepLinkRejected>[];
  static const int maxRecordedRejections = 20;

  DeepLinkAccepted? get pending => _pending;
  ExternalEntrySource? get pendingSource => _source;
  bool get hasPending => _pending != null;

  List<DeepLinkRejected> get rejections =>
      List<DeepLinkRejected>.unmodifiable(_rejections);

  /// Parses and parks a raw incoming URI. Returns the parse result so the
  /// caller can report a rejection rather than discovering nothing happened.
  DeepLinkResult submitUri(
    Uri? uri, {
    ExternalEntrySource source = ExternalEntrySource.deepLink,
  }) {
    final result = DeepLinkParser.parse(uri);
    switch (result) {
      case DeepLinkAccepted():
        _park(result, source);
      case DeepLinkRejected():
        _recordRejection(result);
    }
    return result;
  }

  /// Parks an already-validated destination. Used by the notification layer,
  /// which builds its links with [DeepLinkParser.build] and therefore cannot
  /// produce an unparseable one — but still goes through the same park, so the
  /// gate ordering is identical for both entry points.
  void submitDestination(
    AppDestination destination, {
    Map<String, String> parameters = const <String, String>{},
    ExternalEntrySource source = ExternalEntrySource.notification,
  }) {
    final result = DeepLinkParser.parse(
      DeepLinkParser.build(destination, parameters: parameters),
    );
    switch (result) {
      case DeepLinkAccepted():
        _park(result, source);
      case DeepLinkRejected():
        // Unreachable unless build() and parse() disagree, which is precisely
        // the drift worth catching rather than assuming away.
        _recordRejection(result);
    }
  }

  void _park(DeepLinkAccepted accepted, ExternalEntrySource source) {
    _pending = accepted;
    _source = source;
    notifyListeners();
  }

  void _recordRejection(DeepLinkRejected rejection) {
    _rejections.add(rejection);
    if (_rejections.length > maxRecordedRejections) {
      _rejections.removeAt(0);
    }
    notifyListeners();
  }

  /// Takes the parked destination, if any, and clears it.
  ///
  /// Single-consume on purpose: a destination that survived consumption would
  /// re-fire on every subsequent rebuild, and on a lock/unlock cycle it would
  /// look like the app spontaneously navigating.
  DeepLinkAccepted? consume() {
    final pending = _pending;
    _pending = null;
    _source = null;
    if (pending != null) notifyListeners();
    return pending;
  }

  /// Drops anything parked. Called when the app resets or the user signs out of
  /// the local profile, so a destination cannot outlive the state it referred
  /// to.
  void clear() {
    if (_pending == null && _rejections.isEmpty) return;
    _pending = null;
    _source = null;
    _rejections.clear();
    notifyListeners();
  }
}
