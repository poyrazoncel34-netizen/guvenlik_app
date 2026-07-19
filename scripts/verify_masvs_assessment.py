#!/usr/bin/env python3
"""Fail-closed verifier for one candidate-bound OWASP MASVS assessment."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path


CONTROL_IDS = {
    "MASVS-STORAGE-1",
    "MASVS-STORAGE-2",
    "MASVS-CRYPTO-1",
    "MASVS-CRYPTO-2",
    "MASVS-AUTH-1",
    "MASVS-AUTH-2",
    "MASVS-AUTH-3",
    "MASVS-NETWORK-1",
    "MASVS-NETWORK-2",
    "MASVS-PLATFORM-1",
    "MASVS-PLATFORM-2",
    "MASVS-PLATFORM-3",
    "MASVS-CODE-1",
    "MASVS-CODE-2",
    "MASVS-CODE-3",
    "MASVS-CODE-4",
    "MASVS-RESILIENCE-1",
    "MASVS-RESILIENCE-2",
    "MASVS-RESILIENCE-3",
    "MASVS-RESILIENCE-4",
    "MASVS-PRIVACY-1",
    "MASVS-PRIVACY-2",
    "MASVS-PRIVACY-3",
    "MASVS-PRIVACY-4",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def valid_utc_timestamp(value: object) -> bool:
    if not isinstance(value, str) or not value.endswith("Z"):
        return False
    try:
        datetime.fromisoformat(value.removesuffix("Z") + "+00:00")
    except ValueError:
        return False
    return True


def validate_assessment(
    assessment_path: Path,
    aab_path: Path,
    expected_package: str,
    expected_version_name: str,
    expected_version_code: int,
) -> list[str]:
    errors: list[str] = []
    require(assessment_path.is_file(), "assessment file is missing", errors)
    require(aab_path.is_file(), "candidate AAB is missing", errors)
    if errors:
        return errors
    try:
        payload = json.loads(assessment_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"assessment cannot be parsed: {exc}"]
    if not isinstance(payload, dict):
        return ["assessment root must be an object"]

    require(payload.get("schemaVersion") == 1, "schemaVersion must be 1", errors)
    framework = payload.get("framework")
    require(isinstance(framework, dict), "framework object is required", errors)
    if isinstance(framework, dict):
        require(framework.get("name") == "OWASP MASVS", "framework name mismatch", errors)
        require(
            framework.get("sourceUrl") == "https://mas.owasp.org/MASVS/",
            "framework source URL mismatch",
            errors,
        )
        revision = framework.get("referenceRevision")
        require(
            isinstance(revision, str)
            and bool(revision.strip())
            and "REPLACE" not in revision.upper()
            and "PLACEHOLDER" not in revision.upper(),
            "framework referenceRevision is required",
            errors,
        )

    actual_aab_hash = sha256(aab_path)
    candidate = payload.get("candidate")
    require(isinstance(candidate, dict), "candidate object is required", errors)
    if isinstance(candidate, dict):
        require(candidate.get("packageName") == expected_package, "candidate package mismatch", errors)
        require(candidate.get("versionName") == expected_version_name, "candidate versionName mismatch", errors)
        require(candidate.get("versionCode") == expected_version_code, "candidate versionCode mismatch", errors)
        require(
            str(candidate.get("aabSha256", "")).lower() == actual_aab_hash,
            "candidate AAB SHA-256 mismatch",
            errors,
        )

    review = payload.get("review")
    require(isinstance(review, dict), "review object is required", errors)
    if isinstance(review, dict):
        reviewer = review.get("reviewedBy")
        require(
            isinstance(reviewer, str)
            and len(reviewer.strip()) >= 3
            and "REPLACE" not in reviewer.upper(),
            "accountable reviewedBy is required",
            errors,
        )
        require(valid_utc_timestamp(review.get("reviewedAt")), "reviewedAt must be an ISO-8601 UTC timestamp", errors)

    controls = payload.get("controls")
    require(isinstance(controls, list), "controls must be an array", errors)
    seen: set[str] = set()
    assessment_dir = assessment_path.resolve().parent
    if isinstance(controls, list):
        for raw_control in controls:
            if not isinstance(raw_control, dict):
                errors.append("every control must be an object")
                continue
            control_id = str(raw_control.get("id", ""))
            require(control_id in CONTROL_IDS, f"unknown control id: {control_id}", errors)
            require(control_id not in seen, f"duplicate control id: {control_id}", errors)
            seen.add(control_id)
            status = raw_control.get("status")
            require(
                status in {"PASS", "NOT_APPLICABLE"},
                f"{control_id} is not PASS or NOT_APPLICABLE",
                errors,
            )
            rationale = raw_control.get("rationale")
            require(
                isinstance(rationale, str) and len(rationale.strip()) >= 10,
                f"{control_id} has no concrete rationale",
                errors,
            )
            evidence = raw_control.get("evidence")
            require(
                isinstance(evidence, list) and bool(evidence),
                f"{control_id} has no evidence",
                errors,
            )
            if not isinstance(evidence, list):
                continue
            for item in evidence:
                if not isinstance(item, dict):
                    errors.append(f"{control_id} evidence must be an object")
                    continue
                rel_path = str(item.get("path", ""))
                item_hash = str(item.get("sha256", "")).lower()
                require(item.get("candidateBound") is True, f"{control_id}:{rel_path} is not candidate-bound", errors)
                require(bool(SHA256_RE.fullmatch(item_hash)), f"{control_id}:{rel_path} has invalid SHA-256", errors)
                evidence_path = (assessment_dir / rel_path).resolve()
                try:
                    evidence_path.relative_to(assessment_dir)
                except ValueError:
                    errors.append(f"{control_id}:{rel_path} escapes the assessment directory")
                    continue
                require(evidence_path.is_file(), f"{control_id}:{rel_path} is missing", errors)
                if evidence_path.is_file() and SHA256_RE.fullmatch(item_hash):
                    require(sha256(evidence_path) == item_hash, f"{control_id}:{rel_path} hash mismatch", errors)
    require(seen == CONTROL_IDS, f"control set mismatch: found {sorted(seen)}", errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--assessment", required=True, type=Path)
    parser.add_argument("--aab", required=True, type=Path)
    parser.add_argument("--expected-package", required=True)
    parser.add_argument("--expected-version-name", required=True)
    parser.add_argument("--expected-version-code", required=True, type=int)
    args = parser.parse_args()

    errors = validate_assessment(
        args.assessment,
        args.aab,
        args.expected_package,
        args.expected_version_name,
        args.expected_version_code,
    )
    if errors:
        print("MASVS_ASSESSMENT_FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("MASVS_ASSESSMENT_PASS")
    print(f"controls={len(CONTROL_IDS)}")
    print(f"candidate_aab_sha256={sha256(args.aab)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
