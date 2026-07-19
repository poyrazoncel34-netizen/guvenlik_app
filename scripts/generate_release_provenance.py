#!/usr/bin/env python3
"""Generate deterministic schema-v2 provenance for one Play candidate AAB."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


REQUIRED_ARTIFACTS = {
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
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
TAG = re.compile(r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
REPOSITORY = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalize_cert(value: str) -> str:
    return re.sub(r"[\s:]", "", value).lower()


def fail(message: str) -> int:
    print("RELEASE_PROVENANCE_V2_FAIL", file=sys.stderr)
    print(f"- {message}", file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--tag-object", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--tree", required=True)
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--version-code", required=True, type=int)
    parser.add_argument("--upload-cert", required=True)
    parser.add_argument("--play-app-signing-cert", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--workflow-run-url", required=True)
    parser.add_argument("--artifact", action="append", default=[])
    args = parser.parse_args()

    tag_match = TAG.fullmatch(args.tag)
    if not tag_match:
        return fail("tag must be strict vMAJOR.MINOR.PATCH")
    version_name = args.tag.removeprefix("v")
    if args.version_name != version_name:
        return fail("version name does not match signed tag")
    major, minor, patch = (int(value) for value in tag_match.groups())
    if minor > 99 or patch > 99:
        return fail("minor and patch must be <= 99")
    expected_version_code = major * 10_000 + minor * 100 + patch
    if args.version_code != expected_version_code or not 1 <= args.version_code <= 2_100_000_000:
        return fail("versionCode does not match the release formula")

    source_values = {
        "tag object": args.tag_object.lower(),
        "commit": args.commit.lower(),
        "tree": args.tree.lower(),
    }
    for label, value in source_values.items():
        if not HEX40.fullmatch(value):
            return fail(f"{label} must be 40 lowercase hex characters")

    upload_cert = normalize_cert(args.upload_cert)
    play_cert = normalize_cert(args.play_app_signing_cert)
    if not HEX64.fullmatch(upload_cert):
        return fail("upload certificate fingerprint must be SHA-256")
    if not HEX64.fullmatch(play_cert):
        return fail("Play app-signing certificate fingerprint must be SHA-256")
    if not REPOSITORY.fullmatch(args.repository):
        return fail("repository must be owner/name")
    expected_url_prefix = f"https://github.com/{args.repository}/actions/runs/"
    run_id = args.workflow_run_url.removeprefix(expected_url_prefix)
    if not args.workflow_run_url.startswith(expected_url_prefix) or not run_id.isdigit():
        return fail("workflow run URL does not match the repository")

    artifacts: dict[str, Path] = {}
    for specification in args.artifact:
        if "=" not in specification:
            return fail(f"invalid artifact specification: {specification}")
        name, raw_path = specification.split("=", 1)
        if name in artifacts:
            return fail(f"duplicate artifact: {name}")
        artifacts[name] = Path(raw_path)
    missing = REQUIRED_ARTIFACTS - artifacts.keys()
    extra = artifacts.keys() - REQUIRED_ARTIFACTS
    if missing:
        return fail(f"missing required artifacts: {sorted(missing)}")
    if extra:
        return fail(f"unknown artifacts: {sorted(extra)}")

    artifact_records: dict[str, dict[str, object]] = {}
    for name in sorted(artifacts):
        path = artifacts[name]
        if not path.is_file() or path.stat().st_size <= 0:
            return fail(f"artifact is missing or empty: {name}={path}")
        artifact_records[name] = {
            "path": path.as_posix(),
            "sha256": sha256(path),
            "sizeBytes": path.stat().st_size,
        }

    payload = {
        "schemaVersion": 2,
        "source": {
            "gitCommit": source_values["commit"],
            "gitTree": source_values["tree"],
            "signedTag": {
                "name": args.tag,
                "objectSha": source_values["tag object"],
            },
        },
        "candidate": {
            "versionName": args.version_name,
            "versionCode": args.version_code,
            "aabSha256": artifact_records["aab"]["sha256"],
        },
        "signing": {
            "uploadCertificateSha256": upload_cert,
            "playAppSigningCertificateSha256": play_cert,
        },
        "workflow": {
            "repository": args.repository,
            "runUrl": args.workflow_run_url,
        },
        "artifacts": artifact_records,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(args.output.suffix + ".tmp")
    temporary.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(args.output)
    print("RELEASE_PROVENANCE_V2_PASS")
    print(f"aab_sha256={payload['candidate']['aabSha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
