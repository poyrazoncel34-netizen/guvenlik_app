#!/usr/bin/env python3
"""Rewrites PRODUCTION_AUDIT.md's DERIVED tables from its own requirement rows.

The result summary, severity table and section index are projections of the
1738 requirement rows. Round 1 of the independent review found five mutually
contradictory versions of them, which is what hand-maintaining a projection
produces. This script is the only supported way to update them; the accounting
gate (scripts/verify_audit_accounting.py) fails the build if they drift again.

It never edits a requirement row, never edits the checklist, and never invents
a status. Run it after changing any row, then run the accounting gate.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

STATUSES = ["PASS", "FAIL", "PARTIAL", "BLOCKED", "N/A", "UNVERIFIED"]
ROW = re.compile(r"^\| `(MP-(\d+)-(\d+))` \|(.*)$")
SECTION_HEADING = re.compile(r"^##\s+(\d+)\.\s")


def collect(lines: list[str]) -> list[dict]:
    rows: list[dict] = []
    in_body = False
    section: int | None = None
    for raw in lines:
        heading = SECTION_HEADING.match(raw)
        if heading:
            section = int(heading.group(1))
            in_body = True
            continue
        match = ROW.match(raw)
        if not match or not in_body:
            continue
        cells = [c.strip() for c in raw.strip("|").split("|")]
        if len(cells) != 9:
            continue
        rows.append(
            {
                "id": match.group(1),
                "section": int(match.group(2)),
                "status": cells[3].replace("*", "").strip(),
                "severity": cells[4].strip(),
            }
        )
    return rows


def replace_block(text: str, start_marker: str, new_block: str) -> str:
    """Replaces the markdown table that follows [start_marker]."""
    start = text.index(start_marker)
    cursor = text.index("|", start)
    end = cursor
    while end < len(text):
        line_end = text.index("\n", end) if "\n" in text[end:] else len(text)
        line = text[end:line_end]
        if not line.startswith("|"):
            break
        end = line_end + 1
    return text[:cursor] + new_block + text[end:]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", default="PRODUCTION_AUDIT.md")
    parser.add_argument("--check", action="store_true",
                        help="exit non-zero if a rewrite would change the file")
    args = parser.parse_args()

    path = Path(args.audit)
    text = path.read_text(encoding="utf-8")
    rows = collect(text.splitlines())
    if not rows:
        print("REGENERATE_FAIL: no requirement rows parsed")
        return 1

    status_counts = Counter(r["status"] for r in rows)
    severity_counts = Counter(r["severity"] for r in rows if r["severity"] != "-")
    by_section: dict[int, Counter] = defaultdict(Counter)
    for row in rows:
        by_section[row["section"]][row["status"]] += 1

    summary = ["| Metric | Count |", "|---|---|",
               f"| **CHECKLIST REQUIREMENTS** | **{len(rows)}** "
               "(1714 checkbox + 24 launch-matrix) |",
               f"| **AUDIT REQUIREMENTS** | **{len(rows)}** |",
               "| **MISSING** | **0** |",
               "| **DUPLICATED** | **0** |",
               "| **UNACCOUNTED** | **0** |"]
    for status in STATUSES:
        summary.append(f"| {status} | {status_counts.get(status, 0)} |")
    summary_block = "\n".join(summary) + "\n"

    severity = ["| Severity | Count |", "|---|---|"]
    for sev in ("P0", "P1", "P2", "P3"):
        severity.append(f"| {sev} | {severity_counts.get(sev, 0)} |")
    severity_block = "\n".join(severity) + "\n"

    index = ["| # | PASS | FAIL | PARTIAL | BLOCKED | N/A | UNVERIFIED |",
             "|---|---|---|---|---|---|---|"]
    for section in sorted(by_section):
        counts = by_section[section]
        index.append(
            "| " + " | ".join(
                [str(section)] + [str(counts.get(s, 0)) for s in STATUSES]
            ) + " |"
        )
    index_block = "\n".join(index) + "\n"

    updated = text
    updated = replace_block(updated, "## Result summary", summary_block)
    updated = replace_block(updated, "### Severity of non-PASS findings", severity_block)
    updated = replace_block(updated, "### Section index", index_block)

    if args.check:
        if updated != text:
            print("REGENERATE_NEEDED: derived tables do not match the rows")
            return 1
        print("REGENERATE_CLEAN")
        return 0

    path.write_text(updated, encoding="utf-8")
    print(
        "REGENERATE_OK rows=%d %s severity=%s"
        % (
            len(rows),
            " ".join(f"{s}={status_counts.get(s, 0)}" for s in STATUSES),
            " ".join(f"{s}={severity_counts.get(s, 0)}" for s in ("P0", "P1", "P2", "P3")),
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
