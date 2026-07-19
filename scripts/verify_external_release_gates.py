#!/usr/bin/env python3
"""Fail-closed verifier for KoruBeni's external release evidence manifest.

This script never creates evidence. It only proves that one immutable AAB is
bound to every required gate, soak, drill, finding disposition and approval.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

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
    "thirdPartyNotices",
}
REQUIRED_APPROVALS = {
    "product",
    "safety",
    "qa",
    "security",
    "privacy_legal",
    "billing_play",
    "release",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
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


def validate_provenance(
    provenance: object,
    candidate: dict[str, object],
    actual_aab_hash: str,
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
        for name, record in artifacts.items():
            require(isinstance(record, dict), f"provenance artifact {name} is malformed", errors)
            if isinstance(record, dict):
                artifact_hash = str(record.get("sha256", "")).lower()
                require(
                    bool(SHA256_RE.fullmatch(artifact_hash)),
                    f"provenance artifact {name} hash is invalid",
                    errors,
                )
        aab_record = artifacts.get("aab")
        if isinstance(aab_record, dict):
            require(
                str(aab_record.get("sha256", "")).lower() == actual_aab_hash,
                "provenance aab artifact hash mismatch",
                errors,
            )


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
                    validate_provenance(provenance_payload, candidate, actual_aab_hash, errors)

    gates = payload.get("gates")
    require(isinstance(gates, list), "gates must be an array", errors)
    seen: set[str] = set()
    g4_masvs_paths: list[Path] = []
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
            require(isinstance(owners, list) and bool(owners), f"{gate_id} has no owner", errors)
            evidence = gate.get("evidence")
            require(
                isinstance(evidence, list) and bool(evidence),
                f"{gate_id} has no evidence",
                errors,
            )
            if not isinstance(evidence, list):
                continue
            for item in evidence:
                if not isinstance(item, dict):
                    errors.append(f"{gate_id} evidence must be an object")
                    continue
                rel_path = str(item.get("path", ""))
                item_hash = str(item.get("sha256", "")).lower()
                require(item.get("candidateBound") is True, f"{gate_id}:{rel_path} is not candidate-bound", errors)
                require(bool(SHA256_RE.fullmatch(item_hash)), f"{gate_id}:{rel_path} has invalid hash", errors)
                evidence_path = (manifest_dir / rel_path).resolve()
                try:
                    evidence_path.relative_to(manifest_dir)
                except ValueError:
                    errors.append(f"{gate_id}:{rel_path} escapes the evidence directory")
                    continue
                require(evidence_path.is_file(), f"{gate_id}:{rel_path} is missing", errors)
                if evidence_path.is_file() and SHA256_RE.fullmatch(item_hash):
                    require(sha256(evidence_path) == item_hash, f"{gate_id}:{rel_path} hash mismatch", errors)
                if gate_id == "G4" and item.get("kind") == "masvsAssessment":
                    g4_masvs_paths.append(evidence_path)

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

    drill = payload.get("hotfixDrill")
    require(isinstance(drill, dict) and drill.get("status") == "PASS", "hotfix drill is not PASS", errors)

    approvals = payload.get("approvals")
    approved_roles: set[str] = set()
    if isinstance(approvals, list):
        for approval in approvals:
            if isinstance(approval, dict) and approval.get("decision") == "APPROVE":
                if approval.get("signer") and approval.get("signedAt"):
                    approved_roles.add(str(approval.get("role", "")))
    require(
        REQUIRED_APPROVALS.issubset(approved_roles),
        f"missing approvals: {sorted(REQUIRED_APPROVALS - approved_roles)}",
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
