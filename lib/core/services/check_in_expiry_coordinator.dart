class CheckInExpiryCoordinator {
  CheckInExpiryCoordinator._();

  static final CheckInExpiryCoordinator instance = CheckInExpiryCoordinator._();

  static const String checkInSession = 'check_in';
  static const String safeWalkSession = 'safe_walk';

  String? _activeSessionId;
  String? _claimedBy;

  bool get isClaimed => _claimedBy != null;

  void arm(String sessionId) {
    _activeSessionId = sessionId;
    _claimedBy = null;
  }

  bool tryClaim(String source, {String? sessionId}) {
    if (_claimedBy != null) {
      return false;
    }
    if (sessionId != null &&
        _activeSessionId != null &&
        _activeSessionId != sessionId) {
      return false;
    }
    _activeSessionId = sessionId ?? _activeSessionId;
    _claimedBy = source;
    return true;
  }

  void reset({String? sessionId}) {
    if (sessionId != null &&
        _activeSessionId != null &&
        _activeSessionId != sessionId) {
      return;
    }
    _activeSessionId = null;
    _claimedBy = null;
  }
}
