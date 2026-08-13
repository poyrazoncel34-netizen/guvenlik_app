#!/usr/bin/env python3
"""Edits ONE requirement row in PRODUCTION_AUDIT.md, by ID, safely.

Hand-editing a 3000-line markdown table is how rows lose columns, how a status
gets changed without regenerating the summaries, and how the P0/P1 register goes
stale. This tool refuses to touch a row it cannot uniquely identify as a 9-column
requirement row (the P0/P1 register re-lists P1 IDs with 6 columns, and editing
that by accident is a real hazard).

It does NOT regenerate the derived tables — run these afterwards, in order:

    python3 scripts/regenerate_audit_summaries.py
    python3 scripts/verify_audit_accounting.py
    python3 scripts/generate_resolution_queue.py

Example:
    python3 scripts/set_audit_row.py MP-12-017 --status PASS --severity - \
        --verification TEST --evidence "..." --gap "..." --remediation "..."
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

VALID_STATUSES = {"PASS", "FAIL", "PARTIAL", "BLOCKED", "N/A", "UNVERIFIED"}
VALID_METHODS = {"SRC", "RUN", "TEST", "DOC", "NONE", "CMD"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("requirement_id")
    parser.add_argument("--audit", default="PRODUCTION_AUDIT.md")
    parser.add_argument("--status")
    parser.add_argument("--severity")
    parser.add_argument("--evidence")
    parser.add_argument("--gap")
    parser.add_argument("--remediation")
    parser.add_argument("--verification")
    args = parser.parse_args()

    if args.status and args.status not in VALID_STATUSES:
        print(f"SET_ROW_FAIL: invalid status {args.status!r}")
        return 1
    if args.verification and args.verification not in VALID_METHODS:
        print(f"SET_ROW_FAIL: invalid verification {args.verification!r}")
        return 1
    for field in (args.evidence, args.gap, args.remediation):
        if field and "|" in field:
            print("SET_ROW_FAIL: a cell may not contain '|' — it would split the row")
            return 1

    path = Path(args.audit)
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"^\| `" + re.escape(args.requirement_id) + r"` \|.*$", re.M
    )

    matches = []
    for match in pattern.finditer(text):
        cells = [c.strip() for c in match.group(0).strip("|").split("|")]
        if len(cells) == 9:
            matches.append((match, cells))

    if not matches:
        print(f"SET_ROW_FAIL: no 9-column requirement row for {args.requirement_id}")
        return 1
    if len(matches) > 1:
        print(f"SET_ROW_FAIL: {args.requirement_id} matches {len(matches)} rows")
        return 1

    match, cells = matches[0]
    before = list(cells)
    if args.status:
        cells[3] = f"**{args.status}**"
    if args.severity:
        cells[4] = args.severity
    if args.evidence:
        cells[5] = args.evidence
    if args.gap:
        cells[6] = args.gap
    if args.remediation:
        cells[7] = args.remediation
    if args.verification:
        cells[8] = f"`{args.verification}`"

    if cells == before:
        print(f"SET_ROW_NOOP {args.requirement_id}")
        return 0

    updated = text[: match.start()] + "| " + " | ".join(cells) + " |" + text[match.end():]
    path.write_text(updated, encoding="utf-8")
    print(
        f"SET_ROW_OK {args.requirement_id} "
        f"{before[3]} -> {cells[3]}, sev {before[4]} -> {cells[4]}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
