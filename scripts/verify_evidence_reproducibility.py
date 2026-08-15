#!/usr/bin/env python3
"""Fails when a committed evidence artifact does not reproduce from the tree.

Why this exists (CERT-09)
-------------------------
`verify_evidence_provenance.py` proves each artifact NAMES a reconstructable
commit: `dirty: false`, a real revision, and a `treeHash` that matches
`git rev-parse <rev>^{tree}`. That is a claim about the STAMP. It says nothing
about the numbers underneath it.

The certification pass demonstrated the gap: hand-editing a measurement inside
`flows.json` while leaving the stamp untouched left `EVIDENCE_PROVENANCE_PASS`
green. The convergence guard caught it only because the edit was uncommitted and
the worktree-clean gate fired -- a COMMITTED edit would have satisfied all
sixteen gates. Eleven of the twelve artifacts had no content check at all; only
`text_scale.json` did, via the golden assertion inside
`test/screens/layout_size_matrix_test.dart`.

This closes that for the other eleven, using the same convention as the golden:
regenerate, compare, and treat a difference as a failure rather than as new
truth.

What is compared, and what is not
---------------------------------
Everything EXCEPT `codeRevision` and `measuredOn`. Those two legitimately differ
between two runs of the same tree -- which commit was checked out and what day
it was -- and they are exactly what `verify_evidence_provenance.py` already
checks. Every other key is a MEASUREMENT and must not move unless the measured
surface moved.

Why it restores rather than leaves the regeneration in place
------------------------------------------------------------
The emitters write in place, so running them dirties `docs/audit/evidence/`. A
verifier that leaves the tree dirty would break the very sequential chain
RER-02 established (clean -> tests -> clean -> secret scan). Each artifact is
snapshotted before the run and restored byte-for-byte afterwards, and the
restore is VERIFIED -- a failed restore is itself a failure, because a check
that can corrupt the thing it checks is worse than no check.

Usage:
    python3 scripts/verify_evidence_reproducibility.py
    python3 scripts/verify_evidence_reproducibility.py --negative-control

Exit code 0 == EVIDENCE_REPRODUCIBILITY_PASS.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
EVIDENCE_DIR = REPO / "docs" / "audit" / "evidence"

# verifier module -> the artifact it emits. Kept explicit rather than globbed:
# a verifier that silently stops emitting would otherwise just disappear from
# the check instead of failing it.
EMITTERS: dict[str, str] = {
    "a11y_platform": "a11y_platform.json",
    "assets": "assets.json",
    "color": "color.json",
    "copy": "copy.json",
    "flows": "flows.json",
    "interaction": "interaction.json",
    "layout": "layout.json",
    "motion": "motion.json",
    "storage": "storage.json",
    "tokens": "design_tokens.json",
    "typography": "typography.json",
}

# Provenance, not measurement. Two runs of one tree differ here by design.
PROVENANCE_KEYS = ("codeRevision", "measuredOn", "generatedAt")


def measurement_body(raw: str) -> str:
    data = json.loads(raw)
    for key in PROVENANCE_KEYS:
        data.pop(key, None)
    return json.dumps(data, sort_keys=True, ensure_ascii=False)


def drifted_keys(before: str, after: str) -> list[str]:
    a = json.loads(before)
    b = json.loads(after)
    for key in PROVENANCE_KEYS:
        a.pop(key, None)
        b.pop(key, None)
    keys = sorted(set(a) | set(b))
    return [
        k
        for k in keys
        if json.dumps(a.get(k), sort_keys=True) != json.dumps(b.get(k), sort_keys=True)
    ]


def worktree_is_clean_outside_evidence() -> tuple[bool, list[str]]:
    """The emitters refuse to run on a dirty tree (FIR-04), so say so once.

    Without this the caller gets eleven identical REFUSING_TO_EMIT walls of
    text and has to read one to find out the tree was dirty. The convergence
    guard runs this gate on a clean tree, which is the only place the answer
    means anything anyway.
    """
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        capture_output=True,
        text=True,
        cwd=REPO,
    )
    dirty = [
        line[3:]
        for line in result.stdout.splitlines()
        if line[3:] and not line[3:].startswith("docs/audit/evidence/")
    ]
    return (not dirty), dirty


def check(evidence_dir: Path) -> tuple[list[str], int]:
    problems: list[str] = []
    snapshots: dict[Path, str] = {}

    clean, dirty = worktree_is_clean_outside_evidence()
    if not clean:
        return (
            [
                "DIRTY_WORKTREE: the evidence emitters refuse to measure a tree "
                "that corresponds to no commit (FIR-04), so reproducibility "
                "cannot be assessed here. Commit or stash first. Dirty: "
                + ", ".join(dirty[:10])
            ],
            0,
        )

    for module, filename in sorted(EMITTERS.items()):
        artifact = evidence_dir / filename
        if not artifact.is_file():
            problems.append(f"MISSING_ARTIFACT {filename} (emitter {module})")
            continue
        snapshots[artifact] = artifact.read_text(encoding="utf-8")

    if problems:
        return problems, 0

    try:
        for module, filename in sorted(EMITTERS.items()):
            artifact = evidence_dir / filename
            result = subprocess.run(
                [sys.executable, str(REPO / "scripts" / "audit_evidence" / f"{module}.py")],
                capture_output=True,
                text=True,
                cwd=REPO,
            )
            if result.returncode != 0:
                problems.append(
                    f"EMITTER_FAILED {module}: exit {result.returncode}: "
                    f"{result.stdout.strip()} {result.stderr.strip()}"
                )
                continue
            regenerated = artifact.read_text(encoding="utf-8")
            drift = drifted_keys(snapshots[artifact], regenerated)
            if drift:
                problems.append(
                    f"MEASUREMENT_DRIFT {filename}: {', '.join(drift)}. The "
                    f"committed artifact does not reproduce from this tree, so "
                    f"either the surface changed without the artifact being "
                    f"regenerated, or the artifact was edited by hand."
                )
    finally:
        for artifact, original in snapshots.items():
            artifact.write_text(original, encoding="utf-8")

    for artifact, original in snapshots.items():
        if artifact.read_text(encoding="utf-8") != original:
            problems.append(
                f"RESTORE_FAILED {artifact.name}: this check must leave the "
                f"tree exactly as it found it"
            )

    return problems, len(snapshots)


def negative_control(evidence_dir: Path) -> int:
    """Edits one MEASUREMENT by hand and requires the drift to be caught.

    Deliberately not a stamp mutation: `verify_evidence_provenance.py` already
    covers those, and repeating them here would prove nothing new. The whole
    point of this verifier is the case that one passes.
    """
    baseline, _ = check(evidence_dir)
    if baseline:
        print("NEGATIVE_CONTROL_FAIL evidence_reproducibility: baseline is not clean")
        for problem in baseline:
            print(f"  - {problem}")
        return 1

    victim = evidence_dir / "flows.json"
    original = victim.read_text(encoding="utf-8")
    data = json.loads(original)
    exits = data["measurements"]["exitPaths"]
    before = exits["popSites"]
    exits["popSites"] = before + 999

    try:
        victim.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        problems, _ = check(evidence_dir)
        fired = [p for p in problems if p.startswith("MEASUREMENT_DRIFT flows.json")]
    finally:
        victim.write_text(original, encoding="utf-8")

    if victim.read_text(encoding="utf-8") != original:
        print("NEGATIVE_CONTROL_FAIL evidence_reproducibility: restore failed")
        return 1
    if not fired:
        print(
            "NEGATIVE_CONTROL_FAIL evidence_reproducibility: a hand-edited "
            f"measurement (popSites {before} -> {before + 999}) did not fire "
            "MEASUREMENT_DRIFT, so this verifier proves nothing"
        )
        return 1
    print(
        "NEGATIVE_CONTROL_PASS evidence_reproducibility: a hand-edited "
        f"measurement (flows.json popSites {before} -> {before + 999}) fired "
        "MEASUREMENT_DRIFT and the artifact was restored byte-identically. "
        "Note this is exactly the mutation EVIDENCE_PROVENANCE passes (CERT-09)."
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence-dir", default=str(EVIDENCE_DIR))
    parser.add_argument("--negative-control", action="store_true")
    args = parser.parse_args()

    evidence_dir = Path(args.evidence_dir)
    if args.negative_control:
        return negative_control(evidence_dir)

    problems, count = check(evidence_dir)
    if problems:
        print("EVIDENCE_REPRODUCIBILITY_FAIL")
        for problem in problems:
            print(f"- {problem}")
        return 1
    print(
        f"EVIDENCE_REPRODUCIBILITY_PASS {count} artifacts regenerated from the "
        f"tree with zero measurement drift; provenance keys "
        f"({', '.join(PROVENANCE_KEYS)}) excluded by design"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
