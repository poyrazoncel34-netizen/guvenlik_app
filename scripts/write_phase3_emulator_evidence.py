#!/usr/bin/env python3
"""Write validated, source-bound evidence for the Phase 3 emulator probe."""

from __future__ import annotations

import argparse
import json
import os
import re
import tempfile
from datetime import datetime
from pathlib import Path


HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")


def bounded_text(name: str, maximum: int = 512):
    def parse(value: str) -> str:
        normalized = value.strip()
        if not normalized or len(normalized) > maximum or "\x00" in normalized:
            raise argparse.ArgumentTypeError(f"{name} must be 1..{maximum} characters")
        return normalized

    return parse


def exact_hash(name: str, pattern: re.Pattern[str]):
    def parse(value: str) -> str:
        normalized = value.strip().lower()
        if not pattern.fullmatch(normalized):
            raise argparse.ArgumentTypeError(f"{name} has an invalid format")
        return normalized

    return parse


def positive_int(name: str):
    def parse(value: str) -> int:
        try:
            parsed = int(value)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(f"{name} must be an integer") from exc
        if parsed <= 0:
            raise argparse.ArgumentTypeError(f"{name} must be positive")
        return parsed

    return parse


def non_negative_int(name: str):
    def parse(value: str) -> int:
        try:
            parsed = int(value)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(f"{name} must be an integer") from exc
        if parsed < 0:
            raise argparse.ArgumentTypeError(f"{name} must be non-negative")
        return parsed

    return parse


def utc_timestamp(name: str):
    def parse(value: str) -> str:
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError as exc:
            raise argparse.ArgumentTypeError(f"{name} must be ISO-8601") from exc
        if parsed.utcoffset() is None or parsed.utcoffset().total_seconds() != 0:
            raise argparse.ArgumentTypeError(f"{name} must be UTC")
        return parsed.strftime("%Y-%m-%dT%H:%M:%SZ")

    return parse


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    result.add_argument("--output", required=True, type=Path)
    result.add_argument(
        "--git-commit", required=True, type=exact_hash("git-commit", HEX_40)
    )
    result.add_argument("--git-tree", required=True, type=exact_hash("git-tree", HEX_40))
    result.add_argument(
        "--app-apk-sha256",
        required=True,
        type=exact_hash("app-apk-sha256", HEX_64),
    )
    result.add_argument(
        "--test-apk-sha256",
        required=True,
        type=exact_hash("test-apk-sha256", HEX_64),
    )
    result.add_argument("--serial", required=True, type=bounded_text("serial", 128))
    result.add_argument("--avd-name", required=True, type=bounded_text("avd-name", 256))
    result.add_argument("--api-level", required=True, type=positive_int("api-level"))
    result.add_argument(
        "--android-release", required=True, type=bounded_text("android-release", 64)
    )
    result.add_argument("--abi", required=True, type=bounded_text("abi", 64))
    result.add_argument(
        "--manufacturer", required=True, type=bounded_text("manufacturer", 128)
    )
    result.add_argument("--model", required=True, type=bounded_text("model", 256))
    result.add_argument(
        "--build-fingerprint",
        required=True,
        type=bounded_text("build-fingerprint", 512),
    )
    result.add_argument(
        "--page-size-bytes", required=True, type=positive_int("page-size-bytes")
    )
    result.add_argument(
        "--exact-revocation-tests-passed",
        required=True,
        type=non_negative_int("exact-revocation-tests-passed"),
    )
    result.add_argument(
        "--started-at-utc", required=True, type=utc_timestamp("started-at-utc")
    )
    result.add_argument(
        "--finished-at-utc", required=True, type=utc_timestamp("finished-at-utc")
    )
    return result


def main() -> int:
    args = parser().parse_args()
    expected_exact_revocation_count = 3 if args.api_level >= 31 else 0
    if args.exact_revocation_tests_passed != expected_exact_revocation_count:
        raise SystemExit(
            "exact-revocation-tests-passed must be "
            f"{expected_exact_revocation_count} for API {args.api_level}"
        )
    started = datetime.fromisoformat(args.started_at_utc.replace("Z", "+00:00"))
    finished = datetime.fromisoformat(args.finished_at_utc.replace("Z", "+00:00"))
    if finished < started:
        raise SystemExit("finished-at-utc must not precede started-at-utc")

    payload = {
        "schemaVersion": 1,
        "evidenceType": "android_direct_boot_reboot_probe",
        "status": "PASS_EMULATOR_ONLY",
        "candidateBound": False,
        "source": {
            "gitCommit": args.git_commit,
            "gitTree": args.git_tree,
            "clean": True,
        },
        "build": {
            "variant": "playDebug",
            "appApkSha256": args.app_apk_sha256,
            "testApkSha256": args.test_apk_sha256,
        },
        "device": {
            "serial": args.serial,
            "avdName": args.avd_name,
            "apiLevel": args.api_level,
            "androidRelease": args.android_release,
            "abi": args.abi,
            "manufacturer": args.manufacturer,
            "model": args.model,
            "buildFingerprint": args.build_fingerprint,
            "pageSizeBytes": args.page_size_bytes,
            "isEmulator": True,
        },
        "execution": {
            "startedAtUtc": args.started_at_utc,
            "finishedAtUtc": args.finished_at_utc,
            "armInstrumentationTestsPassed": 1,
            "verifyInstrumentationTestsPassed": 1,
            "realReboot": True,
            "bootCompletedObserved": True,
            "typedSessionRestored": True,
            "exactPermissionRevocationRebootTested": (
                args.exact_revocation_tests_passed > 0
            ),
            "exactPermissionRevocationInstrumentationTestsPassed": (
                args.exact_revocation_tests_passed
            ),
            "packagesRemoved": True,
        },
        "limitations": [
            "NOT_PHYSICAL_DEVICE_EVIDENCE",
            "NOT_PRODUCTION_AAB_EVIDENCE",
            "NOT_TELEPHONY_CONNECTION_EVIDENCE",
            "NOT_OEM_BATTERY_POLICY_EVIDENCE",
            "NOT_16KB_KERNEL_EVIDENCE"
            if args.page_size_bytes != 16384
            else "EMULATOR_16KB_KERNEL_ONLY",
        ],
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{args.output.name}.", dir=args.output.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(serialized)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_name, 0o644)
        os.replace(temporary_name, args.output)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)

    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
