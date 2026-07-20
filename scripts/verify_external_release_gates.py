#!/usr/bin/env python3
"""Fail-closed verifier for KoruBeni's external release evidence manifest.

This script never creates evidence. It only proves that one immutable AAB is
bound to every required gate, soak, drill, finding disposition and approval.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

from verify_gate_evidence import (
    REQUIRED_APPROVAL_ROLES,
    REQUIRED_EVIDENCE_KINDS,
    REQUIRED_GATE_OWNERS,
    accountable_identity,
    exact_string_set,
    parse_utc,
    validate_gate_evidence,
)
from verify_masvs_assessment import validate_assessment


EXPECTED_GATES = {f"G{i}" for i in range(11)}
REQUIRED_PROVENANCE_ARTIFACTS = {
    "aab",
    "androidReleaseSurface",
    "sbom",
    "mergedManifest",
    "r8Mapping",
    "dartSymbolsIndex",
    "nativeSymbolsIndex",
    "criticalCoverage",
    "mutationReport",
    "lintReport",
    "dependencyLockPub",
    "dependencyLockGradle",
    "gradleVerification",
    "sourceProvenance",
    "secretScan",
    "osvAudit",
    "thirdPartyNotices",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()
TAG_RE = re.compile(r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
WORKFLOW_URL_RE = re.compile(
    r"^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+$"
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def read_json_artifact(
    name: str,
    artifacts: dict[str, Path],
    errors: list[str],
) -> dict[str, object] | None:
    path = artifacts.get(name)
    if path is None or not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        errors.append(f"provenance artifact {name} cannot be parsed: {exc}")
        return None
    if not isinstance(payload, dict):
        errors.append(f"provenance artifact {name} must be a JSON object")
        return None
    return payload


def validate_clean_source_binding(
    name: str,
    payload: dict[str, object],
    candidate: dict[str, object],
    errors: list[str],
) -> None:
    source = payload.get("source")
    require(isinstance(source, dict), f"{name} source is missing", errors)
    if not isinstance(source, dict):
        return
    require(
        source.get("gitCommit") == candidate.get("gitCommit"),
        f"{name} gitCommit mismatch",
        errors,
    )
    require(
        source.get("gitTree") == candidate.get("gitTree"),
        f"{name} gitTree mismatch",
        errors,
    )
    require(source.get("sourceWasDirty") is False, f"{name} source is dirty", errors)
    require(
        source.get("sourceStatusSha256") == EMPTY_SHA256,
        f"{name} clean source status hash mismatch",
        errors,
    )


def validate_candidate_security_artifacts(
    artifacts: dict[str, Path],
    candidate: dict[str, object],
    errors: list[str],
) -> None:
    secret_scan = read_json_artifact("secretScan", artifacts, errors)
    if secret_scan is not None:
        require(secret_scan.get("schemaVersion") == 2, "secretScan schemaVersion must be 2", errors)
        require(secret_scan.get("status") == "PASS", "secretScan is not PASS", errors)
        require(
            secret_scan.get("mode") == "tracked-candidate",
            "secretScan mode is not tracked-candidate",
            errors,
        )
        require(parse_utc(secret_scan.get("scannedAt")) is not None, "secretScan scannedAt is invalid", errors)
        require(secret_scan.get("findingCount") == 0, "secretScan contains findings", errors)
        validate_clean_source_binding("secretScan", secret_scan, candidate, errors)
        scanner = secret_scan.get("scanner")
        require(isinstance(scanner, dict), "secretScan scanner identity is missing", errors)
        if isinstance(scanner, dict):
            require(
                scanner.get("name") == "scan_release_secrets.py",
                "secretScan scanner name mismatch",
                errors,
            )
            require(
                bool(SHA256_RE.fullmatch(str(scanner.get("sha256", "")))),
                "secretScan scanner hash is invalid",
                errors,
            )
        for field in ("pathSetSha256", "contentSetSha256"):
            require(
                bool(SHA256_RE.fullmatch(str(secret_scan.get(field, "")))),
                f"secretScan {field} is invalid",
                errors,
            )
        input_count = secret_scan.get("inputPathCount")
        text_count = secret_scan.get("scannedTextFileCount")
        binary_count = secret_scan.get("skippedBinaryFileCount")
        counts_are_ints = all(
            isinstance(value, int) and not isinstance(value, bool) and value >= 0
            for value in (input_count, text_count, binary_count)
        )
        require(counts_are_ints, "secretScan file counts are invalid", errors)
        if counts_are_ints:
            require(input_count > 0, "secretScan scanned no files", errors)
            require(
                text_count + binary_count == input_count,
                "secretScan file counts do not reconcile",
                errors,
            )

    osv_audit = read_json_artifact("osvAudit", artifacts, errors)
    if osv_audit is not None:
        require(osv_audit.get("schemaVersion") == 1, "osvAudit schemaVersion must be 1", errors)
        require(osv_audit.get("status") == "PASS", "osvAudit is not PASS", errors)
        require(osv_audit.get("findingCount") == 0, "osvAudit contains findings", errors)
        require(osv_audit.get("findings") == [], "osvAudit findings must be empty", errors)
        require(
            osv_audit.get("endpoint") == "https://api.osv.dev/v1/querybatch",
            "osvAudit endpoint mismatch",
            errors,
        )
        require(
            osv_audit.get("interpretation") == "noKnownFindingsAtScanTime",
            "osvAudit interpretation mismatch",
            errors,
        )
        require(parse_utc(osv_audit.get("scannedAt")) is not None, "osvAudit scannedAt is invalid", errors)
        validate_clean_source_binding("osvAudit", osv_audit, candidate, errors)
        inputs = osv_audit.get("inputs")
        require(isinstance(inputs, dict), "osvAudit inputs are missing", errors)
        if isinstance(inputs, dict):
            pub_lock = artifacts.get("dependencyLockPub")
            gradle_lock = artifacts.get("dependencyLockGradle")
            if pub_lock is not None and pub_lock.is_file():
                require(
                    inputs.get("pubspecLockSha256") == sha256(pub_lock),
                    "osvAudit pubspec lock hash mismatch",
                    errors,
                )
            if gradle_lock is not None and gradle_lock.is_file():
                require(
                    inputs.get("gradleLockSha256") == sha256(gradle_lock),
                    "osvAudit Gradle lock hash mismatch",
                    errors,
                )
            for field in ("runnerSha256", "generatorSha256"):
                require(
                    bool(SHA256_RE.fullmatch(str(inputs.get(field, "")))),
                    f"osvAudit {field} is invalid",
                    errors,
                )
        ecosystems = osv_audit.get("ecosystems")
        require(
            isinstance(ecosystems, dict) and set(ecosystems) == {"Pub", "Maven"},
            "osvAudit ecosystem set mismatch",
            errors,
        )
        if isinstance(ecosystems, dict):
            for ecosystem in ("Pub", "Maven"):
                record = ecosystems.get(ecosystem)
                require(isinstance(record, dict), f"osvAudit {ecosystem} record is missing", errors)
                if not isinstance(record, dict):
                    continue
                query_count = record.get("queryCount")
                require(
                    isinstance(query_count, int)
                    and not isinstance(query_count, bool)
                    and query_count > 0,
                    f"osvAudit {ecosystem} queryCount is invalid",
                    errors,
                )
                require(
                    record.get("findingCount") == 0,
                    f"osvAudit {ecosystem} contains findings",
                    errors,
                )
                for field in ("querySha256", "responseSha256"):
                    require(
                        bool(SHA256_RE.fullmatch(str(record.get(field, "")))),
                        f"osvAudit {ecosystem} {field} is invalid",
                        errors,
                    )


def validate_provenance(
    provenance: object,
    candidate: dict[str, object],
    actual_aab_hash: str,
    evidence_root: Path,
    provenance_path: Path,
    candidate_aab_path: Path,
    errors: list[str],
) -> None:
    require(isinstance(provenance, dict), "provenance payload must be an object", errors)
    if not isinstance(provenance, dict):
        return
    require(provenance.get("schemaVersion") == 2, "provenance schemaVersion must be 2", errors)

    source = provenance.get("source")
    require(isinstance(source, dict), "provenance source is missing", errors)
    if isinstance(source, dict):
        require(source.get("gitCommit") == candidate.get("gitCommit"), "provenance gitCommit mismatch", errors)
        require(source.get("gitTree") == candidate.get("gitTree"), "provenance gitTree mismatch", errors)
        signed_tag = source.get("signedTag")
        require(isinstance(signed_tag, dict), "provenance signedTag is missing", errors)
        if isinstance(signed_tag, dict):
            require(signed_tag.get("name") == candidate.get("tag"), "provenance tag mismatch", errors)
            require(
                signed_tag.get("objectSha") == candidate.get("tagObjectSha"),
                "provenance tag object mismatch",
                errors,
            )

    provenance_candidate = provenance.get("candidate")
    require(isinstance(provenance_candidate, dict), "provenance candidate is missing", errors)
    if isinstance(provenance_candidate, dict):
        require(
            provenance_candidate.get("versionName") == candidate.get("versionName"),
            "provenance versionName mismatch",
            errors,
        )
        require(
            provenance_candidate.get("versionCode") == candidate.get("versionCode"),
            "provenance versionCode mismatch",
            errors,
        )
        require(
            provenance_candidate.get("aabSha256") == actual_aab_hash,
            "provenance AAB SHA-256 mismatch",
            errors,
        )

    signing = provenance.get("signing")
    require(isinstance(signing, dict), "provenance signing is missing", errors)
    if isinstance(signing, dict):
        require(
            signing.get("uploadCertificateSha256") == candidate.get("uploadCertificateSha256"),
            "provenance upload certificate mismatch",
            errors,
        )
        require(
            signing.get("playAppSigningCertificateSha256")
            == candidate.get("playAppSigningCertificateSha256"),
            "provenance Play app-signing certificate mismatch",
            errors,
        )

    workflow = provenance.get("workflow")
    require(isinstance(workflow, dict), "provenance workflow is missing", errors)
    if isinstance(workflow, dict):
        require(
            workflow.get("runUrl") == candidate.get("workflowRunUrl"),
            "provenance workflow URL mismatch",
            errors,
        )

    artifacts = provenance.get("artifacts")
    require(isinstance(artifacts, dict), "provenance artifacts are missing", errors)
    if isinstance(artifacts, dict):
        require(
            set(artifacts) == REQUIRED_PROVENANCE_ARTIFACTS,
            "provenance artifact set mismatch",
            errors,
        )
        resolved_artifacts: dict[str, Path] = {}
        seen_artifact_paths: set[Path] = set()
        for name, record in artifacts.items():
            require(isinstance(record, dict), f"provenance artifact {name} is malformed", errors)
            if isinstance(record, dict):
                artifact_hash = str(record.get("sha256", "")).lower()
                require(
                    bool(SHA256_RE.fullmatch(artifact_hash)),
                    f"provenance artifact {name} hash is invalid",
                    errors,
                )
                raw_path = record.get("path")
                require(
                    isinstance(raw_path, str) and bool(raw_path.strip()),
                    f"provenance artifact {name} path is missing",
                    errors,
                )
                if isinstance(raw_path, str) and raw_path.strip():
                    declared_path = Path(raw_path)
                    if declared_path.is_absolute():
                        path_candidates = {declared_path.resolve()}
                    else:
                        path_candidates = {
                            (Path.cwd() / declared_path).resolve(),
                            (evidence_root / declared_path).resolve(),
                            (provenance_path.parent / declared_path).resolve(),
                        }
                    existing_candidates = {
                        path for path in path_candidates if path.is_file()
                    }
                    require(
                        len(existing_candidates) <= 1,
                        f"provenance artifact {name} path is ambiguous",
                        errors,
                    )
                    artifact_path = (
                        next(iter(existing_candidates))
                        if existing_candidates
                        else next(iter(path_candidates))
                    )
                    try:
                        artifact_path.relative_to(evidence_root)
                    except ValueError:
                        errors.append(f"provenance artifact {name} escapes the evidence directory")
                    else:
                        require(
                            artifact_path not in seen_artifact_paths,
                            f"provenance artifact path reused: {raw_path}",
                            errors,
                        )
                        seen_artifact_paths.add(artifact_path)
                        resolved_artifacts[name] = artifact_path
                        require(
                            artifact_path.is_file(),
                            f"provenance artifact {name} is missing",
                            errors,
                        )
                        declared_size = record.get("sizeBytes")
                        require(
                            isinstance(declared_size, int)
                            and not isinstance(declared_size, bool)
                            and declared_size > 0,
                            f"provenance artifact {name} sizeBytes is invalid",
                            errors,
                        )
                        if artifact_path.is_file():
                            require(
                                artifact_path.stat().st_size == declared_size,
                                f"provenance artifact {name} size mismatch",
                                errors,
                            )
                            if SHA256_RE.fullmatch(artifact_hash):
                                require(
                                    sha256(artifact_path) == artifact_hash,
                                    f"provenance artifact {name} hash mismatch",
                                    errors,
                                )
        aab_record = artifacts.get("aab")
        if isinstance(aab_record, dict):
            require(
                str(aab_record.get("sha256", "")).lower() == actual_aab_hash,
                "provenance aab artifact hash mismatch",
                errors,
            )
            require(
                resolved_artifacts.get("aab") == candidate_aab_path.resolve(),
                "provenance aab artifact path does not match candidate AAB",
                errors,
            )
        validate_candidate_security_artifacts(resolved_artifacts, candidate, errors)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--aab", required=True, type=Path)
    args = parser.parse_args()
    errors: list[str] = []

    require(args.manifest.is_file(), "manifest file is missing", errors)
    require(args.aab.is_file(), "candidate AAB is missing", errors)
    if errors:
        return fail(errors)

    try:
        payload = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return fail([f"manifest cannot be parsed: {exc}"])

    require(payload.get("schemaVersion") == 2, "schemaVersion must be 2", errors)
    candidate = payload.get("candidate")
    require(isinstance(candidate, dict), "candidate object is required", errors)
    if not isinstance(candidate, dict):
        return fail(errors)

    commit = str(candidate.get("gitCommit", ""))
    tree = str(candidate.get("gitTree", ""))
    tag = str(candidate.get("tag", ""))
    tag_object = str(candidate.get("tagObjectSha", ""))
    version_name = str(candidate.get("versionName", ""))
    raw_version_code = candidate.get("versionCode")
    version_code = (
        raw_version_code
        if isinstance(raw_version_code, int) and not isinstance(raw_version_code, bool)
        else 0
    )
    expected_aab_hash = str(candidate.get("aabSha256", "")).lower()
    upload_cert = str(candidate.get("uploadCertificateSha256", "")).lower()
    play_cert = str(candidate.get("playAppSigningCertificateSha256", "")).lower()
    workflow_run_url = str(candidate.get("workflowRunUrl", ""))
    require(bool(COMMIT_RE.fullmatch(commit)), "gitCommit must be 40 lowercase hex", errors)
    require(bool(COMMIT_RE.fullmatch(tree)), "gitTree must be 40 lowercase hex", errors)
    require(bool(TAG_RE.fullmatch(tag)), "tag must be strict vMAJOR.MINOR.PATCH", errors)
    require(bool(COMMIT_RE.fullmatch(tag_object)), "tagObjectSha must be 40 lowercase hex", errors)
    require(version_name == tag.removeprefix("v"), "versionName must match tag", errors)
    require(
        version_code > 0,
        "versionCode must be a positive integer",
        errors,
    )
    require(bool(SHA256_RE.fullmatch(expected_aab_hash)), "aabSha256 is invalid", errors)
    require(bool(SHA256_RE.fullmatch(upload_cert)), "upload certificate SHA-256 is invalid", errors)
    require(bool(SHA256_RE.fullmatch(play_cert)), "Play app-signing certificate SHA-256 is invalid", errors)
    require(bool(WORKFLOW_URL_RE.fullmatch(workflow_run_url)), "workflowRunUrl is invalid", errors)
    actual_aab_hash = sha256(args.aab)
    require(actual_aab_hash == expected_aab_hash, "AAB SHA-256 does not match manifest", errors)

    manifest_dir = args.manifest.resolve().parent
    provenance_ref = candidate.get("provenance")
    require(isinstance(provenance_ref, dict), "candidate provenance reference is required", errors)
    if isinstance(provenance_ref, dict):
        provenance_rel = str(provenance_ref.get("path", ""))
        provenance_hash = str(provenance_ref.get("sha256", "")).lower()
        require(bool(SHA256_RE.fullmatch(provenance_hash)), "provenance reference hash is invalid", errors)
        provenance_path = (manifest_dir / provenance_rel).resolve()
        try:
            provenance_path.relative_to(manifest_dir)
        except ValueError:
            errors.append("provenance path escapes the evidence directory")
        else:
            require(provenance_path.is_file(), "provenance file is missing", errors)
            if provenance_path.is_file() and SHA256_RE.fullmatch(provenance_hash):
                require(sha256(provenance_path) == provenance_hash, "provenance file hash mismatch", errors)
                try:
                    provenance_payload = json.loads(provenance_path.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError) as exc:
                    errors.append(f"provenance cannot be parsed: {exc}")
                else:
                    evidence_root = Path(
                        os.path.commonpath([manifest_dir, args.aab.resolve()])
                    ).resolve()
                    require(
                        evidence_root != Path(evidence_root.anchor),
                        "candidate evidence package has no bounded common root",
                        errors,
                    )
                    validate_provenance(
                        provenance_payload,
                        candidate,
                        actual_aab_hash,
                        evidence_root,
                        provenance_path,
                        args.aab,
                        errors,
                    )

    gates = payload.get("gates")
    require(isinstance(gates, list), "gates must be an array", errors)
    seen: set[str] = set()
    g4_masvs_paths: list[Path] = []
    used_evidence_paths: set[Path] = set()
    typed_evidence_payloads: dict[str, dict[str, object]] = {}
    if isinstance(gates, list):
        for gate in gates:
            if not isinstance(gate, dict):
                errors.append("every gate must be an object")
                continue
            gate_id = str(gate.get("id", ""))
            require(gate_id in EXPECTED_GATES, f"unknown gate id: {gate_id}", errors)
            require(gate_id not in seen, f"duplicate gate: {gate_id}", errors)
            seen.add(gate_id)
            require(gate.get("status") == "PASS", f"{gate_id} is not PASS", errors)
            owners = gate.get("owners")
            require(
                isinstance(owners, list)
                and exact_string_set(owners) == REQUIRED_GATE_OWNERS.get(gate_id, set()),
                f"{gate_id} owner set mismatch",
                errors,
            )
            declared_kinds = gate.get("requiredEvidenceKinds")
            expected_kinds = REQUIRED_EVIDENCE_KINDS.get(gate_id, set())
            require(
                isinstance(declared_kinds, list)
                and exact_string_set(declared_kinds) == expected_kinds,
                f"{gate_id} requiredEvidenceKinds mismatch",
                errors,
            )
            evidence = gate.get("evidence")
            require(
                isinstance(evidence, list) and bool(evidence),
                f"{gate_id} has no evidence",
                errors,
            )
            if not isinstance(evidence, list):
                continue
            actual_kinds: list[str] = []
            for item in evidence:
                if not isinstance(item, dict):
                    errors.append(f"{gate_id} evidence must be an object")
                    continue
                rel_path = str(item.get("path", ""))
                kind = str(item.get("kind", ""))
                actual_kinds.append(kind)
                item_hash = str(item.get("sha256", "")).lower()
                require(kind in expected_kinds, f"{gate_id}:{rel_path} has unexpected kind {kind}", errors)
                require(item.get("candidateBound") is True, f"{gate_id}:{rel_path} is not candidate-bound", errors)
                require(bool(SHA256_RE.fullmatch(item_hash)), f"{gate_id}:{rel_path} has invalid hash", errors)
                evidence_path = (manifest_dir / rel_path).resolve()
                try:
                    evidence_path.relative_to(manifest_dir)
                except ValueError:
                    errors.append(f"{gate_id}:{rel_path} escapes the evidence directory")
                    continue
                require(evidence_path not in used_evidence_paths, f"evidence path reused: {rel_path}", errors)
                used_evidence_paths.add(evidence_path)
                require(evidence_path.is_file(), f"{gate_id}:{rel_path} is missing", errors)
                if evidence_path.is_file() and SHA256_RE.fullmatch(item_hash):
                    require(sha256(evidence_path) == item_hash, f"{gate_id}:{rel_path} hash mismatch", errors)
                if gate_id == "G4" and kind == "masvsAssessment":
                    g4_masvs_paths.append(evidence_path)
                elif kind in expected_kinds and evidence_path.is_file():
                    gate_errors = validate_gate_evidence(
                        evidence_path,
                        gate_id,
                        kind,
                        actual_aab_hash,
                        "com.poyrazoncel.korubeni",
                        version_name,
                        version_code,
                    )
                    errors.extend(f"{gate_id} {kind}: {error}" for error in gate_errors)
                    try:
                        typed_payload = json.loads(evidence_path.read_text(encoding="utf-8"))
                    except (OSError, json.JSONDecodeError):
                        typed_payload = None
                    if isinstance(typed_payload, dict):
                        require(kind not in typed_evidence_payloads, f"duplicate typed evidence kind: {kind}", errors)
                        typed_evidence_payloads[kind] = typed_payload
            require(
                set(actual_kinds) == expected_kinds and len(actual_kinds) == len(expected_kinds),
                f"{gate_id} evidence kind set mismatch",
                errors,
            )

    require(seen == EXPECTED_GATES, f"gate set mismatch: found {sorted(seen)}", errors)
    require(
        len(g4_masvs_paths) == 1,
        "G4 requires one candidate-bound MASVS assessment",
        errors,
    )
    if len(g4_masvs_paths) == 1 and g4_masvs_paths[0].is_file():
        masvs_errors = validate_assessment(
            g4_masvs_paths[0],
            args.aab,
            "com.poyrazoncel.korubeni",
            version_name,
            version_code,
        )
        errors.extend(f"G4 MASVS: {error}" for error in masvs_errors)

    findings = payload.get("openFindings")
    require(isinstance(findings, list), "openFindings must be an array", errors)
    if isinstance(findings, list):
        for finding in findings:
            if isinstance(finding, dict) and finding.get("severity") in {"P0", "P1"}:
                errors.append("open P0/P1 finding blocks release")

    soak = payload.get("closedSoak")
    require(isinstance(soak, dict), "closedSoak object is required", errors)
    if isinstance(soak, dict):
        require(soak.get("status") == "PASS", "closed soak is not PASS", errors)
        require(isinstance(soak.get("days"), int) and soak["days"] >= 14, "closed soak is shorter than 14 days", errors)
        require(isinstance(soak.get("testers"), int) and soak["testers"] >= 12, "closed soak has fewer than 12 testers", errors)
        require(soak.get("safetyIncidents") == 0, "closed soak has a safety incident", errors)
        require(str(soak.get("aabSha256", "")).lower() == expected_aab_hash, "closed soak used a different AAB", errors)
        soak_report = typed_evidence_payloads.get("closedSoakReport")
        soak_metrics = soak_report.get("metrics") if isinstance(soak_report, dict) else None
        if isinstance(soak_metrics, dict):
            require(
                soak.get("testers") == soak_metrics.get("testers"),
                "closed soak testers do not match typed report",
                errors,
            )
            require(
                soak.get("safetyIncidents") == soak_metrics.get("safetyIncidents"),
                "closed soak incidents do not match typed report",
                errors,
            )
            started_at = parse_utc(soak_metrics.get("startedAt"))
            finished_at = parse_utc(soak_metrics.get("finishedAt"))
            if started_at is not None and finished_at is not None:
                complete_days = int((finished_at - started_at).total_seconds() // 86_400)
                require(
                    soak.get("days") == complete_days,
                    "closed soak days do not match typed report",
                    errors,
                )

    drill = payload.get("hotfixDrill")
    require(isinstance(drill, dict) and drill.get("status") == "PASS", "hotfix drill is not PASS", errors)
    if isinstance(drill, dict):
        duration = drill.get("durationMinutes")
        require(
            isinstance(duration, int)
            and not isinstance(duration, bool)
            and 1 <= duration <= 120,
            "hotfix drill duration must be 1..120 minutes",
            errors,
        )
        reserved_code = drill.get("reservedVersionCode")
        require(
            isinstance(reserved_code, int)
            and not isinstance(reserved_code, bool)
            and reserved_code > version_code,
            "hotfix drill reservedVersionCode must exceed candidate",
            errors,
        )
        require(
            str(drill.get("aabSha256", "")).lower() == expected_aab_hash,
            "hotfix drill used a different AAB",
            errors,
        )
        drill_report = typed_evidence_payloads.get("hotfixDrillReport")
        drill_metrics = drill_report.get("metrics") if isinstance(drill_report, dict) else None
        if isinstance(drill_metrics, dict):
            require(
                drill.get("durationMinutes") == drill_metrics.get("durationMinutes"),
                "hotfix drill duration does not match typed report",
                errors,
            )
            require(
                drill.get("reservedVersionCode") == drill_metrics.get("reservedVersionCode"),
                "hotfix drill reservedVersionCode does not match typed report",
                errors,
            )

    approvals = payload.get("approvals")
    approved_roles: set[str] = set()
    seen_approval_roles: set[str] = set()
    if isinstance(approvals, list):
        for approval in approvals:
            if not isinstance(approval, dict):
                errors.append("approval record must be an object")
                continue
            role = str(approval.get("role", ""))
            require(role in REQUIRED_APPROVAL_ROLES, f"unknown approval role: {role}", errors)
            require(role not in seen_approval_roles, f"duplicate approval role: {role}", errors)
            seen_approval_roles.add(role)
            require(approval.get("decision") == "APPROVE", f"{role} did not approve", errors)
            require(accountable_identity(approval.get("signer")), f"{role} signer is not accountable", errors)
            approval_signed_at = parse_utc(approval.get("signedAt"))
            require(approval_signed_at is not None, f"{role} signedAt must be UTC", errors)
            soak_report = typed_evidence_payloads.get("closedSoakReport")
            soak_metrics = soak_report.get("metrics") if isinstance(soak_report, dict) else None
            soak_finished_at = parse_utc(soak_metrics.get("finishedAt")) if isinstance(soak_metrics, dict) else None
            if approval_signed_at is not None and soak_finished_at is not None:
                require(
                    approval_signed_at >= soak_finished_at,
                    f"{role} approval predates closed soak completion",
                    errors,
                )
            require(
                str(approval.get("candidateAabSha256", "")).lower() == expected_aab_hash,
                f"{role} approval used a different AAB",
                errors,
            )
            require(
                approval.get("versionCode") == version_code,
                f"{role} approval versionCode mismatch",
                errors,
            )
            approval_rel = approval.get("evidencePath")
            approval_hash = str(approval.get("evidenceSha256", "")).lower()
            require(
                isinstance(approval_rel, str) and bool(approval_rel.strip()),
                f"{role} approval evidencePath is required",
                errors,
            )
            require(
                bool(SHA256_RE.fullmatch(approval_hash)),
                f"{role} approval evidenceSha256 is invalid",
                errors,
            )
            require(
                approval.get("evidenceCandidateBound") is True,
                f"{role} approval evidence is not candidate-bound",
                errors,
            )
            if isinstance(approval_rel, str) and approval_rel.strip():
                approval_path = (manifest_dir / approval_rel).resolve()
                try:
                    approval_path.relative_to(manifest_dir)
                except ValueError:
                    errors.append(f"{role} approval evidence escapes the evidence directory")
                else:
                    require(
                        approval_path not in used_evidence_paths,
                        f"evidence path reused: {approval_rel}",
                        errors,
                    )
                    used_evidence_paths.add(approval_path)
                    require(approval_path.is_file(), f"{role} approval evidence is missing", errors)
                    if approval_path.is_file() and SHA256_RE.fullmatch(approval_hash):
                        require(
                            sha256(approval_path) == approval_hash,
                            f"{role} approval evidence hash mismatch",
                            errors,
                        )
                        try:
                            approval_payload = json.loads(approval_path.read_text(encoding="utf-8"))
                        except (OSError, json.JSONDecodeError) as exc:
                            errors.append(f"{role} approval evidence cannot be parsed: {exc}")
                        else:
                            require(isinstance(approval_payload, dict), f"{role} approval evidence must be an object", errors)
                            if isinstance(approval_payload, dict):
                                for field in (
                                    "role",
                                    "decision",
                                    "signer",
                                    "signedAt",
                                    "candidateAabSha256",
                                    "versionCode",
                                ):
                                    require(
                                        approval_payload.get(field) == approval.get(field),
                                        f"{role} approval evidence {field} mismatch",
                                        errors,
                                    )
            if approval.get("decision") == "APPROVE" and role in REQUIRED_APPROVAL_ROLES:
                approved_roles.add(role)
    require(
        approved_roles == REQUIRED_APPROVAL_ROLES,
        f"missing approvals: {sorted(REQUIRED_APPROVAL_ROLES - approved_roles)}",
        errors,
    )

    if errors:
        return fail(errors)
    print("MASTER_GO_NO_GO_PASS")
    print(f"candidate_aab_sha256={actual_aab_hash}")
    return 0


def fail(errors: list[str]) -> int:
    print("MASTER_GO_NO_GO_FAIL", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
