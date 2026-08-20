#!/usr/bin/env python3
"""Fails when an unresolved audit row still carries repository work.

Why this exists
---------------
`verify_audit_accounting.py` proves every requirement HAS a row. It says nothing
about what that row asks for. The convergence claim this repository makes is a
different one:

    every remaining unresolved row is blocked on something outside the
    repository, or on an owner decision -- and on NOTHING ELSE.

Nothing read the scope column at all, so the totals in `RESOLUTION_QUEUE.md`
were trusted rather than checked, and the queue could drift away from the audit
that generates it without anything going red.

What this does NOT catch, stated plainly
----------------------------------------
`classify()` returns EXTERNAL_BLOCKER for any row whose status is BLOCKED,
before it ever reads the remediation. So the RER-01 defect -- `MP-41-017`, a
BLOCKED row whose remediation asked for a QA case to be AUTHORED in this
repository -- would still pass this verifier today. That class is caught
elsewhere, by the `STALE_REPO_REFERENCE` rule in `verify_absence_claims.py`,
which reads the remediation cell and fires when it demands work naming a file
the tree already has. The two checks are complementary and neither subsumes the
other; this one would be overclaiming if it said otherwise.

What it checks
--------------
1. IN_REPO_RESOLVABLE == 0 and RUNTIME_VERIFIABLE_NOW == 0.
2. No P0 or P1 row is classified as in-repo or runtime work.
3. `RESOLUTION_QUEUE.md` is byte-identical to what the generator produces from
   the CURRENT audit -- so the queue cannot drift into agreeing with a stale
   picture of the audit, which is how a hand-kept queue silently drops work.

The classification itself is deliberately NOT reimplemented here. It is imported
from `generate_resolution_queue.py`, because two copies of one rule is how the
audit and its summary tables came to disagree in the first place.

Usage:
    python3 scripts/verify_resolution_classification.py
    python3 scripts/verify_resolution_classification.py --negative-control

Exit code 0 == RESOLUTION_CLASSIFICATION_PASS.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "scripts"))

# Every manual scope override, pinned.
#
# An override is the one judgement in this system that no gate can contradict:
# classify() applies it BEFORE anything is counted, so this verifier's
# "inRepo=0 runtime=0" is computed from the override's own output. CERT2-01 was
# exactly that failure -- MP-72-013/014 sat as EXTERNAL on the argument that a
# second density bucket is hardware, which is backwards (the DEVICE has one
# bucket, the REPOSITORY has all five), and eighteen green gates could not say
# so.
#
# Pinning the set does NOT make any entry correct. It makes ADDING one a visible
# diff that a reviewer has to approve on purpose, instead of a line in a dict
# that silently moves a row out of the work queue. When this list and
# SCOPE_OVERRIDES disagree, the fix is to justify the new entry in review and
# then update this list -- never to sync it blindly.
PINNED_OVERRIDES = frozenset({
    "MP-02-016", "MP-03-013",
            "MP-32-040", "MP-41-004", "MP-41-006",
    "MP-41-009", "MP-41-010", "MP-41-011",     "MP-46-030", "MP-46-031",     "MP-54-023", "MP-54-024",     "MP-59-029", "MP-69-012",
    "MP-69-013", "MP-72-002", "MP-72-006", "MP-72-016",
    "MP-74-007", "MP-77-022",
    "MP-80-017",
})

from generate_resolution_queue import (  # noqa: E402
    SCOPE_OVERRIDES,
    STATUS_ORDER,
    classify,
    parse_rows,
)

# The two scopes that mean "this repository can still close it". Both must be
# empty for the convergence claim to hold.
IN_REPO_SCOPES = ("IN_REPO_RESOLVABLE", "RUNTIME_VERIFIABLE_NOW")
BLOCKING_SEVERITIES = ("P0", "P1")


def unresolved_rows(audit: Path) -> list:
    rows = [r for r in parse_rows(audit) if r["status"] in STATUS_ORDER]
    for row in rows:
        row["scope"], row["scopeReason"] = classify(row)
    return rows


def check(audit: Path, queue: Path) -> tuple:
    problems: list[str] = []
    rows = unresolved_rows(audit)
    if not rows:
        return ["NO_ROWS_PARSED: the audit produced no unresolved rows"], Counter()

    counts = Counter(row["scope"] for row in rows)

    # The override set is pinned, so a new hand-decided scope cannot enter
    # silently. See PINNED_OVERRIDES for why this is a review aid and not a
    # correctness check.
    actual_overrides = frozenset(SCOPE_OVERRIDES)
    for rid in sorted(actual_overrides - PINNED_OVERRIDES):
        problems.append(
            f"UNPINNED_SCOPE_OVERRIDE {rid}: a manual override was added that "
            f"no reviewer has signed off. An override is applied before this "
            f"gate counts anything, so it can move a row out of the work queue "
            f"without any gate disagreeing. Justify it in review, then add it "
            f"to PINNED_OVERRIDES."
        )
    for rid in sorted(PINNED_OVERRIDES - actual_overrides):
        problems.append(
            f"STALE_PINNED_OVERRIDE {rid}: pinned but no longer in "
            f"SCOPE_OVERRIDES. If the row was resolved, drop it from "
            f"PINNED_OVERRIDES in the same commit."
        )

    for scope in IN_REPO_SCOPES:
        for row in sorted(
            (r for r in rows if r["scope"] == scope), key=lambda r: r["id"]
        ):
            problems.append(
                f"IN_REPO_WORK_REMAINS {row['id']} [{row['severity']} "
                f"{row['status']}]: classified {scope} because "
                f"{row['scopeReason']}. Either do the work, or state the "
                f"external dependency the row is actually waiting on."
            )

    for row in rows:
        if row["severity"] in BLOCKING_SEVERITIES and row["scope"] in IN_REPO_SCOPES:
            problems.append(
                f"BLOCKING_SEVERITY_IN_REPO {row['id']}: {row['severity']} "
                f"classified {row['scope']}"
            )

    # The queue must be what the generator produces from THIS audit.
    with tempfile.TemporaryDirectory() as tmp:
        regenerated = Path(tmp) / "RESOLUTION_QUEUE.md"
        result = subprocess.run(
            [
                sys.executable,
                str(REPO / "scripts" / "generate_resolution_queue.py"),
                "--audit",
                str(audit),
                "--output",
                str(regenerated),
            ],
            capture_output=True,
            text=True,
            cwd=REPO,
        )
        if result.returncode != 0:
            problems.append(
                f"QUEUE_GENERATOR_FAILED: exit {result.returncode}: "
                f"{result.stdout.strip()} {result.stderr.strip()}"
            )
        elif not queue.exists():
            problems.append(f"QUEUE_MISSING: {queue} does not exist")
        elif regenerated.read_text(encoding="utf-8") != queue.read_text(
            encoding="utf-8"
        ):
            problems.append(
                f"QUEUE_STALE: {queue.name} differs from what the generator "
                f"produces from the current audit. Regenerate it with "
                f"`python3 scripts/generate_resolution_queue.py` -- a queue that "
                f"disagrees with the audit is how work gets silently dropped."
            )

    return problems, counts


def negative_control(audit: Path, queue: Path) -> int:
    """Injects a row whose gap names no external dependency at all.

    The generator's fallback classification is IN_REPO_RESOLVABLE, so a row with
    an ordinary "this is not implemented yet" gap must move the count off zero
    and fire IN_REPO_WORK_REMAINS. If it does not, this verifier is measuring
    nothing.
    """
    baseline, baseline_counts = check(audit, queue)
    lines = audit.read_text(encoding="utf-8").splitlines(keepends=True)

    injected = None
    out = []
    for line in lines:
        out.append(line)
        if injected is None and line.startswith("| `MP-01-"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) == 9:
                injected = "MP-99-999"
                out.append(
                    "| `MP-99-999` | Negative control row. | Applicable | "
                    "**PARTIAL** | P1 | none | The feature is not implemented "
                    "yet. | Implement it in lib/ and add a test. | `SRC` |\n"
                )
    if injected is None:
        print("NEGATIVE_CONTROL_FAIL resolution_classification: nothing to inject")
        return 1

    scratch = audit.parent / "PRODUCTION_AUDIT._classification_control.md"
    scratch.write_text("".join(out), encoding="utf-8")
    try:
        mutated, mutated_counts = check(scratch, queue)
    finally:
        scratch.unlink()

    fired = [p for p in mutated if p.startswith("IN_REPO_WORK_REMAINS MP-99-999")]
    severity_fired = [
        p for p in mutated if p.startswith("BLOCKING_SEVERITY_IN_REPO MP-99-999")
    ]
    if not fired or not severity_fired:
        print(
            "NEGATIVE_CONTROL_FAIL resolution_classification: an unblocked P1 row "
            f"did not fire both rules ({len(baseline)} -> {len(mutated)})"
        )
        return 1
    print(
        "NEGATIVE_CONTROL_PASS resolution_classification: an injected P1 row with "
        "no external dependency moved IN_REPO_RESOLVABLE "
        f"{baseline_counts['IN_REPO_RESOLVABLE']} -> "
        f"{mutated_counts['IN_REPO_RESOLVABLE']} and fired "
        "IN_REPO_WORK_REMAINS + BLOCKING_SEVERITY_IN_REPO"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", default=str(REPO / "PRODUCTION_AUDIT.md"))
    parser.add_argument("--queue", default=str(REPO / "RESOLUTION_QUEUE.md"))
    parser.add_argument("--negative-control", action="store_true")
    args = parser.parse_args()

    audit = Path(args.audit)
    queue = Path(args.queue)

    if args.negative_control:
        return negative_control(audit, queue)

    problems, counts = check(audit, queue)
    if problems:
        print("RESOLUTION_CLASSIFICATION_FAIL")
        for problem in problems:
            print(f"- {problem}")
        return 1
    print(
        "RESOLUTION_CLASSIFICATION_PASS "
        f"unresolved={sum(counts.values())} "
        f"inRepo={counts['IN_REPO_RESOLVABLE']} "
        f"runtime={counts['RUNTIME_VERIFIABLE_NOW']} "
        f"external={counts['EXTERNAL_BLOCKER']} "
        f"product={counts['PRODUCT_DECISION_REQUIRED']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
