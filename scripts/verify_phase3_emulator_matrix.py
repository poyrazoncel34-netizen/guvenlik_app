#!/usr/bin/env python3
"""Fail-closed verifier for the API 29/34/36 Direct Boot emulator matrix.

This verifier intentionally produces emulator-only evidence. It cannot close
physical-device, production-AAB, telephony, or OEM battery-policy gates.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any


HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_PROFILES = {
    (29, 4096): "api29-4kb",
    (34, 4096): "api34-4kb",
    (36, 4096): "api36-4kb",
    (36, 16384): "api36-16kb",
}
PROFILE_ORDER = tuple(REQUIRED_PROFILES.values())
COMMON_LIMITATIONS = {
    "NOT_PHYSICAL_DEVICE_EVIDENCE",
    "NOT_PRODUCTION_AAB_EVIDENCE",
    "NOT_TELEPHONY_CONNECTION_EVIDENCE",
    "NOT_OEM_BATTERY_POLICY_EVIDENCE",
}
REQUIRED_EXECUTION_TRUE = (
    "realReboot",
    "bootCompletedObserved",
    "typedSessionRestored",
    "packagesRemoved",
)


class EvidenceError(ValueError):
    pass


def exact_hash(name: str, pattern: re.Pattern[str]):
    def parse(value: str) -> str:
        normalized = value.strip().lower()
        if not pattern.fullmatch(normalized):
            raise argparse.ArgumentTypeError(f"{name} has an invalid format")
        return normalized

    return parse


def mapping(parent: dict[str, Any], key: str, label: str) -> dict[str, Any]:
    value = parent.get(key)
    if not isinstance(value, dict):
        raise EvidenceError(f"{label}.{key} must be an object")
    return value


def require_exact(parent: dict[str, Any], key: str, expected: Any, label: str) -> None:
    if parent.get(key) != expected or type(parent.get(key)) is not type(expected):
        raise EvidenceError(f"{label}.{key} must be {expected!r}")


def require_hash(parent: dict[str, Any], key: str, label: str) -> str:
    value = parent.get(key)
    if not isinstance(value, str) or not HEX_64.fullmatch(value):
        raise EvidenceError(f"{label}.{key} must be a lowercase SHA-256")
    return value


def parse_utc(value: Any, label: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise EvidenceError(f"{label} must be an ISO-8601 UTC timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise EvidenceError(f"{label} must be an ISO-8601 UTC timestamp") from exc
    if parsed.utcoffset() is None or parsed.utcoffset().total_seconds() != 0:
        raise EvidenceError(f"{label} must be UTC")
    return parsed


def read_payload(path: Path) -> tuple[dict[str, Any], str]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise EvidenceError(f"cannot read evidence {path.name}: {exc}") from exc
    try:
        payload = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise EvidenceError(f"evidence {path.name} is not valid UTF-8 JSON") from exc
    if not isinstance(payload, dict):
        raise EvidenceError(f"evidence {path.name} must contain a JSON object")
    return payload, hashlib.sha256(raw).hexdigest()


def validate_evidence(
    path: Path,
    payload: dict[str, Any],
    expected_commit: str,
    expected_tree: str,
) -> dict[str, Any]:
    label = path.name
    require_exact(payload, "schemaVersion", 1, label)
    require_exact(payload, "evidenceType", "android_direct_boot_reboot_probe", label)
    require_exact(payload, "status", "PASS_EMULATOR_ONLY", label)
    require_exact(payload, "candidateBound", False, label)

    source = mapping(payload, "source", label)
    require_exact(source, "clean", True, f"{label}.source")
    if source.get("gitCommit") != expected_commit:
        raise EvidenceError(f"{label}: git commit mismatch")
    if source.get("gitTree") != expected_tree:
        raise EvidenceError(f"{label}: git tree mismatch")

    build = mapping(payload, "build", label)
    require_exact(build, "variant", "playDebug", f"{label}.build")
    app_hash = require_hash(build, "appApkSha256", f"{label}.build")
    test_hash = require_hash(build, "testApkSha256", f"{label}.build")

    device = mapping(payload, "device", label)
    require_exact(device, "isEmulator", True, f"{label}.device")
    api_level = device.get("apiLevel")
    page_size = device.get("pageSizeBytes")
    if type(api_level) is not int or type(page_size) is not int:
        raise EvidenceError(f"{label}: apiLevel/pageSizeBytes must be integers")
    profile = REQUIRED_PROFILES.get((api_level, page_size))
    if profile is None:
        raise EvidenceError(
            f"{label}: unsupported emulator profile api={api_level} page={page_size}"
        )

    execution = mapping(payload, "execution", label)
    for key in REQUIRED_EXECUTION_TRUE:
        if execution.get(key) is not True:
            raise EvidenceError(f"{label}: {key} must be true")
    require_exact(
        execution,
        "armInstrumentationTestsPassed",
        1,
        f"{label}.execution",
    )
    require_exact(
        execution,
        "verifyInstrumentationTestsPassed",
        1,
        f"{label}.execution",
    )
    started_value = execution.get("startedAtUtc")
    finished_value = execution.get("finishedAtUtc")
    started = parse_utc(started_value, f"{label}.execution.startedAtUtc")
    finished = parse_utc(finished_value, f"{label}.execution.finishedAtUtc")
    if finished < started:
        raise EvidenceError(f"{label}: finishedAtUtc precedes startedAtUtc")

    limitations = payload.get("limitations")
    if not isinstance(limitations, list) or not all(
        isinstance(item, str) for item in limitations
    ):
        raise EvidenceError(f"{label}.limitations must be a string array")
    limitation_set = set(limitations)
    missing_common = sorted(COMMON_LIMITATIONS - limitation_set)
    if missing_common:
        raise EvidenceError(f"{label}: missing limitations {missing_common}")
    page_limitation = (
        "EMULATOR_16KB_KERNEL_ONLY"
        if page_size == 16384
        else "NOT_16KB_KERNEL_EVIDENCE"
    )
    if page_limitation not in limitation_set:
        raise EvidenceError(f"{label}: missing limitation {page_limitation}")

    return {
        "profile": profile,
        "appHash": app_hash,
        "testHash": test_hash,
        "startedAtUtc": started_value,
        "finishedAtUtc": finished_value,
    }


def atomic_write(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(serialized)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_name, 0o644)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def fail(message: str) -> int:
    print("PHASE3_EMULATOR_MATRIX_FAIL", file=sys.stderr)
    print(f"- {message}", file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--expected-git-commit",
        required=True,
        type=exact_hash("expected-git-commit", HEX_40),
    )
    parser.add_argument(
        "--expected-git-tree",
        required=True,
        type=exact_hash("expected-git-tree", HEX_40),
    )
    parser.add_argument("--evidence", required=True, action="append", type=Path)
    args = parser.parse_args()

    try:
        args.output.unlink(missing_ok=True)
    except OSError as exc:
        return fail(f"cannot invalidate stale output: {exc}")

    try:
        resolved_inputs = [item.resolve() for item in args.evidence]
        if len(resolved_inputs) != len(set(resolved_inputs)):
            raise EvidenceError("duplicate evidence paths are forbidden")
        if args.output.resolve() in resolved_inputs:
            raise EvidenceError("output path cannot also be an evidence input")

        validated: list[dict[str, Any]] = []
        digests: dict[str, str] = {}
        for path in resolved_inputs:
            payload, digest = read_payload(path)
            item = validate_evidence(
                path,
                payload,
                args.expected_git_commit,
                args.expected_git_tree,
            )
            profile = item["profile"]
            if profile in digests:
                raise EvidenceError(f"duplicate profile: {profile}")
            digests[profile] = digest
            validated.append(item)

        profiles = {item["profile"] for item in validated}
        missing = [item for item in PROFILE_ORDER if item not in profiles]
        extras = sorted(profiles - set(PROFILE_ORDER))
        if missing or extras or len(validated) != len(PROFILE_ORDER):
            raise EvidenceError(
                f"missing required profiles: {missing}; unexpected profiles: {extras}"
            )

        app_hashes = {item["appHash"] for item in validated}
        test_hashes = {item["testHash"] for item in validated}
        if len(app_hashes) != 1 or len(test_hashes) != 1:
            raise EvidenceError("APK hashes differ across emulator profiles")

        by_profile = {item["profile"]: item for item in validated}
        output_payload = {
            "schemaVersion": 1,
            "evidenceType": "android_direct_boot_emulator_matrix",
            "status": "PASS_EMULATOR_MATRIX_ONLY",
            "candidateBound": False,
            "source": {
                "gitCommit": args.expected_git_commit,
                "gitTree": args.expected_git_tree,
                "clean": True,
            },
            "build": {
                "variant": "playDebug",
                "appApkSha256": next(iter(app_hashes)),
                "testApkSha256": next(iter(test_hashes)),
            },
            "coverage": {
                "profiles": list(PROFILE_ORDER),
                "realRebootPerProfile": True,
                "bootCompletedObservedPerProfile": True,
                "typedSessionRestoredPerProfile": True,
                "api36Real16KbKernel": True,
            },
            "inputs": [
                {
                    "profile": profile,
                    "sha256": digests[profile],
                    "startedAtUtc": by_profile[profile]["startedAtUtc"],
                    "finishedAtUtc": by_profile[profile]["finishedAtUtc"],
                }
                for profile in PROFILE_ORDER
            ],
            "limitations": sorted(COMMON_LIMITATIONS),
        }
        atomic_write(args.output, output_payload)
    except (EvidenceError, OSError) as exc:
        return fail(str(exc))

    print("PHASE3_EMULATOR_MATRIX_PASS")
    print(f"profiles={','.join(PROFILE_ORDER)} candidateBound=false")
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
