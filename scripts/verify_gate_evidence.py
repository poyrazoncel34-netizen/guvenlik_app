#!/usr/bin/env python3
"""Validate typed, candidate-bound evidence for KoruBeni release gates."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path


REQUIRED_EVIDENCE_KINDS = {
    "G0": {"safetyCaseReview"},
    "G1": {"nativeKernelReport", "mutationReport"},
    "G2": {"flutterSessionReport"},
    "G3": {"androidPlatformMatrix"},
    "G4": {"masvsAssessment", "licensePolicyReport", "privacyCounselDecision"},
    "G5": {"qualityMatrix"},
    "G6": {"artifactChainReport"},
    "G7": {"physicalDeviceMatrix"},
    "G8": {"billingPlayMatrix", "playPolicyDisposition"},
    "G9": {"closedSoakReport"},
    "G10": {"hotfixDrillReport", "releaseBoardDecision"},
}

REQUIRED_GATE_OWNERS = {
    "G0": {"product", "safety"},
    "G1": {"android_safety"},
    "G2": {"flutter_safety"},
    "G3": {"android_platform"},
    "G4": {"security", "privacy_legal"},
    "G5": {"qa"},
    "G6": {"release"},
    "G7": {"qa", "independent_witness"},
    "G8": {"billing_play"},
    "G9": {"release_owner"},
    "G10": {"release_board"},
}

REQUIRED_APPROVAL_ROLES = {
    "product",
    "safety",
    "qa",
    "security",
    "privacy_legal",
    "billing_play",
    "release",
}

INDEPENDENT_EVIDENCE_KINDS = {
    "safetyCaseReview",
    "nativeKernelReport",
    "privacyCounselDecision",
    "physicalDeviceMatrix",
    "releaseBoardDecision",
}

HAZARD_IDS = {f"H{index:02d}" for index in range(1, 16)}
SUPPORTED_API_LEVELS = set(range(29, 37))
PHYSICAL_DEVICE_PROFILES = {
    "api29_boundary",
    "pixel_api36_16kb",
    "samsung_oneui",
    "xiaomi_hyperos",
}
BILLING_CASES = {
    "monthlyPurchase",
    "annualPurchase",
    "pending",
    "userCancel",
    "cancelledUntilExpiry",
    "restore",
    "reinstall",
    "renewal",
    "grace",
    "pauseResume",
    "accountHold",
    "refundRevoke",
    "expiryLapse",
    "multiGoogleAccount",
    "offlineCacheInside",
    "offlineCacheOutside",
    "noOffering",
    "networkFailure",
    "revenueCatOutage",
}
PLAY_POLICY_FORMS = {
    "dataSafety",
    "healthApps",
    "targetAudience",
    "contentRating",
    "appAccess",
    "privacyUrl",
    "deletionUrl",
}
ACCESSIBILITY_CHECKS = {
    "talkBack",
    "switchAccess",
    "accessibilityScanner",
    "font200Percent",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
PLACEHOLDER_MARKERS = ("replace", "placeholder", "dry-run", "example")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def parse_utc(value: object) -> datetime | None:
    if not isinstance(value, str) or not value.endswith("Z"):
        return None
    try:
        parsed = datetime.fromisoformat(value.removesuffix("Z") + "+00:00")
    except ValueError:
        return None
    return parsed if parsed.utcoffset() == timedelta(0) else None


def accountable_identity(value: object) -> bool:
    if not isinstance(value, str) or len(value.strip()) < 3:
        return False
    lowered = value.lower()
    return not any(marker in lowered for marker in PLACEHOLDER_MARKERS)


def exact_string_set(value: object) -> set[str] | None:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        return None
    return set(value)


def positive_int(value: object, minimum: int = 1) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= minimum


def nonnegative_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0


def require_true(metrics: dict[str, object], name: str, kind: str, errors: list[str]) -> None:
    require(metrics.get(name) is True, f"{kind}.{name} must be true", errors)


def require_zero(metrics: dict[str, object], name: str, kind: str, errors: list[str]) -> None:
    require(metrics.get(name) == 0, f"{kind}.{name} must be zero", errors)


def require_exact_pass_map(
    value: object,
    expected_keys: set[str],
    label: str,
    errors: list[str],
) -> None:
    require(isinstance(value, dict), f"{label} must be an object", errors)
    if not isinstance(value, dict):
        return
    require(set(value) == expected_keys, f"{label} key set mismatch", errors)
    for key in expected_keys:
        require(value.get(key) == "PASS", f"{label}.{key} is not PASS", errors)


def validate_metrics(
    kind: str,
    metrics: dict[str, object],
    version_code: int,
    errors: list[str],
) -> None:
    if kind == "safetyCaseReview":
        require_zero(metrics, "openS4", kind, errors)
        require_zero(metrics, "uncontrolledS3", kind, errors)
        hazards = metrics.get("hazards")
        require(isinstance(hazards, list), f"{kind}.hazards must be an array", errors)
        if isinstance(hazards, list):
            ids: set[str] = set()
            for item in hazards:
                if not isinstance(item, dict):
                    errors.append(f"{kind}.hazards contains a malformed record")
                    continue
                hazard_id = str(item.get("id", ""))
                require(hazard_id not in ids, f"{kind} duplicate hazard {hazard_id}", errors)
                ids.add(hazard_id)
                require(item.get("status") == "CONTROLLED", f"{kind}.{hazard_id} is not CONTROLLED", errors)
                control = item.get("controlEvidence")
                require(isinstance(control, str) and len(control.strip()) >= 10, f"{kind}.{hazard_id} lacks control evidence", errors)
            require(ids == HAZARD_IDS, f"{kind} hazard set mismatch", errors)
        return

    if kind == "nativeKernelReport":
        require(positive_int(metrics.get("nativeTests")), f"{kind}.nativeTests must be positive", errors)
        require(positive_int(metrics.get("modelOperations"), 10_000_000), f"{kind}.modelOperations is below 10000000", errors)
        require(positive_int(metrics.get("raceFamilies"), 5), f"{kind}.raceFamilies is below 5", errors)
        require(positive_int(metrics.get("interleavingsPerFamily"), 1_000), f"{kind}.interleavingsPerFamily is below 1000", errors)
        require_zero(metrics, "criticalSafetyViolations", kind, errors)
        return

    if kind == "mutationReport":
        total = metrics.get("total")
        killed = metrics.get("killed")
        require(positive_int(total, 6), f"{kind}.total is below 6", errors)
        require(killed == total, f"{kind}.killed must equal total", errors)
        require_true(metrics, "baselinePassed", kind, errors)
        return

    if kind == "flutterSessionReport":
        require(positive_int(metrics.get("dartTests")), f"{kind}.dartTests must be positive", errors)
        require(positive_int(metrics.get("criticalCoverageFiles"), 4), f"{kind}.criticalCoverageFiles is below 4", errors)
        coverage = metrics.get("minimumCriticalCoveragePercent")
        require(nonnegative_number(coverage) and float(coverage) >= 90.0, f"{kind}.minimumCriticalCoveragePercent is below 90", errors)
        for name in ("pinReadFailureProtected", "lifecycleCancelProtected", "falseCancelProtected"):
            require_true(metrics, name, kind, errors)
        return

    if kind == "androidPlatformMatrix":
        levels = metrics.get("apiLevels")
        valid_levels = (
            isinstance(levels, list)
            and all(isinstance(level, int) and not isinstance(level, bool) for level in levels)
            and set(levels) == SUPPORTED_API_LEVELS
        )
        require(valid_levels, f"{kind}.apiLevels must cover API 29-36", errors)
        for name in ("directBootReboot", "doze", "permissionRevokeRegrant", "telecomRequest", "playDeliveredCandidate"):
            require_true(metrics, name, kind, errors)
        require_zero(metrics, "criticalSafetyViolations", kind, errors)
        return

    if kind == "licensePolicyReport":
        components = metrics.get("components")
        require(positive_int(components), f"{kind}.components must be positive", errors)
        require(metrics.get("reviewed") == components, f"{kind}.reviewed must equal components", errors)
        require_zero(metrics, "unverified", kind, errors)
        require_true(metrics, "policyPassed", kind, errors)
        require_true(metrics, "noticesParity", kind, errors)
        return

    if kind == "privacyCounselDecision":
        require(metrics.get("decision") == "APPROVED", f"{kind}.decision is not APPROVED", errors)
        for name in ("fieldInventoryComplete", "transferMechanismsResolved", "deletionRunbookVerified"):
            require_true(metrics, name, kind, errors)
        return

    if kind == "qualityMatrix":
        require_exact_pass_map(metrics.get("accessibility"), ACCESSIBILITY_CHECKS, f"{kind}.accessibility", errors)
        for name in ("featureMatrixPassed", "migrationMatrixPassed"):
            require_true(metrics, name, kind, errors)
        require_zero(metrics, "criticalCrashAnr", kind, errors)
        thresholds = {
            "coldStartP95Ms": 4_000,
            "armAckP95Ms": 500,
            "receiverFallbackP95Ms": 1_000,
            "wakeLockMaxMs": 10_000,
            "idleBatteryDeltaPercentagePoints": 2,
        }
        for name, maximum in thresholds.items():
            value = metrics.get(name)
            require(nonnegative_number(value) and float(value) <= maximum, f"{kind}.{name} exceeds {maximum}", errors)
        return

    if kind == "artifactChainReport":
        for name in (
            "bundletoolValid", "arm64Only", "page16kCompatible", "signatureValid",
            "attestationVerified", "provenanceVerified", "sbomVerified",
            "symbolsComplete", "productionRevenueCatKey",
        ):
            require_true(metrics, name, kind, errors)
        require(metrics.get("buildCount") == 1, f"{kind}.buildCount must be 1", errors)
        return

    if kind == "physicalDeviceMatrix":
        results = metrics.get("deviceResults")
        require(isinstance(results, list), f"{kind}.deviceResults must be an array", errors)
        profiles: set[str] = set()
        if isinstance(results, list):
            for result in results:
                if not isinstance(result, dict):
                    errors.append(f"{kind}.deviceResults contains a malformed record")
                    continue
                profile = str(result.get("profile", ""))
                require(profile not in profiles, f"{kind} duplicate profile {profile}", errors)
                profiles.add(profile)
                for name in ("physical", "playInstalled"):
                    require(result.get(name) is True, f"{kind}.{profile}.{name} must be true", errors)
                for name, minimum in (("fakeDeadlines", 100), ("cancelRaces", 50), ("lifecycleCycles", 20)):
                    require(positive_int(result.get(name), minimum), f"{kind}.{profile}.{name} is below {minimum}", errors)
                for name in ("missedDeadlines", "confirmedCancelDispatches", "wrongTargets", "pinBypasses", "safetyCrashes"):
                    require(result.get(name) == 0, f"{kind}.{profile}.{name} must be zero", errors)
            require(profiles == PHYSICAL_DEVICE_PROFILES, f"{kind} device profile set mismatch", errors)
        require(positive_int(metrics.get("automaticRequestsObserved"), 10), f"{kind}.automaticRequestsObserved is below 10", errors)
        require(positive_int(metrics.get("manualDialObserved"), 10), f"{kind}.manualDialObserved is below 10", errors)
        require_zero(metrics, "criticalCrashAnr", kind, errors)
        return

    if kind == "billingPlayMatrix":
        require_exact_pass_map(metrics.get("cases"), BILLING_CASES, f"{kind}.cases", errors)
        require_true(metrics, "finalConfigurationRestored", kind, errors)
        require_true(metrics, "smokePurchaseRestorePassed", kind, errors)
        return

    if kind == "playPolicyDisposition":
        require_exact_pass_map(metrics.get("forms"), PLAY_POLICY_FORMS, f"{kind}.forms", errors)
        for name in ("bundleExplorer16kb", "permissionsMatchDeclarations", "noFgsFsiBackgroundLocation"):
            require_true(metrics, name, kind, errors)
        require_zero(metrics, "preLaunchOpenFindings", kind, errors)
        return

    if kind == "closedSoakReport":
        started = parse_utc(metrics.get("startedAt"))
        finished = parse_utc(metrics.get("finishedAt"))
        require(started is not None, f"{kind}.startedAt must be UTC", errors)
        require(finished is not None, f"{kind}.finishedAt must be UTC", errors)
        if started is not None and finished is not None:
            require(finished - started >= timedelta(days=14), f"{kind} duration is below 14 days", errors)
        require(positive_int(metrics.get("testers"), 12), f"{kind}.testers is below 12", errors)
        require(positive_int(metrics.get("manualProbeDays"), 14), f"{kind}.manualProbeDays is below 14", errors)
        for name in ("safetyIncidents", "openP0P1", "criticalCrashAnr", "purchaseRestoreFailures"):
            require_zero(metrics, name, kind, errors)
        require(metrics.get("aabChanged") is False, f"{kind}.aabChanged must be false", errors)
        require_true(metrics, "dashboardFrozen", kind, errors)
        return

    if kind == "hotfixDrillReport":
        duration = metrics.get("durationMinutes")
        require(positive_int(duration) and int(duration) <= 120, f"{kind}.durationMinutes must be 1..120", errors)
        for name in ("internalTrackReady", "nonUploadableArtifact", "regressionSelected"):
            require_true(metrics, name, kind, errors)
        reserved = metrics.get("reservedVersionCode")
        require(positive_int(reserved) and int(reserved) > version_code, f"{kind}.reservedVersionCode must exceed candidate", errors)
        return

    if kind == "releaseBoardDecision":
        require(metrics.get("decision") == "GO", f"{kind}.decision is not GO", errors)
        roles = metrics.get("approvedRoles")
        require(exact_string_set(roles) == REQUIRED_APPROVAL_ROLES, f"{kind}.approvedRoles mismatch", errors)
        require_zero(metrics, "openP0P1", kind, errors)
        require_zero(metrics, "safetyIncidents", kind, errors)
        return

    errors.append(f"unsupported evidence kind: {kind}")


def validate_gate_evidence(
    evidence_path: Path,
    gate_id: str,
    kind: str,
    actual_aab_hash: str,
    expected_package: str,
    expected_version_name: str,
    expected_version_code: int,
) -> list[str]:
    errors: list[str] = []
    require(gate_id in REQUIRED_EVIDENCE_KINDS, f"unknown gate id: {gate_id}", errors)
    require(kind in REQUIRED_EVIDENCE_KINDS.get(gate_id, set()), f"{gate_id} does not accept {kind}", errors)
    require(kind != "masvsAssessment", "MASVS assessment uses its dedicated verifier", errors)
    require(evidence_path.is_file(), "evidence file is missing", errors)
    if errors:
        return errors
    try:
        payload = json.loads(evidence_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"evidence cannot be parsed: {exc}"]
    if not isinstance(payload, dict):
        return ["evidence root must be an object"]

    require(payload.get("schemaVersion") == 1, "schemaVersion must be 1", errors)
    require(payload.get("evidenceType") == kind, "evidenceType mismatch", errors)
    require(payload.get("gateId") == gate_id, "gateId mismatch", errors)
    require(payload.get("status") == "PASS", "evidence status is not PASS", errors)
    summary = payload.get("summary")
    require(isinstance(summary, str) and len(summary.strip()) >= 20, "evidence summary is too short", errors)

    candidate = payload.get("candidate")
    require(isinstance(candidate, dict), "candidate object is required", errors)
    if isinstance(candidate, dict):
        require(candidate.get("packageName") == expected_package, "candidate package mismatch", errors)
        require(candidate.get("versionName") == expected_version_name, "candidate versionName mismatch", errors)
        require(candidate.get("versionCode") == expected_version_code, "candidate versionCode mismatch", errors)
        require(str(candidate.get("aabSha256", "")).lower() == actual_aab_hash, "candidate AAB SHA-256 mismatch", errors)

    review = payload.get("review")
    require(isinstance(review, dict), "review object is required", errors)
    if isinstance(review, dict):
        require(accountable_identity(review.get("performedBy")), "accountable performedBy is required", errors)
        require(parse_utc(review.get("performedAt")) is not None, "performedAt must be ISO-8601 UTC", errors)
        if kind in INDEPENDENT_EVIDENCE_KINDS:
            require(review.get("independentFromImplementation") is True, f"{kind} requires independent review", errors)

    artifacts = payload.get("artifacts")
    require(
        isinstance(artifacts, list) and bool(artifacts),
        "artifacts must be a non-empty array",
        errors,
    )
    artifact_paths: set[Path] = set()
    evidence_dir = evidence_path.resolve().parent
    if isinstance(artifacts, list):
        for artifact in artifacts:
            if not isinstance(artifact, dict):
                errors.append("artifact record must be an object")
                continue
            relative_path = str(artifact.get("path", ""))
            artifact_hash = str(artifact.get("sha256", "")).lower()
            description = artifact.get("description")
            require(artifact.get("candidateBound") is True, f"artifact {relative_path} is not candidate-bound", errors)
            require(bool(SHA256_RE.fullmatch(artifact_hash)), f"artifact {relative_path} has invalid SHA-256", errors)
            require(isinstance(description, str) and len(description.strip()) >= 10, f"artifact {relative_path} has no description", errors)
            artifact_path = (evidence_dir / relative_path).resolve()
            try:
                artifact_path.relative_to(evidence_dir)
            except ValueError:
                errors.append(f"artifact {relative_path} escapes the evidence directory")
                continue
            require(artifact_path != evidence_path.resolve(), f"artifact {relative_path} cannot reference its own report", errors)
            require(artifact_path not in artifact_paths, f"duplicate artifact path: {relative_path}", errors)
            artifact_paths.add(artifact_path)
            require(artifact_path.is_file(), f"artifact {relative_path} is missing", errors)
            if artifact_path.is_file() and SHA256_RE.fullmatch(artifact_hash):
                require(sha256(artifact_path) == artifact_hash, f"artifact {relative_path} hash mismatch", errors)

    metrics = payload.get("metrics")
    require(isinstance(metrics, dict), "metrics object is required", errors)
    if isinstance(metrics, dict):
        validate_metrics(kind, metrics, expected_version_code, errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--gate", required=True)
    parser.add_argument("--kind", required=True)
    parser.add_argument("--aab", required=True, type=Path)
    parser.add_argument("--expected-package", required=True)
    parser.add_argument("--expected-version-name", required=True)
    parser.add_argument("--expected-version-code", required=True, type=int)
    args = parser.parse_args()
    if not args.aab.is_file():
        print("GATE_EVIDENCE_FAIL\n- candidate AAB is missing", file=sys.stderr)
        return 1
    errors = validate_gate_evidence(
        args.evidence,
        args.gate,
        args.kind,
        sha256(args.aab),
        args.expected_package,
        args.expected_version_name,
        args.expected_version_code,
    )
    if errors:
        print("GATE_EVIDENCE_FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("GATE_EVIDENCE_PASS")
    print(f"gate={args.gate} kind={args.kind} candidate_aab_sha256={sha256(args.aab)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
