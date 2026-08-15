#!/usr/bin/env python3
"""Fails when an audit row asserts the absence of something the repository has.

Why this exists
---------------
The accounting gate proves every requirement has a row. It never asked whether a
row's evidence is still TRUE. The final independent review found seven rows
graded FAIL on one pasted sentence -- "no ticketing system, ownership model,
severity scale or response-time commitment exists in the repository" -- against a
repository whose own `docs/release/incident_runbook.md` contains a severity
ladder with per-level response targets, and whose `dr_and_key_custody.md`
contains the three DR runbooks another FAIL row's remediation asked for. Two more
rows (MP-47-017, MP-69-010) claimed no hardware-keyboard pass had been performed
while the device record of one was already cited as PASS by four other rows.

Hand-written prose outlives the tree it describes. This is the check that makes
that expensive.

What it does NOT do
-------------------
It does not parse natural language. Deciding whether an arbitrary English
sentence is still true is not a thing a verifier can do honestly, and a parser
that pretended to would be worse than nothing: it would launder the same class of
unchecked claim behind a green check.

Instead it works from a REGISTRY. Every non-PASS row whose evidence contains an
absence phrase must appear in `config/absence_claims.json` with:

  claim      - the exact phrase, quoted from the row. If the row's evidence
               changes so the phrase is gone, the entry is stale and this fails.
  refutedBy  - repository paths (optionally `path#heading`) whose EXISTENCE would
               make the claim false. Empty means the claim is about something
               outside the repository (a device pass, a Play account, a human
               decision), and that must be said in `why`.
  why        - why the claim is still true, in one sentence a reader can check.

The check then fails if any `refutedBy` target exists. A row that says a document
is absent, in a tree that contains it, is a defect -- whatever else is true.

Usage:
    python3 scripts/verify_absence_claims.py
    python3 scripts/verify_absence_claims.py --negative-control

Exit code 0 == ABSENCE_CLAIMS_PASS.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

ROW = re.compile(r"^\|\s*`(MP-\d+-\d+)`\s*\|(.*)$")

# Phrases that assert something does not exist. Deliberately narrow: each one is
# a claim a reader would check against the tree.
ABSENCE_PHRASES = [
    # "no longer" / "no worse" are comparisons, not absence claims.
    r"\bno (?!longer\b|worse\b|obvious\b)[a-z]",
    r"\bdoes not exist",
    r"\bis absent",
    r"\bnot defined",
    r"\bnone exists",
    r"\bnothing exists",
    r"\bmissing\b",
    r"\bnever written",
]

RESOLVED = {"PASS", "N/A"}


def audit_rows(audit: Path) -> dict:
    rows = {}
    for line in audit.read_text(encoding="utf-8").splitlines():
        match = ROW.match(line)
        if not match:
            continue
        cells = [cell.strip() for cell in match.group(2).split("|")]
        if len(cells) < 6:
            continue
        rows[match.group(1)] = {
            "requirement": cells[0],
            "status": cells[2].replace("*", "").strip(),
            "evidence": cells[4],
        }
    return rows


def claims_needing_registration(rows: dict) -> list:
    out = []
    for rid, row in sorted(rows.items()):
        if row["status"] in RESOLVED:
            continue
        if any(re.search(p, row["evidence"], re.I) for p in ABSENCE_PHRASES):
            out.append(rid)
    return out


def target_exists(repo: Path, target: str) -> bool:
    """Whether a refuting target is present.

    Two forms, both decidable without reading English:

      ``path`` / ``path#heading`` -- the file exists (and carries the heading).
      ``grep:<dir>:<regex>``      -- some file under <dir> matches the regex.

    The grep form exists because several claims are about a RECORD rather than a
    fixed filename ("no TalkBack pass is recorded under docs/qa/"). Naming one
    speculative filename would make the check trivially evadable; searching the
    directory the row itself names does not.
    """
    if target.startswith("grep:"):
        _, directory, pattern = target.split(":", 2)
        base = repo / directory
        if not base.exists():
            return False
        rx = re.compile(pattern, re.I)
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
            if rx.search(text):
                return True
        return False
    path_part, _, heading = target.partition("#")
    path = repo / path_part
    if not path.exists():
        return False
    if not heading:
        return True
    return heading in path.read_text(encoding="utf-8")


def check(repo: Path, audit: Path, registry_path: Path) -> list:
    problems = []
    rows = audit_rows(audit)
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    entries = registry["claims"]

    needed = claims_needing_registration(rows)
    for rid in needed:
        if rid not in entries:
            problems.append(
                f"UNREGISTERED_ABSENCE_CLAIM {rid}: its evidence asserts an "
                f"absence but no entry names what would refute it. Add one to "
                f"{registry_path.name}."
            )

    for rid, entry in sorted(entries.items()):
        row = rows.get(rid)
        if row is None:
            problems.append(f"UNKNOWN_ROW {rid}: registered but not in the audit.")
            continue
        if entry["claim"] not in row["evidence"]:
            problems.append(
                f"STALE_REGISTRY_ENTRY {rid}: the registered phrase "
                f"{entry['claim']!r} no longer appears in the row's evidence, so "
                f"nothing here is checking the claim the row now makes."
            )
        for target in entry.get("refutedBy", []):
            if target_exists(repo, target):
                problems.append(
                    f"REFUTED_ABSENCE_CLAIM {rid}: the row asserts "
                    f"{entry['claim']!r}, but {target} EXISTS. Re-grade the row "
                    f"against the tree instead of restating the claim."
                )
        if not entry.get("refutedBy") and not entry.get("why"):
            problems.append(
                f"UNJUSTIFIED_CLAIM {rid}: no refuting path and no reason given."
            )
    return problems


def negative_control(repo: Path, audit: Path, registry_path: Path) -> int:
    """Registers a claim refuted by a file that certainly exists."""
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    rows = audit_rows(audit)
    victim = next(iter(sorted(claims_needing_registration(rows))), None)
    if victim is None:
        print("NEGATIVE_CONTROL_FAIL absence_claims: no absence claim to mutate")
        return 1
    baseline = check(repo, audit, registry_path)
    registry["claims"][victim] = {
        "claim": rows[victim]["evidence"][:40],
        "refutedBy": ["PRODUCTION_AUDIT.md"],
        "why": "negative control",
    }
    scratch = registry_path.parent / "_absence_claims_control.json"
    scratch.write_text(json.dumps(registry, indent=2), encoding="utf-8")
    try:
        mutated = check(repo, audit, scratch)
    finally:
        scratch.unlink()
    fired = [p for p in mutated if p.startswith("REFUTED_ABSENCE_CLAIM")]
    if not fired or len(mutated) <= len(baseline):
        print(
            "NEGATIVE_CONTROL_FAIL absence_claims: a claim refuted by an "
            "existing file did not fire (%d -> %d)" % (len(baseline), len(mutated))
        )
        return 1
    print(
        "NEGATIVE_CONTROL_PASS absence_claims: a claim refuted by an existing "
        "file moved problems %d -> %d; rule fired: REFUTED_ABSENCE_CLAIM"
        % (len(baseline), len(mutated))
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=str(REPO))
    parser.add_argument("--audit", default=None)
    parser.add_argument("--registry", default=None)
    parser.add_argument("--negative-control", action="store_true")
    args = parser.parse_args()

    repo = Path(args.repo)
    audit = Path(args.audit) if args.audit else repo / "PRODUCTION_AUDIT.md"
    registry = (
        Path(args.registry) if args.registry else repo / "config" / "absence_claims.json"
    )

    if args.negative_control:
        return negative_control(repo, audit, registry)

    problems = check(repo, audit, registry)
    if problems:
        print("ABSENCE_CLAIMS_FAIL")
        for problem in problems:
            print(f"- {problem}")
        return 1
    registered = len(json.loads(registry.read_text(encoding="utf-8"))["claims"])
    print(f"ABSENCE_CLAIMS_PASS registered={registered}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
