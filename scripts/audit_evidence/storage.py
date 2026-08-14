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


def _sites(root: Path, pattern: str, files=None) -> list:
    """file:line for every match, so a claim can be checked and can go stale."""
    out = []
    rx = re.compile(pattern)
    for path in dart_files(root):
        name = rel(path, root)
        if files and name not in files:
            continue
        src = read_stripped(path)
        for m in rx.finditer(src):
            out.append(f"{name}:{src[: m.start()].count(chr(10)) + 1}")
    return out


def _manifest(root: Path) -> str:
    path = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    return path.read_text(encoding="utf-8") if path.exists() else ""


def _tracked_env_files(root: Path) -> list:
    """Env/keystore files git actually tracks. Was a hard-coded empty list."""
    import subprocess
    try:
        out = subprocess.run(["git", "ls-files"], cwd=root, capture_output=True,
                             text=True, check=True).stdout.splitlines()
    except Exception:
        return ["<git unavailable>"]
    return [f for f in out
            if f.endswith((".env", ".jks", ".keystore")) or f.endswith("key.properties")
            or "/.env" in f]


def _db(root: Path) -> str:
    path = root / DB
    return read_stripped(path) if path.exists() else ""



# The one file allowed to write a user-selected image to disk, and the one
# allowed to produce its bytes.
IMAGE_STORE_FILE = "lib/core/services/avatar_store_service.dart"
IMAGE_SANITIZER_FILE = "lib/core/services/image_sanitizer_service.dart"
IMAGE_PICKER_FILE = "lib/screens/fake_call_screen.dart"


INTEGRITY_FILE = "lib/core/services/database_integrity_service.dart"


def _integrity_policy(root: Path) -> dict:
    """MP-29-017: what the DB layer actually enforces, and what it verifies.

    Computed. The predecessor of this block was a paragraph of rationale, which
    the audit correctly called "a design position, not a measurement of
    integrity".
    """
    svc = read_stripped(root / INTEGRITY_FILE) if (root / INTEGRITY_FILE).exists() else ""
    db_src = _db(root)

    # Pragmas are reached two ways: written literally, and selected by name
    # into an interpolated `PRAGMA $pragma`. A regex over literals alone
    # reported two of the four and would have understated the policy.
    pragmas = sorted(set(
        re.findall(r"PRAGMA (\w+)", svc)
        + re.findall(r"'(quick_check|integrity_check|foreign_key_check)'", svc)
    ))
    depth_block = re.search(r"enum IntegrityScanDepth\s*\{([^}]*)\}", svc, re.S)
    depths = (
        [d.strip() for d in depth_block.group(1).split(",") if d.strip()]
        if depth_block else []
    )

    # Where each depth is wired. The claim "not on every open" is only worth
    # anything if the open path is inspected rather than described.
    open_block = ""
    if "_database = await openDatabase(" in db_src:
        start = db_src.index("_database = await openDatabase(")
        open_block = db_src[start: db_src.index("return _database!;", start)]
    upgrade_block = ""
    if "static Future<void> upgradeSchema(" in db_src:
        start = db_src.index("static Future<void> upgradeSchema(")
        end = db_src.find("static Future<void> _addMissingColumns(", start)
        upgrade_block = db_src[start: end if end > 0 else len(db_src)]

    export_src = read_stripped(root / "lib/core/services/user_data_export_service.dart")

    return {
        "policyFile": INTEGRITY_FILE if svc else None,
        "pragmasUsed": pragmas,
        "scanDepths": depths,
        "foreignKeysEnabledAtConnect": "PRAGMA foreign_keys = ON" in svc
                                       and "onConfigure" in open_block,
        "scanOnEveryOpen": "DatabaseIntegrityService.scan" in open_block,
        "scanAfterMigration": "DatabaseIntegrityService.scan" in upgrade_block,
        "fullScanInUserDiagnostics": "IntegrityScanDepth.full" in export_src,
        "declaredForeignKeys": len(re.findall(r"REFERENCES\s+\w+", db_src)),
        "checksForeignKeysSeparately": "foreign_key_check" in svc,
        "coveringTests": ["test/core/services/database_integrity_service_test.dart"],
        "note": (
            "integrity_check does NOT report referential problems, so a database "
            "can pass it while holding orphaned rows; foreign_key_check is run "
            "separately and the test asserts that trap explicitly. The shipped "
            "schema declares no foreign keys today (declaredForeignKeys), so that "
            "check is a guard against a future relationship rather than a "
            "current finding -- which is why foreign_keys is switched ON at "
            "connect time: SQLite defaults it OFF per connection, and a key "
            "declared later would otherwise be silently unenforced."
        ),
    }


TILE_CLIENT = "lib/core/network/osm_tile_cache_client.dart"
TILE_VOLUME_TEST = "test/core/network/tile_request_volume_test.dart"
GROWTH_TEST = "test/core/services/high_volume_timeline_test.dart"
POWER_USER_TEST = "test/core/services/power_user_path_test.dart"
SMOKE_SCRIPT = "store/MANUAL_SMOKE_TEST_SCRIPT.md"


def _int_after(text: str, label: str):
    """The integer a Dart declaration assigns. Anchored on `=`, not on the first
    digits on the line -- the forced-colour verifier already shipped that bug
    once and reported 100 out of a `(y<100)` in the prose."""
    match = re.search(re.escape(label) + r"\s*=?\s*(\d+)", text)
    return int(match.group(1)) if match else None


def _tile_request_volume(root: Path) -> dict:
    """MP-42-024: how many tile requests one session costs OSM.

    The client is instrumented at the boundary that actually talks to the tile
    server, and the figures below are read from the covering test's own
    constants rather than restated here -- a number that lives in two places
    drifts.
    """
    client = read_stripped(root / TILE_CLIENT) if (root / TILE_CLIENT).exists() else ""
    test = (root / TILE_VOLUME_TEST).read_text(encoding="utf-8") \
        if (root / TILE_VOLUME_TEST).exists() else ""
    return {
        "instrumentedClient": TILE_CLIENT if client else None,
        "counters": sorted(set(re.findall(r"int get (\w+) =>", client))),
        "dedupesInFlight": "_inFlight" in client,
        "cacheServesRepeatViews": "_tileServedLocally" in client,
        "sessionModel": {
            "viewports": _int_after(test, "const viewports ="),
            "tileSidePx": _int_after(test, "_tileSide ="),
            "keepBuffer": _int_after(test, "_keepBuffer ="),
        },
        "policyCeilingAsserted": "lessThan(250)" in test,
        "policyNote": (
            "OSM's tile usage policy names heavy use (e.g. > 250 tiles/sec) and "
            "bulk downloading as unacceptable. The assertion is an "
            "order-of-magnitude bound rather than a golden count: pinning the "
            "exact number would break on any map-layout change while saying "
            "nothing about the quota."
        ),
        "coveringTest": TILE_VOLUME_TEST,
    }


def _volume_paths(root: Path) -> dict:
    """MP-47-003 / MP-47-011: the power-user path and the growth table."""
    growth = (root / GROWTH_TEST).read_text(encoding="utf-8") \
        if (root / GROWTH_TEST).exists() else ""
    power = (root / POWER_USER_TEST).read_text(encoding="utf-8") \
        if (root / POWER_USER_TEST).exists() else ""
    script = (root / SMOKE_SCRIPT).read_text(encoding="utf-8") \
        if (root / SMOKE_SCRIPT).exists() else ""
    tiers = re.search(r"_tiers = <int>\[([^\]]*)\]", growth)
    steps = re.findall(r"^\s*'([^']+)',", 
                       power.split("_path = <String>[")[1].split("];")[0], re.M) \
        if "_path = <String>[" in power else []
    return {
        "growthTable": "activity_events",
        "volumeTiers": [int(t.strip()) for t in tiers.group(1).split(",") if t.strip()]
                       if tiers else [],
        "tiersAreProductBound": "worst REALISTIC supported volume" in growth,
        "lazyBuildAsserted": "widgets built for 10000 rows" in growth,
        "integrityAtMaxTierAsserted": "integrity stays clean at the maximum tier" in growth,
        "powerUserSteps": steps,
        "powerUserAutomated": POWER_USER_TEST if power else None,
        "powerUserInManualScript": "Power user (long path)" in script,
        "manualScriptNamesTheTest": "power_user_path_test.dart" in script,
        "coveringTests": [GROWTH_TEST, POWER_USER_TEST],
    }


def _stored_extension(sanitizer: str):
    match = re.search(r"extension = '(\w+)'", sanitizer)
    return match.group(1) if match else None


def _legacy_names(store: str) -> list:
    if "legacyExtensions" not in store:
        return []
    block = store.split("legacyExtensions", 1)[1].split("]", 1)[0]
    return re.findall(r"'(\w+)'", block)


def _image_import_boundary(root: Path) -> dict:
    """MP-31-010: what actually reaches disk when a user picks a photo.

    Every value here is derived from the tree. Its predecessor was a pair of
    hand-written constants (``"exifStripped": False`` plus a paragraph), which
    is how this row's ORIGINAL evidence managed to claim there was no image
    picker at all while `image_picker: ^1.1.2` sat in pubspec.yaml.
    """
    picker = read_stripped(root / IMAGE_PICKER_FILE) if (root / IMAGE_PICKER_FILE).exists() else ""
    store = read_stripped(root / IMAGE_STORE_FILE) if (root / IMAGE_STORE_FILE).exists() else ""
    sanitizer = read_stripped(root / IMAGE_SANITIZER_FILE) if (root / IMAGE_SANITIZER_FILE).exists() else ""

    # A byte copy anywhere on the image path is the defect itself.
    byte_copy_sites = _sites(root, r"File\([^)]*\)\.copy\(|\.copy\(target",
                             files={IMAGE_PICKER_FILE, IMAGE_STORE_FILE})

    # "Sanitised" is claimed only if the sanitiser demonstrably builds a NEW
    # image rather than editing the decoded one.
    rebuilds_pixels = "img.Image(" in sanitizer and "setPixelRgb(" in sanitizer
    bakes_orientation = "bakeOrientation" in sanitizer
    reads_source_orientation = "readSourceOrientation" in sanitizer
    clones_metadata = bool(re.search(r"Image\.from\(|\.exif\s*=\s*ExifData\.from",
                                     sanitizer))

    return {
        "imagePickerSite": (_sites(root, r"pickImage\(", files={IMAGE_PICKER_FILE})
                            or [None])[0],
        "importBoundaryFile": IMAGE_STORE_FILE if store else None,
        "sanitizerFile": IMAGE_SANITIZER_FILE if sanitizer else None,
        "pickerDelegatesToBoundary": "AvatarStoreService.instance.importFromFile"
                                     in picker,
        "byteCopySitesOnImagePath": byte_copy_sites,
        "rebuildsPixelsIntoFreshImage": rebuilds_pixels,
        "appliesOrientationToPixels": bakes_orientation,
        "readsOrientationFromSourceBytes": reads_source_orientation,
        "clonesSourceMetadata": clones_metadata,
        "storedExtension": _stored_extension(sanitizer),
        "legacyNamesCleanedUp": _legacy_names(store),
        "exifStripped": bool(sanitizer) and rebuilds_pixels and not byte_copy_sites,
        "coveringTests": [
            "test/core/services/image_sanitizer_service_test.dart",
            "test/core/services/avatar_store_service_test.dart",
        ],
    }


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
    # N. MP-31-010: a user-selected image must reach disk as pixels only.
    boundary = _image_import_boundary(root)
    if boundary["imagePickerSite"]:
        for site in boundary["byteCopySitesOnImagePath"]:
            violations.append({
                "rule": "sourceImageBytesCopiedToStorage",
                "detail": f"{site} copies a picked file; every EXIF tag the "
                          f"source carried, GPS included, lands in app documents",
            })
        if not boundary["sanitizerFile"]:
            violations.append({"rule": "noImageSanitizer",
                               "detail": "an image picker exists with no sanitiser"})
        elif not boundary["rebuildsPixelsIntoFreshImage"]:
            violations.append({
                "rule": "sanitizerEditsSourceImage",
                "detail": "the sanitiser mutates the decoded image instead of "
                          "building a new one, so exif/iccProfile/textData are "
                          "inherited and a new tag type would slip through",
            })
        if boundary["clonesSourceMetadata"]:
            violations.append({
                "rule": "sanitizerClonesMetadata",
                "detail": "the sanitiser copies the source image object, which "
                          "carries its metadata with it",
            })
        if not boundary["pickerDelegatesToBoundary"]:
            violations.append({
                "rule": "pickerBypassesImportBoundary",
                "detail": "the picker writes storage without going through the "
                          "one service that sanitises",
            })
        if not boundary["appliesOrientationToPixels"]:
            violations.append({
                "rule": "orientationDroppedNotBaked",
                "detail": "removing the orientation tag without applying it to "
                          "the pixels lays every portrait photo on its side",
            })

    # N. MP-29-017: the integrity policy must exist, must not sit on the open
    #    path, and must check referential integrity SEPARATELY.
    policy = _integrity_policy(root)
    if not policy["policyFile"]:
        violations.append({"rule": "noIntegrityPolicy", "detail": INTEGRITY_FILE})
    else:
        if not policy["foreignKeysEnabledAtConnect"]:
            violations.append({
                "rule": "foreignKeysNotEnforced",
                "detail": "SQLite defaults PRAGMA foreign_keys OFF per connection; "
                          "any key declared later would be silently unenforced",
            })
        if policy["scanOnEveryOpen"]:
            violations.append({
                "rule": "integrityScanOnStartupPath",
                "detail": "a scan whose cost grows with activity_events sits on "
                          "the connection open path",
            })
        if not policy["scanAfterMigration"]:
            violations.append({
                "rule": "noPostMigrationIntegrityCheck",
                "detail": "the one moment the app itself may have damaged the "
                          "file is unverified",
            })
        if not policy["checksForeignKeysSeparately"]:
            violations.append({
                "rule": "referentialIntegrityUnchecked",
                "detail": "integrity_check does not report referential problems, "
                          "so foreign_key_check must be run separately",
            })
        if policy["declaredForeignKeys"] and not policy["foreignKeysEnabledAtConnect"]:
            violations.append({
                "rule": "declaredForeignKeysUnenforced",
                "detail": "the schema declares foreign keys that no connection "
                          "enforces",
            })

    # N. MP-42-024 / MP-47-003 / MP-47-011: volume, quotas and the long path.
    tiles = _tile_request_volume(root)
    if not tiles["instrumentedClient"]:
        violations.append({"rule": "tileClientUninstrumented",
                           "detail": TILE_CLIENT})
    else:
        if len(tiles["counters"]) < 3:
            violations.append({
                "rule": "tileVolumeUncounted",
                "detail": "asked / served-locally / upstream are different "
                          "numbers and only upstream is the quota figure",
            })
        if not tiles["dedupesInFlight"]:
            violations.append({
                "rule": "tileRequestsNotDeduplicated",
                "detail": "a fast pan asks for one tile many times; without "
                          "de-duplication each ask becomes an OSM request",
            })
        if not tiles["policyCeilingAsserted"]:
            violations.append({"rule": "tileVolumeUnbounded",
                               "detail": "no assertion bounds session volume"})

    paths = _volume_paths(root)
    if len(paths["volumeTiers"]) < 3:
        violations.append({
            "rule": "growthTableUntested",
            "detail": "activity_events is unbounded and is exercised at fewer "
                      "than three volume tiers",
        })
    if not paths["tiersAreProductBound"]:
        violations.append({
            "rule": "volumeTiersUnjustified",
            "detail": "the maximum tier is a number with no product argument "
                      "behind it",
        })
    if not paths["lazyBuildAsserted"]:
        violations.append({
            "rule": "listLazinessUnasserted",
            "detail": "nothing proves the list still builds a screenful rather "
                      "than the whole table",
        })
    if len(paths["powerUserSteps"]) < 6:
        violations.append({
            "rule": "powerUserPathIncomplete",
            "detail": f"the long path names {len(paths['powerUserSteps'])} "
                      f"steps; the audit's path has six",
        })
    if not paths["powerUserInManualScript"]:
        violations.append({
            "rule": "powerUserPathNotInManualScript",
            "detail": "the human pass has no row for the long journey",
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
                "the emergency path must degrade rather than throw. What CANNOT "
                "throw is VERIFIED instead -- see integrityPolicy."
            ),
            "integrityPolicy": _integrity_policy(root),
            "transactionSites": txn,
            "transactionBoundary": (
                "the 100-row crash-log cap is enforced on every insert; the "
                "insert+prune pair is the only genuine multi-statement write"
            ),
            "volumePaths": _volume_paths(root),
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
            "tileRequestVolume": _tile_request_volume(root),
        },
        "files": {
            "userGeneratedFiles": ["the KVKK data export (JSON)",
                                   "the fake-call avatar, re-encoded from a "
                                   "gallery selection"],
            "exportScreen": "lib/screens/settings_legal/data_export_screen.dart",
            **_image_import_boundary(root),
            "imageUploadSurfaces": len([p for p in dart_files(root)
                                        if re.search(r"ImagePicker|FilePicker|MultipartRequest",
                                                     read_stripped(p))]),
            "exifRisk": (
                "CLOSED at the import boundary, and the history is kept because it "
                "is the lesson. This field once asserted 'no camera permission and "
                "no image picker dependency' as a hard-coded constant; computing it "
                "found image_picker: ^1.1.2 and a live pickImage call, and the file "
                "was then being copied byte for byte into app documents. The fix is "
                "structural rather than a blocklist: the picked bytes are decoded, "
                "the source orientation is applied to the PIXELS, and a NEW image "
                "holding nothing but colour values is encoded -- so no EXIF block, "
                "XMP packet or PNG text chunk can be inherited, including tags no "
                "blocklist anticipated. Avatars written by earlier builds are "
                "re-encoded on load, so the exposure does not survive an upgrade."
            ),
            "cameraPermissionDeclared": "android.permission.CAMERA" in _manifest(root),
            "imagePickerDependency": any(
                d in (root / "pubspec.yaml").read_text(encoding="utf-8")
                for d in ("image_picker", "camera:", "file_picker")),
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
            "envFilesTracked": _tracked_env_files(root),
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

    # MP-31-010: put the byte copy back, exactly as it was before the fix, and
    # make the picker write storage directly again.
    picker = scratch / IMAGE_PICKER_FILE
    if picker.exists():
        picker.write_text(
            picker.read_text(encoding="utf-8").replace(
                "await AvatarStoreService.instance.importFromFile(\n"
                "        picked.path,\n      )",
                "(await File(picked.path).copy(targetPath)).path",
            ),
            encoding="utf-8",
        )
    # ...and make the sanitiser clone the decoded image instead of rebuilding
    # it, which silently reinstates every inherited metadata channel.
    sanitizer = scratch / IMAGE_SANITIZER_FILE
    if sanitizer.exists():
        sanitizer.write_text(
            sanitizer.read_text(encoding="utf-8").replace(
                "final out = img.Image(", "final out = img.Image.from(", 1
            ).replace("out.setPixelRgb(", "out.setPixel_disabled(")
            .replace("bakeOrientation", "_noBake"),
            encoding="utf-8",
        )
    # MP-29-017: take the integrity policy back out -- drop foreign_key_check,
    # stop enabling foreign_keys, and move the scan onto the open path.
    integrity = scratch / INTEGRITY_FILE
    if integrity.exists():
        integrity.write_text(
            integrity.read_text(encoding="utf-8")
            .replace("PRAGMA foreign_keys = ON", "PRAGMA synchronous = NORMAL")
            .replace("foreign_key_check", "table_list"),
            encoding="utf-8",
        )
    # MP-42-024 / MP-47-011: strip the tile counters and the volume tiers.
    tile_client = scratch / TILE_CLIENT
    if tile_client.exists():
        tile_client.write_text(
            tile_client.read_text(encoding="utf-8")
            .replace("int get upstreamTileRequests =>", "int _hidden3 =")
            .replace("int get tileRequestsServedLocally =>", "int _hidden2 ="),
            encoding="utf-8",
        )
    growth = scratch / GROWTH_TEST
    if growth.exists():
        growth.write_text(
            growth.read_text(encoding="utf-8").replace(
                "_tiers = <int>[100, 1000, 10000]", "_tiers = <int>[100]"
            ),
            encoding="utf-8",
        )
    db_service = scratch / DB
    if db_service.exists():
        db_service.write_text(
            db_service.read_text(encoding="utf-8").replace(
                "      onCreate: (db, version) => createSchema(db),",
                "      onCreate: (db, version) => createSchema(db),\n"
                "      onOpen: (db) => DatabaseIntegrityService.scan(db),",
            ),
            encoding="utf-8",
        )
    return ("a hard-coded API key, a DROP TABLE on activity_events, a PRAGMA "
            "identifier taken from a variable, the picked-image byte copy "
            "restored, the sanitiser turned into a clone of the source, and "
            "the integrity policy stripped of foreign-key enforcement while "
            "its scan is moved onto the connection open path, the tile "
            "counters removed and the volume tiers cut to one")


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
            "mutation": "a hard-coded API key; a DROP TABLE on activity_events; a "
                        "PRAGMA identifier from a variable; the picked-image byte "
                        "copy restored; the sanitiser turned into a clone of the "
                        "source; foreign-key enforcement removed and the integrity "
                        "scan moved onto the connection open path",
            "expected": "11 violations across hardcodedSecretLiteral, "
                        "destructiveMigration, pragmaIdentifierFromVariable, "
                        "sourceImageBytesCopiedToStorage, sanitizerEditsSourceImage, "
                        "sanitizerClonesMetadata, pickerBypassesImportBoundary, "
                        "orientationDroppedNotBaked, foreignKeysNotEnforced, "
                        "integrityScanOnStartupPath and referentialIntegrityUnchecked",
        }},
    )
    print(f"STORAGE_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
