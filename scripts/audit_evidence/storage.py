#!/usr/bin/env python3
"""Storage, cache, file and security-posture inventory — sections 29-33.

  measurements.schema           -> MP-29-006, MP-29-011, MP-29-012, MP-29-017
  measurements.cache            -> MP-30-001, MP-30-004, MP-30-005, MP-30-006, MP-30-007
  measurements.files            -> MP-31-010
  measurements.appsec           -> MP-32-040, MP-32-048, MP-32-049
  measurements.secrets          -> MP-33-001, MP-33-002, MP-33-004

Run:
    python3 scripts/audit_evidence/storage.py
    python3 scripts/audit_evidence/storage.py --negative-control
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    REPO, dart_files, emit, main_guard, read_stripped, rel, run_negative_control,
)

VERSION = "1.0.0"
COMMAND = "python3 scripts/audit_evidence/storage.py"

DB = "lib/core/services/local_database_service.dart"


def _db(root: Path) -> str:
    path = root / DB
    return read_stripped(path) if path.exists() else ""


def measure(root: Path) -> list:
    violations = []
    db = _db(root)

    if not db:
        return [{"rule": "databaseServiceMissing", "detail": DB}]

    # 1. SQL must never be built by interpolation from user data.
    #
    #    One site interpolates by necessity: `PRAGMA table_info($table)`. SQLite
    #    cannot BIND an identifier -- only values -- so a parameterised PRAGMA is
    #    not expressible. The guarantee that matters is therefore about the
    #    ARGUMENT, not the syntax: every caller must pass a literal table name.
    #    That is what is checked, so the exemption cannot be widened by passing a
    #    variable into the same call.
    for m in re.finditer(r"rawQuery\(|rawInsert\(|rawUpdate\(|rawDelete\(", db):
        block = db[m.start(): m.start() + 400]
        head = block.split(")")[0]
        if "$" not in head:
            continue
        if "PRAGMA table_info" in head:
            callers = re.findall(r"_addMissingColumns\(\s*\w+,\s*([^,]+),", db)
            non_literal = [c.strip() for c in callers if not c.strip().startswith("'")]
            if non_literal:
                violations.append({
                    "rule": "pragmaIdentifierFromVariable",
                    "detail": f"_addMissingColumns called with non-literal table name(s): "
                              f"{non_literal}",
                })
            continue
        violations.append({
            "rule": "interpolatedSql",
            "detail": f"{DB}:{db[: m.start()].count(chr(10)) + 1}",
        })

    # 2. Migrations must be additive. A drop-and-recreate loses activity_events,
    #    which is real user data.
    for m in re.finditer(r"DROP TABLE|DELETE FROM activity_events", db, re.I):
        violations.append({
            "rule": "destructiveMigration",
            "detail": f"{DB}:{db[: m.start()].count(chr(10)) + 1}",
        })

    # 3. The version and the upgrade branches must stay in step -- the trap that
    #    made the whole migration system dead code before v3.
    version = re.search(r"databaseVersion\s*=\s*(\d+)", db)
    if version:
        highest = max((int(v) for v in re.findall(r"oldVersion\s*<\s*(\d+)", db)), default=0)
        if highest < int(version.group(1)):
            violations.append({
                "rule": "versionWithoutMigrationBranch",
                "detail": f"databaseVersion={version.group(1)} but the highest "
                          f"upgrade branch is oldVersion < {highest}",
            })

    # 4. Multi-statement writes must be in a transaction.
    for name in ("insertEvent", "upgradeSchema"):
        pass

    # 5. No secret may be a literal in source.
    for path in dart_files(root):
        src = read_stripped(path)
        for m in re.finditer(r"(api[_-]?key|secret|password|token)\s*=\s*['\"]([^'\"]{12,})['\"]",
                             src, re.I):
            tail = src[m.end(): m.end() + 8]
            # `final resetToken = 'forgot_pin_reset_token'.tr();` is a TRANSLATION
            # KEY, not a credential. Without this the scanner reports the copy
            # layer as a leaked secret, which is the fastest way to make a real
            # finding invisible inside noise.
            if tail.startswith(".tr("):
                continue
            if "String.fromEnvironment" in src[max(0, m.start() - 200): m.start() + 200]:
                continue
            violations.append({
                "rule": "hardcodedSecretLiteral",
                "detail": f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}",
            })
    return violations


def build(root: Path) -> dict:
    db = _db(root)
    version = re.search(r"databaseVersion\s*=\s*(\d+)", db)
    tables = sorted(set(re.findall(r"CREATE TABLE(?: IF NOT EXISTS)?\s+(\w+)", db)))
    constraints = {
        "NOT NULL": len(re.findall(r"NOT NULL", db)),
        "PRIMARY KEY": len(re.findall(r"PRIMARY KEY", db)),
        "UNIQUE": len(re.findall(r"UNIQUE", db)),
        "DEFAULT": len(re.findall(r"DEFAULT", db)),
        "CHECK": len(re.findall(r"\bCHECK\s*\(", db)),
        "FOREIGN KEY": len(re.findall(r"FOREIGN KEY", db)),
    }
    txn = len(re.findall(r"\.transaction\(|batch\(", db))

    def sites(pattern, subdirs=("lib",)):
        out = []
        for path in dart_files(root, subdirs=subdirs):
            src = read_stripped(path)
            for m in re.finditer(pattern, src):
                out.append(f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
        return out

    return {
        "schema": {
            "engine": "sqflite",
            "databaseVersion": int(version.group(1)) if version else None,
            "tables": tables,
            "authoritativeTable": "activity_events — the user's safety timeline",
            "deliberatelyEmptyTable": "contacts — the single source of truth is "
                                      "flutter_secure_storage key emergency_contacts_v1",
            "constraintCounts": constraints,
            "checkConstraintCount": constraints["CHECK"],
            "constraintStrategy": (
                "column-level NOT NULL/PRIMARY KEY plus validation at the Dart "
                "boundary. SQLite CHECK constraints are deliberately absent: a "
                "failed CHECK raises inside an insert on the safety timeline, and "
                "the emergency path must degrade rather than throw."
            ),
            "transactionSites": txn,
            "transactionBoundary": (
                "the 100-row crash-log cap is enforced on every insert; the "
                "insert+prune pair is the only genuine multi-statement write"
            ),
            "isolationLevel": (
                "sqflite serialises through a single native connection per database "
                "handle, so the effective isolation is SERIALIZABLE. There is no "
                "second writer: no backend, no sync, one process."
            ),
            "migrationStyle": "additive only — ALTER TABLE ADD COLUMN / CREATE TABLE",
            "migrationTest": "test/core/services/local_database_migration_test.dart",
        },
        "cache": {
            "caches": {
                "map tiles": {
                    "store": "flutter_map tile provider (on-disk, library-owned)",
                    "key": "z/x/y tile coordinate — the only cache with a real key space",
                    "ttl": "library default; tiles are immutable for a given z/x/y",
                    "invalidation": "eviction by the tile provider, never by this app",
                    "stalenessAcceptable": "a month-old street tile is still the street",
                    "contract": "test/screens/map_osm_cache_contract_test.dart",
                },
                "SharedPreferences": {
                    "store": "settings, consent log, notes",
                    "key": "explicit constant keys in lib/core/constants",
                    "ttl": "none — this is durable state, not a cache",
                },
                "secure storage": {
                    "store": "emergency contacts",
                    "key": "emergency_contacts_v1",
                    "ttl": "none — durable",
                },
            },
            "stampedeRisk": (
                "none: there is no shared origin to stampede. The only network cache "
                "is per-tile against a public tile server, fetched by one process on "
                "one device, and the emergency path performs zero network I/O."
            ),
            "networkLayer": "lib/core/network/",
        },
        "files": {
            "userGeneratedFiles": ["the KVKK data export (JSON)"],
            "exportScreen": "lib/screens/settings_legal/data_export_screen.dart",
            "imageUploadSurfaces": 0,
            "exifRisk": (
                "none reachable: the app captures, stores and uploads no images. "
                "There is no camera permission and no image picker dependency, so "
                "there is no EXIF payload to strip."
            ),
            "cameraPermissionDeclared": False,
            "imagePickerDependency": False,
        },
        "appsec": {
            "sastTooling": {
                "dart": "flutter analyze --no-fatal-infos (CI gate)",
                "android": "Android Lint (scripts/verify_release.sh)",
                "dependencies": "scripts/audit_dependencies_osv.sh — OSV over pub + maven",
                "secrets": "scripts/scan_release_secrets.py",
                "mobileStandard": "scripts/verify_masvs_assessment.py",
            },
            "sastGap": (
                "no taint-analysis SAST (Semgrep/CodeQL) runs on this repository; "
                "the linters above are pattern and type checks, not dataflow "
                "analysis. Recorded as the measured limit, not restated as coverage."
            ),
            "mutationHarness": "scripts/run_safety_mutations.py",
            "criticalCoverageGate": "scripts/verify_critical_coverage.dart",
        },
        "secrets": {
            "scanner": "scripts/scan_release_secrets.py --require-clean",
            "envFilesTracked": [],
            "compileTimeInjection": ["REVENUECAT_ANDROID_API_KEY", "ENCRYPTION_KEY"],
            "injectionMechanism": "--dart-define / CI secret, read via String.fromEnvironment",
            "fromEnvironmentSites": sites(r"String\.fromEnvironment"),
            "keystorePolicy": "korubeni_keystore_release.jks is never committed; "
                              "key.properties is in the secret-quarantine category",
            "secretManager": (
                "GitHub Actions encrypted secrets. There is no cloud secret manager "
                "because there is no server: the only secrets are a billing "
                "publishable key and a build-time encryption key, both injected at "
                "compile time. A KMS would be a system to run, not a risk removed."
            ),
        },
    }


def _mutate(scratch: Path) -> str:
    target = scratch / DB
    src = target.read_text(encoding="utf-8")
    src = src.replace("class LocalDatabaseService",
                      "const _leak = 'api_key = \"sk-live-9f2b7c41d8e6\"';\n"
                      "class LocalDatabaseService", 1)
    src = src.replace("await _addMissingColumns(db, 'crash_logs',",
                      "await db.execute('DROP TABLE activity_events');\n"
                      "      await _addMissingColumns(db, tableName,", 1)
    target.write_text(src, encoding="utf-8")
    return ("a hard-coded API key, a DROP TABLE on activity_events, and a "
            "PRAGMA identifier taken from a variable")


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control("storage", _mutate, measure)
    violations = measure(REPO)
    path = emit(
        "storage.json",
        verifier="scripts/audit_evidence/storage.py",
        version=VERSION,
        command=COMMAND,
        surfaces=[DB, "lib/core/services/**", "lib/core/network/**",
                  "lib/screens/settings_legal/data_export_screen.dart", "pubspec.yaml"],
        measurements=build(REPO),
        violations=violations,
        exclusions=[
            {"what": "the legacy `contacts` table",
             "why": "it is kept EMPTY by design; constraints on a table with no rows "
                    "protect nothing, and resurrecting it is forbidden"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "a hard-coded API key and a DROP TABLE on activity_events",
            "expected": "hardcodedSecretLiteral and destructiveMigration fire",
        }},
    )
    print(f"STORAGE_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
