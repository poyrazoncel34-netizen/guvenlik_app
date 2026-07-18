#!/usr/bin/env python3
"""Classify every dirty path and reject local tooling/secrets in the index.

This is a source-scope verifier, not a release-readiness claim. It intentionally
accepts a dirty tree during hardening, but only when every changed path matches
one reviewed rule. Production provenance still requires a completely clean tree.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


def run_git(repo: Path, *arguments: str, check: bool = True) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(repo), *arguments],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and result.returncode != 0:
        message = result.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(message or f"git {' '.join(arguments)} failed")
    return result.stdout


def parse_porcelain_v1(raw: bytes) -> list[tuple[str, str]]:
    fields = raw.split(b"\0")
    entries: list[tuple[str, str]] = []
    index = 0
    while index < len(fields):
        field = fields[index]
        index += 1
        if not field:
            continue
        text = field.decode("utf-8", errors="surrogateescape")
        if len(text) < 4 or text[2] != " ":
            raise ValueError(f"unsupported porcelain record: {text!r}")
        status = text[:2]
        path = text[3:]
        if status[0] in {"R", "C"}:
            if index >= len(fields) or not fields[index]:
                raise ValueError(f"rename/copy source missing for {path!r}")
            index += 1
        entries.append((status, path))
    return entries


def load_config(path: Path) -> tuple[dict[str, Any], list[tuple[re.Pattern[str], dict[str, Any]]]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("schemaVersion") != 1:
        raise ValueError("classification config schemaVersion must be 1")
    allowed = set(payload.get("allowedCategories", []))
    if not allowed:
        raise ValueError("allowedCategories must not be empty")
    forbidden = set(payload.get("forbiddenStagedCategories", []))
    if not forbidden.issubset(allowed):
        raise ValueError("forbiddenStagedCategories contains an unknown category")

    compiled: list[tuple[re.Pattern[str], dict[str, Any]]] = []
    for rule in payload.get("rules", []):
        if rule.get("category") not in allowed:
            raise ValueError(f"rule has unknown category: {rule!r}")
        if not rule.get("commitGroup") or not rule.get("reason"):
            raise ValueError(f"rule is missing commitGroup/reason: {rule!r}")
        compiled.append((re.compile(str(rule["pattern"])), rule))
    if not compiled:
        raise ValueError("classification rules must not be empty")
    return payload, compiled


def git_head(repo: Path) -> str | None:
    value = run_git(repo, "rev-parse", "HEAD", check=False).decode().strip()
    return value if re.fullmatch(r"[0-9a-f]{40}", value) else None


def fail(messages: list[str]) -> int:
    print("RELEASE_CHANGE_CLASSIFICATION_FAIL", file=sys.stderr)
    for message in messages:
        print(f"- {message}", file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    try:
        config, rules = load_config(args.config.resolve())
        raw_status = run_git(
            args.repo.resolve(),
            "status",
            "--porcelain=v1",
            "-z",
            "--untracked-files=all",
        )
        dirty_entries = parse_porcelain_v1(raw_status)
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        return fail([str(exc)])

    forbidden = set(config["forbiddenStagedCategories"])
    unclassified: list[str] = []
    forbidden_staged: list[str] = []
    entries: list[dict[str, Any]] = []

    for status, path in dirty_entries:
        matches = [(pattern, rule) for pattern, rule in rules if pattern.search(path)]
        if not matches:
            unclassified.append(path)
            continue
        _, rule = matches[0]
        category = str(rule["category"])
        staged = status[0] not in {" ", "?", "!"}
        if staged and category in forbidden:
            forbidden_staged.append(path)
        entries.append(
            {
                "path": path,
                "status": status,
                "staged": staged,
                "category": category,
                "commitGroup": rule["commitGroup"],
                "reason": rule["reason"],
            }
        )

    payload = {
        "schemaVersion": 1,
        "gitHead": git_head(args.repo.resolve()),
        "statusSha256": hashlib.sha256(raw_status).hexdigest(),
        "entryCount": len(entries),
        "unclassifiedCount": len(unclassified),
        "forbiddenStagedCount": len(forbidden_staged),
        "entries": sorted(entries, key=lambda item: item["path"]),
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    errors = [f"UNCLASSIFIED_PATH {path}" for path in unclassified]
    errors.extend(f"FORBIDDEN_STAGED_PATH {path}" for path in forbidden_staged)
    if errors:
        return fail(errors)

    print("RELEASE_CHANGE_CLASSIFICATION_PASS")
    print(f"classified_paths={len(entries)}")
    print(f"status_sha256={payload['statusSha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
