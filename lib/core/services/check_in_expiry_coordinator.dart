class CheckInExpiryCoordinator {
  CheckInExpiryCoordinator._();

  static final CheckInExpiryCoordinator instance = CheckInExpiryCoordinator._();

  static const String checkInSession = 'check_in';
  static const String safeWalkSession = 'safe_walk';

  final Set<String> _activeSessionIds = <String>{};
  final Map<String, String> _claimsBySession = <String, String>{};

  bool get isClaimed => _claimsBySession.isNotEmpty;

  bool isClaimedFor(String sessionId) =>
      _claimsBySession.containsKey(sessionId);

  void arm(String sessionId) {
    _activeSessionIds.add(sessionId);
    _claimsBySession.remove(sessionId);
  }

  bool tryClaim(String source, {String? sessionId}) {
    if (sessionId == null) {
      if (_claimsBySession.isNotEmpty || _activeSessionIds.length > 1) {
        return false;
      }
      final resolvedSessionId = _activeSessionIds.isEmpty
          ? '_legacy'
          : _activeSessionIds.first;
      _activeSessionIds.add(resolvedSessionId);
      _claimsBySession[resolvedSessionId] = source;
      return true;
    }

    if (_claimsBySession.containsKey(sessionId)) {
      return false;
    }
    if (_activeSessionIds.isNotEmpty &&
        !_activeSessionIds.contains(sessionId)) {
      return false;
    }
    _activeSessionIds.add(sessionId);
    _claimsBySession[sessionId] = source;
    return true;
  }

  void reset({String? sessionId}) {
    if (sessionId != null) {
      _activeSessionIds.remove(sessionId);
      _claimsBySession.remove(sessionId);
      return;
    }
    _activeSessionIds.clear();
    _claimsBySession.clear();
  }
}
