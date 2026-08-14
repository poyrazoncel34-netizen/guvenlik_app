import 'package:sqflite/sqflite.dart';

/// When an integrity scan runs, and how deep it goes.
///
/// The depths are SQLite's own, and they answer different questions:
///
/// * [quick]  — `PRAGMA quick_check`. Structural b-tree validation, skipping
///   the expensive index-vs-table cross-check. Catches a truncated or
///   byte-damaged file.
/// * [full]   — `PRAGMA integrity_check` plus `PRAGMA foreign_key_check`.
///   `integrity_check` alone does NOT report referential problems, which is a
///   standing trap: a database can pass it while holding orphaned rows.
enum IntegrityScanDepth { quick, full }

/// One integrity finding, kept as text because SQLite reports prose.
class IntegrityFinding {
  const IntegrityFinding({required this.kind, required this.detail});

  /// `structural` (from quick_check/integrity_check) or `foreignKey`.
  final String kind;
  final String detail;

  Map<String, Object?> toMap() => <String, Object?>{
    'kind': kind,
    'detail': detail,
  };

  @override
  String toString() => '$kind: $detail';
}

/// The result of one scan. Never throws to the caller: a corruption check that
/// itself crashes the app has made the situation worse.
class IntegrityReport {
  const IntegrityReport({
    required this.depth,
    required this.findings,
    required this.elapsed,
    required this.scanFailed,
    this.failureReason,
  });

  final IntegrityScanDepth depth;
  final List<IntegrityFinding> findings;
  final Duration elapsed;

  /// True when the scan could not be completed at all (the file is damaged
  /// badly enough that even the PRAGMA fails). Distinct from "found problems".
  final bool scanFailed;
  final String? failureReason;

  bool get isHealthy => !scanFailed && findings.isEmpty;

  List<IntegrityFinding> get structural =>
      findings.where((f) => f.kind == 'structural').toList(growable: false);

  List<IntegrityFinding> get foreignKey =>
      findings.where((f) => f.kind == 'foreignKey').toList(growable: false);

  Map<String, Object?> toMap() => <String, Object?>{
    'depth': depth.name,
    'healthy': isHealthy,
    'scanFailed': scanFailed,
    if (failureReason != null) 'failureReason': failureReason,
    'elapsedMs': elapsed.inMilliseconds,
    'findings': findings.map((f) => f.toMap()).toList(growable: false),
  };
}

/// Database-level integrity policy for the local sqflite store (MP-29-017).
///
/// What is enforced vs what is verified
/// ------------------------------------
/// Enforcement that can THROW is deliberately limited. `activity_events` is the
/// user's safety timeline and it is written from the emergency path, where the
/// project rule is "degrade, never throw": a CHECK constraint that rejects a
/// row would turn a cosmetic data problem into a failed dispatch record. So the
/// schema enforces structure (PRIMARY KEY, NOT NULL, UNIQUE) and this service
/// VERIFIES the rest, out of band, where a finding can be reported instead of
/// thrown.
///
/// `PRAGMA foreign_keys` is nevertheless switched ON at connection time. SQLite
/// defaults it OFF per connection, so a foreign key added later would be
/// declared and silently unenforced — the same shape of dead safeguard as the
/// `oldVersion < 1` migration branch this repo already shipped once.
///
/// Lifecycle — and why NOT on every open
/// -------------------------------------
/// | Moment | Depth | Why |
/// |---|---|---|
/// | every connection open | none | `activity_events` grows without bound and the open sits on the startup path, which is latency-contracted. A scan here buys a rare condition at a recurring cost. `foreign_keys = ON` is applied instead, which is constant. |
/// | after a schema migration | quick | The one moment the app itself may have damaged the file, once per version, on a path the user is already waiting through. |
/// | user-requested diagnostics | full | Unbounded time is acceptable when the user asked and is watching. |
/// | suspected corruption (a `DatabaseException` on read/write) | full | Classify before acting: a structural fault and an orphaned row need different responses. |
abstract final class DatabaseIntegrityService {
  /// Applied to every connection, in `onConfigure`.
  static Future<void> configureConnection(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Whether [db] has foreign keys switched on. Used by the tests and the
  /// diagnostics report, so "we turned it on" is checkable rather than claimed.
  static Future<bool> foreignKeysEnabled(Database db) async {
    final rows = await db.rawQuery('PRAGMA foreign_keys');
    if (rows.isEmpty) return false;
    final value = rows.first.values.first;
    return value == 1 || value == true;
  }

  static Future<IntegrityReport> scan(
    Database db, {
    IntegrityScanDepth depth = IntegrityScanDepth.quick,
  }) async {
    final stopwatch = Stopwatch()..start();
    final findings = <IntegrityFinding>[];
    try {
      findings.addAll(await _structuralFindings(db, depth));
      if (depth == IntegrityScanDepth.full) {
        findings.addAll(await _foreignKeyFindings(db));
      }
    } on DatabaseException catch (error) {
      stopwatch.stop();
      return IntegrityReport(
        depth: depth,
        findings: findings,
        elapsed: stopwatch.elapsed,
        scanFailed: true,
        failureReason: error.getResultCode()?.toString() ?? 'databaseException',
      );
    }
    stopwatch.stop();
    return IntegrityReport(
      depth: depth,
      findings: findings,
      elapsed: stopwatch.elapsed,
      scanFailed: false,
    );
  }

  static Future<List<IntegrityFinding>> _structuralFindings(
    Database db,
    IntegrityScanDepth depth,
  ) async {
    final pragma = depth == IntegrityScanDepth.quick
        ? 'quick_check'
        : 'integrity_check';
    final rows = await db.rawQuery('PRAGMA $pragma');
    return rows
        .map((row) => row.values.first?.toString() ?? '')
        // SQLite reports the single row 'ok' for a healthy database.
        .where((value) => value.isNotEmpty && value != 'ok')
        .map((value) => IntegrityFinding(kind: 'structural', detail: value))
        .toList(growable: false);
  }

  /// `foreign_key_check` returns one row per violation:
  /// (child table, child rowid, parent table, constraint index).
  ///
  /// The shipped schema declares NO foreign keys, so this is empty today. It is
  /// run anyway, because the alternative — adding the check only once a
  /// relationship exists — is how a schema acquires an unverified one.
  static Future<List<IntegrityFinding>> _foreignKeyFindings(Database db) async {
    final rows = await db.rawQuery('PRAGMA foreign_key_check');
    return rows
        .map(
          (row) => IntegrityFinding(
            kind: 'foreignKey',
            detail:
                '${row['table']} rowid=${row['rowid']} '
                '-> ${row['parent']} (fkid=${row['fkid']})',
          ),
        )
        .toList(growable: false);
  }
}
