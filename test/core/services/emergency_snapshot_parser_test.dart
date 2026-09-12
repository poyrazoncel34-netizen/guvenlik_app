import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/emergency_snapshot_parser.dart';

void main() {
  const token = SessionToken(
    protocolVersion: 1,
    randomId: 'synthetic-parser',
    generation: 1,
    kind: EmergencySessionKind.checkIn,
  );
  Map<String, dynamic> session() => {
    'token': token.toMap(),
    'lifecycleState': 'requestFailed',
    'mainDeadlineMs': 1000,
    'finalDeadlineMs': 2000,
    'completedAtMs': 3500,
    'mainDurationMs': 1000,
    'target': '',
    'callRequestOutcome': 'failed',
    'fallbackOutcome': 'notAttempted',
  };
  test(
    'native completion survives parsing; legacy record has no invented time',
    () {
      final data = session();
      expect(
        parseSessionSnapshot({
          'type': 'present',
          'session': data,
        }).completedAt?.millisecondsSinceEpoch,
        3500,
      );
      data.remove('completedAtMs');
      expect(
        parseSessionSnapshot({'type': 'present', 'session': data}).completedAt,
        isNull,
      );
      data['completedAtMs'] = -1;
      expect(
        parseSessionSnapshot({'type': 'present', 'session': data}).completedAt,
        isNull,
      );
    },
  );
  test('discovery refuses a valid token from the wrong native slot', () {
    final snapshot = parseSessionSnapshot({
      'type': 'present',
      'session': session(),
    }, requestedKind: EmergencySessionKind.safeWalk);
    expect(snapshot.status, SessionReadStatus.unknown);
    expect(snapshot.reasonCode, 'invalidToken');
  });
  test('unknown outcomes remain malformed rather than fabricating failure', () {
    for (final key in ['callRequestOutcome', 'fallbackOutcome']) {
      final data = session()..[key] = 'futureOutcome';
      expect(
        parseSessionSnapshot({'type': 'present', 'session': data}).status,
        SessionReadStatus.unknown,
      );
    }
  });
}
