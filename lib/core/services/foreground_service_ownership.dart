enum ForegroundServiceTransition { none, start, stop }

/// Reference-counted ownership for the user-visible active-session status.
///
/// Check-in, Safe Walk and panic countdown may overlap. A caller may release
/// only its own lease; the shared status remains active until the last owner
/// releases it.
class ForegroundServiceOwnership {
  final Set<String> _owners = <String>{};

  Set<String> get owners => Set<String>.unmodifiable(_owners);

  ForegroundServiceTransition acquire(String owner) {
    if (owner.isEmpty || !_owners.add(owner)) {
      return ForegroundServiceTransition.none;
    }
    return _owners.length == 1
        ? ForegroundServiceTransition.start
        : ForegroundServiceTransition.none;
  }

  ForegroundServiceTransition release(String owner) {
    if (!_owners.remove(owner)) {
      return ForegroundServiceTransition.none;
    }
    return _owners.isEmpty
        ? ForegroundServiceTransition.stop
        : ForegroundServiceTransition.none;
  }
}
