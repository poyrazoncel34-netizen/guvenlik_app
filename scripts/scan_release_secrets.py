#!/usr/bin/env python3
"""Fail-closed deterministic scan for high-confidence credential signatures.

Findings never print the matched value. This scanner is a local release gate,
not a substitute for an independent scanner or repository-host secret scanning.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


RULES = (
    ("private-key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("aws-access-key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("google-api-key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("github-token", re.compile(r"\bgh[pousr]_[0-9A-Za-z]{36,}\b")),
    ("slack-token", re.compile(r"\bxox[baprs]-[0-9A-Za-z-]{20,}\b")),
    ("stripe-secret", re.compile(r"\bsk_(?:live|test)_[0-9A-Za-z]{16,}\b")),
    ("revenuecat-secret", re.compile(r"\bsk_[0-9A-Za-z]{20,}\b")),
    (
        "assigned-secret",
        re.compile(
            r"(?i)\b(?:password|passwd|secret|api[_-]?key|access[_-]?token|private[_-]?key)\b"
            r"\s*[:=]\s*[\"']([^\"'\s]{16,})[\"']"
        ),
    ),
)
SAFE_VALUE_MARKERS = (
    "${{",
    "$",
    "placeholder",
    "dummy",
    "example",
    "redacted",
    "changeme",
    "non_release",
)
EXCLUDED_TRACKED_PREFIXES = (".agents/", ".codex/")
EXCLUDED_TRACKED_NAMES = {"AGENTS.md"}
FORBIDDEN_TRACKED_SUFFIXES = (".jks", ".keystore")
FORBIDDEN_TRACKED_NAMES = {"key.properties", "google-services.json", "GoogleService-Info.plist"}


def fail(messages: list[str], output: Path | None = None) -> int:
    if output is not None:
        try:
            output.unlink(missing_ok=True)
        except OSError:
            pass
    print("RELEASE_SECRET_SCAN_FAIL", file=sys.stderr)
    for message in messages[:50]:
        print(f"- {message}", file=sys.stderr)
    if len(messages) > 50:
        print(f"- ... {len(messages) - 50} additional findings", file=sys.stderr)
    return 1


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def tracked_paths(repo: Path) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(repo), "ls-files", "-z"],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        raise ValueError("git ls-files failed")
    return sorted(
        item.decode("utf-8")
        for item in result.stdout.split(b"\0")
        if item
    )


def classified_paths(path: Path) -> tuple[list[str], str]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"classification cannot be read: {exc}") from exc
    if not isinstance(payload, dict) or payload.get("schemaVersion") != 1:
        raise ValueError("classification schema must be 1")
    entries = payload.get("entries")
    status_hash = payload.get("statusSha256")
    if not isinstance(entries, list) or not isinstance(status_hash, str):
        raise ValueError("classification entries/status hash are missing")
    paths: list[str] = []
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("malformed classification entry")
        if entry.get("commitGroup") == "EXCLUDE" or str(entry.get("status", "")).endswith("D"):
            continue
        candidate = entry.get("path")
        if not isinstance(candidate, str) or not candidate:
            raise ValueError("classification path is missing")
        paths.append(candidate)
    if len(paths) != len(set(paths)):
        raise ValueError("classification contains duplicate paths")
    return sorted(paths), status_hash


def is_safe_assigned_value(match: re.Match[str]) -> bool:
    if match.lastindex != 1:
        return False
    value = match.group(1).lower()
    return any(marker in value for marker in SAFE_VALUE_MARKERS)


def tracked_source(repo: Path) -> tuple[dict[str, object], list[str]]:
    commit = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    tree = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD^{tree}"],
        check=False,
        capture_output=True,
        text=True,
    )
    status = subprocess.run(
        [
            "git",
            "-C",
            str(repo),
            "status",
            "--porcelain=v1",
            "--untracked-files=all",
        ],
        check=False,
        capture_output=True,
    )
    if commit.returncode != 0 or tree.returncode != 0 or status.returncode != 0:
        raise ValueError("candidate Git identity cannot be resolved")
    commit_value = commit.stdout.strip()
    tree_value = tree.stdout.strip()
    if not re.fullmatch(r"[0-9a-f]{40}", commit_value) or not re.fullmatch(
        r"[0-9a-f]{40}", tree_value
    ):
        raise ValueError("candidate Git identity is malformed")
    return (
        {
            "gitCommit": commit_value,
            "gitTree": tree_value,
            "sourceWasDirty": bool(status.stdout),
            "sourceStatusSha256": sha256_bytes(status.stdout),
        },
        tracked_paths(repo),
    )


def atomic_write(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path("."))
    parser.add_argument("--classification", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--require-clean", action="store_true")
    args = parser.parse_args()
    repo = args.repo.resolve()
    output = args.output.resolve()
    try:
        output.unlink(missing_ok=True)
    except OSError as exc:
        return fail([f"stale output cannot be removed: {exc}"], output)

    try:
        if args.classification is None:
            mode = "tracked-candidate"
            source, paths = tracked_source(repo)
            if args.require_clean and source["sourceWasDirty"]:
                raise ValueError("candidate source is dirty")
        else:
            if args.require_clean:
                raise ValueError("require-clean is valid only for tracked candidates")
            mode = "classified-dirty-source"
            paths, source_status_hash = classified_paths(args.classification)
            source = {
                "gitCommit": None,
                "gitTree": None,
                "sourceWasDirty": True,
                "sourceStatusSha256": source_status_hash,
            }
    except ValueError as exc:
        return fail([str(exc)], output)

    findings: list[str] = []
    scanned: list[str] = []
    skipped_binary: list[str] = []
    content_digests: list[str] = []
    for relative in paths:
        if mode == "tracked-candidate" and (
            relative in EXCLUDED_TRACKED_NAMES or relative.startswith(EXCLUDED_TRACKED_PREFIXES)
        ):
            findings.append(f"forbidden tracked tooling path: {relative}")
            continue
        name = Path(relative).name
        if name in FORBIDDEN_TRACKED_NAMES or relative.lower().endswith(FORBIDDEN_TRACKED_SUFFIXES):
            findings.append(f"forbidden credential material path: {relative}")
            continue
        resolved = (repo / relative).resolve()
        try:
            resolved.relative_to(repo)
        except ValueError:
            findings.append(f"path escapes repository: {relative}")
            continue
        if not resolved.is_file():
            findings.append(f"classified source is missing: {relative}")
            continue
        try:
            raw = resolved.read_bytes()
        except OSError:
            findings.append(f"source cannot be read: {relative}")
            continue
        content_digests.append(f"{relative}\0{sha256_bytes(raw)}")
        if b"\0" in raw[:8192]:
            skipped_binary.append(relative)
            continue
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            skipped_binary.append(relative)
            continue
        scanned.append(relative)
        for line_number, line in enumerate(text.splitlines(), start=1):
            for rule_name, pattern in RULES:
                for match in pattern.finditer(line):
                    if rule_name == "assigned-secret" and is_safe_assigned_value(match):
                        continue
                    findings.append(f"{relative}:{line_number}: {rule_name}")

    if findings:
        return fail(findings, output)
    path_set_hash = sha256_bytes("\n".join(paths).encode("utf-8"))
    content_set_hash = sha256_bytes("\n".join(content_digests).encode("utf-8"))
    payload = {
        "schemaVersion": 2,
        "status": "PASS",
        "scannedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mode": mode,
        "source": source,
        "scanner": {
            "name": "scan_release_secrets.py",
            "sha256": sha256_bytes(Path(__file__).resolve().read_bytes()),
        },
        "pathSetSha256": path_set_hash,
        "contentSetSha256": content_set_hash,
        "inputPathCount": len(paths),
        "scannedTextFileCount": len(scanned),
        "skippedBinaryFileCount": len(skipped_binary),
        "rules": [name for name, _ in RULES],
        "findingCount": 0,
    }
    try:
        atomic_write(output, payload)
    except OSError as exc:
        return fail([f"report cannot be written: {exc}"], output)
    print("RELEASE_SECRET_SCAN_PASS")
    print(f"mode={mode} text={len(scanned)} binary={len(skipped_binary)} findings=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
