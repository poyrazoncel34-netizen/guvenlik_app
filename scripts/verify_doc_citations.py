#!/usr/bin/env python3
"""Fail-closed check that every SRC/TEST/CMD/DOC citation in the audit and
release documents names a file this repository actually contains.

Why this exists
---------------
The 2026-10-01 security audit found PRODUCTION_AUDIT.md claiming a security
control ("safe_device root detection") that had been removed from the runtime
path by A-017. Nothing caught it: the accounting gate proves every requirement
has a row, and the absence gate proves no row denies something present, but
neither asks whether a row's citation still points at a real file.

Scope and honesty
-----------------
This is the MECHANICAL half of citation integrity. It proves a cited path
resolves; it does NOT prove the cited file does what the sentence claims.
Semantic drift -- a test that exists and passes but asserts something else --
is not detectable here and stays a human review duty. Saying otherwise would
be the same class of overclaim the gate was written to catch.

Abbreviations are accepted on purpose: the documents write
`android/.../EmergencyPrefs.kt` and sometimes a bare basename after giving the
full path earlier in the sentence. Those resolve by basename against the tracked
file list. A citation that resolves NEITHER exactly NOR by basename is a finding.
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Longest-first so `.kts` wins over `.kt` and `.yaml` over `.yml`. Getting this
# order wrong invents findings: an early `kt` alternative truncates
# `build.gradle.kts` into a path that does not exist.
EXTENSIONS = sorted(
    [
        "dart", "kt", "kts", "java", "xml", "md", "py", "sh", "json",
        "yaml", "yml", "pro", "txt", "html",
    ],
    key=len,
    reverse=True,
)

CITATION = re.compile(
    r"\b(SRC|TEST|CMD|DOC)\s+([A-Za-z0-9_./\-]+\.(?:"
    + "|".join(EXTENSIONS)
    + r"))(?![A-Za-z0-9])"
)

ROOT_DOCS = (
    "PRODUCTION_AUDIT.md",
    "AUDIT_REPORT.md",
    "EXTERNAL_LAUNCH_BLOCKERS.md",
    "FINAL_REMEDIATION_REGISTER.md",
    "REMEDIATION_PLAN.md",
    "RESOLUTION_QUEUE.md",
    "SECURITY.md",
    "SPEC.md",
)


def tracked_files(repo: Path) -> list[str]:
    """Repository files: tracked, plus untracked files git does not ignore.

    Deliberately NOT "whatever exists on this disk". `.claude/` is git-ignored
    local agent tooling; citations into it resolved on a developer machine and
    failed on every clean checkout -- CI -- so the gate's verdict depended on
    who ran it.
    """
    out = subprocess.run(
        ["git", "-C", str(repo), "ls-files", "--cached", "--others",
         "--exclude-standard"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return [line for line in out.split("\n") if line]


def document_set(repo: Path) -> list[str]:
    docs = [name for name in ROOT_DOCS if (repo / name).is_file()]
    docs += sorted(
        str(path.relative_to(repo))
        for path in (repo / "docs").rglob("*.md")
        if path.is_file()
    )
    return docs


def scan(repo: Path) -> dict[str, object]:
    present = set(tracked_files(repo))
    by_basename: dict[str, set[str]] = collections.defaultdict(set)
    for path in present:
        by_basename[os.path.basename(path)].add(path)

    exact = 0
    abbreviated = 0
    unresolved: list[dict[str, str]] = []

    for document in document_set(repo):
        text = (repo / document).read_text(encoding="utf-8", errors="replace")
        for number, line in enumerate(text.split("\n"), 1):
            for kind, cited in CITATION.findall(line):
                if cited in present:
                    exact += 1
                elif by_basename.get(os.path.basename(cited)):
                    abbreviated += 1
                else:
                    unresolved.append(
                        {
                            "citation": cited,
                            "kind": kind,
                            "document": document,
                            "line": number,
                        }
                    )

    return {
        "schemaVersion": 1,
        "documentCount": len(document_set(repo)),
        "citationCount": exact + abbreviated + len(unresolved),
        "exactCount": exact,
        "abbreviatedCount": abbreviated,
        "unresolvedCount": len(unresolved),
        "unresolved": unresolved,
        "limitation": (
            "Mechanical only: proves a cited path resolves, not that the cited "
            "file supports the claim made about it."
        ),
        "status": "PASS" if not unresolved else "FAIL",
    }


def negative_control(repo: Path) -> int:
    """Proves the check can actually fail.

    A gate that has never been seen red is not evidence. This injects one
    impossible citation into a scratch copy of the document set and requires the
    scan to report it.
    """
    poison = "SRC lib/core/services/this_file_does_not_exist.dart"
    target = repo / "SECURITY.md"
    if not target.is_file():
        print("NEGATIVE_CONTROL_FAIL no document to poison", file=sys.stderr)
        return 1

    # Measured against THIS tree rather than a clone. A clone checks out the
    # default branch, so citations added on the current branch would read as
    # unresolved and the control would calibrate against the wrong baseline.
    baseline = scan(repo)["unresolvedCount"]
    original = target.read_text(encoding="utf-8")
    try:
        target.write_text(
            original + "\n" + poison + "\n", encoding="utf-8"
        )
        poisoned = scan(repo)["unresolvedCount"]
    finally:
        # Restored unconditionally: a control that can leave the document
        # modified is worse than no control.
        target.write_text(original, encoding="utf-8")

    if poisoned != baseline + 1:
        print(
            "NEGATIVE_CONTROL_FAIL poisoned citation was not detected "
            f"(baseline={baseline} poisoned={poisoned})",
            file=sys.stderr,
        )
        return 1
    if target.read_text(encoding="utf-8") != original:
        print("NEGATIVE_CONTROL_FAIL document not restored", file=sys.stderr)
        return 1
    print(f"NEGATIVE_CONTROL_PASS baseline={baseline} poisoned={poisoned}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".")
    parser.add_argument("--output")
    parser.add_argument("--negative-control", action="store_true")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    if args.negative_control:
        return negative_control(repo)

    report = scan(repo)
    if args.output:
        Path(args.output).write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

    if report["unresolvedCount"]:
        print("DOC_CITATION_FAIL")
        for item in report["unresolved"]:
            print(
                f"- UNRESOLVED {item['citation']} "
                f"<- {item['document']}:{item['line']} [{item['kind']}]"
            )
        return 1

    print("DOC_CITATION_PASS")
    print(
        f"documents={report['documentCount']} "
        f"citations={report['citationCount']} "
        f"exact={report['exactCount']} "
        f"abbreviated={report['abbreviatedCount']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
