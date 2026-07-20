#!/usr/bin/env python3
"""Validate OSV batch responses and emit candidate-bound JSON evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


OSV_ENDPOINT = "https://api.osv.dev/v1/querybatch"
SCANNED_AT = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def git(repo: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *arguments],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid JSON: {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def inspect_ecosystem(
    ecosystem: str,
    query_path: Path,
    response_path: Path,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    query_root = load_json(query_path)
    response_root = load_json(response_path)
    queries = query_root.get("queries")
    results = response_root.get("results")
    if not isinstance(queries, list):
        raise ValueError(f"{ecosystem} queries must be an array")
    if not isinstance(results, list):
        raise ValueError(f"{ecosystem} results must be an array")
    if len(results) != len(queries):
        raise ValueError(
            f"OSV response count mismatch for {ecosystem}: "
            f"queries={len(queries)} results={len(results)}"
        )

    coordinates: list[str] = []
    findings: list[dict[str, Any]] = []
    for index, (query, result) in enumerate(zip(queries, results, strict=True)):
        if not isinstance(query, dict) or not isinstance(result, dict):
            raise ValueError(f"invalid {ecosystem} entry at index {index}")
        package = query.get("package")
        version = query.get("version")
        if not isinstance(package, dict):
            raise ValueError(f"missing package at {ecosystem} index {index}")
        name = package.get("name")
        actual_ecosystem = package.get("ecosystem")
        if actual_ecosystem != ecosystem:
            raise ValueError(
                f"ecosystem mismatch at {ecosystem} index {index}: "
                f"{actual_ecosystem!r}"
            )
        if not isinstance(name, str) or not name or len(name) > 512:
            raise ValueError(f"invalid package name at {ecosystem} index {index}")
        if not isinstance(version, str) or not version or len(version) > 256:
            raise ValueError(f"invalid version at {ecosystem} index {index}")
        coordinate = f"{ecosystem}:{name}@{version}"
        coordinates.append(coordinate)

        vulnerabilities = result.get("vulns", [])
        if not isinstance(vulnerabilities, list):
            raise ValueError(f"invalid vulns at {ecosystem} index {index}")
        ids: set[str] = set()
        for vulnerability in vulnerabilities:
            if not isinstance(vulnerability, dict):
                raise ValueError(f"invalid vulnerability at {ecosystem} index {index}")
            identifier = vulnerability.get("id")
            if not isinstance(identifier, str) or not identifier or len(identifier) > 128:
                raise ValueError(
                    f"invalid vulnerability id at {ecosystem} index {index}"
                )
            ids.add(identifier)
        if ids:
            findings.append({"coordinate": coordinate, "ids": sorted(ids)})

    if len(set(coordinates)) != len(coordinates):
        raise ValueError(f"duplicate exact package query in {ecosystem}")

    summary = {
        "queryCount": len(queries),
        "querySha256": sha256(query_path),
        "responseSha256": sha256(response_path),
        "findingCount": len(findings),
    }
    return summary, findings


def atomic_write(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--pub-query", type=Path, required=True)
    parser.add_argument("--pub-response", type=Path, required=True)
    parser.add_argument("--maven-query", type=Path, required=True)
    parser.add_argument("--maven-response", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--require-clean", action="store_true")
    parser.add_argument("--scanned-at")
    args = parser.parse_args()

    repo = args.repo.resolve()
    output = args.output.resolve()
    try:
        scanned_at = args.scanned_at or datetime.now(timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
        if not SCANNED_AT.fullmatch(scanned_at):
            raise ValueError("scanned-at must be UTC YYYY-MM-DDTHH:MM:SSZ")

        commit = git(repo, "rev-parse", "HEAD")
        tree = git(repo, "rev-parse", "HEAD^{tree}")
        status_bytes = subprocess.run(
            [
                "git",
                "-C",
                str(repo),
                "status",
                "--porcelain=v1",
                "--untracked-files=all",
            ],
            check=True,
            capture_output=True,
        ).stdout
        source_was_dirty = bool(status_bytes)
        if args.require_clean and source_was_dirty:
            raise ValueError("candidate source is dirty")

        pub_summary, pub_findings = inspect_ecosystem(
            "Pub", args.pub_query, args.pub_response
        )
        maven_summary, maven_findings = inspect_ecosystem(
            "Maven", args.maven_query, args.maven_response
        )
        findings = sorted(
            [*pub_findings, *maven_findings], key=lambda item: item["coordinate"]
        )

        pub_lock = repo / "pubspec.lock"
        gradle_lock = repo / "android/app/gradle.lockfile"
        runner = repo / "scripts/audit_dependencies_osv.sh"
        generator = repo / "scripts/generate_osv_evidence.py"
        for required in (pub_lock, gradle_lock, runner, generator):
            if not required.is_file() or required.stat().st_size == 0:
                raise ValueError(f"missing required input: {required}")

        payload: dict[str, Any] = {
            "schemaVersion": 1,
            "status": "FAIL" if findings else "PASS",
            "scannedAt": scanned_at,
            "endpoint": OSV_ENDPOINT,
            "interpretation": "noKnownFindingsAtScanTime" if not findings else "knownFindings",
            "source": {
                "gitCommit": commit,
                "gitTree": tree,
                "sourceWasDirty": source_was_dirty,
                "sourceStatusSha256": sha256_bytes(status_bytes),
            },
            "inputs": {
                "pubspecLockSha256": sha256(pub_lock),
                "gradleLockSha256": sha256(gradle_lock),
                "runnerSha256": sha256(runner),
                "generatorSha256": sha256(generator),
            },
            "ecosystems": {"Pub": pub_summary, "Maven": maven_summary},
            "findingCount": len(findings),
            "findings": findings,
            "coverageLimit": (
                "OSV data sources and package mapping are incomplete; PASS means only "
                "that these exact queries had no known OSV finding at scan time."
            ),
        }
        atomic_write(output, payload)
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        try:
            output.unlink(missing_ok=True)
        except OSError:
            pass
        print("OSV_EVIDENCE_FAIL", file=sys.stderr)
        print(f"- {error}", file=sys.stderr)
        return 2

    if findings:
        print("OSV_EVIDENCE_BLOCKED", file=sys.stderr)
        for finding in findings:
            print(
                f"- {finding['coordinate']}: {','.join(finding['ids'])}",
                file=sys.stderr,
            )
        return 1
    print("OSV_EVIDENCE_PASS")
    print(f"pub_queries={pub_summary['queryCount']}")
    print(f"maven_queries={maven_summary['queryCount']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
