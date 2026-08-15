#!/usr/bin/env python3
"""Fails when an evidence artifact names no reconstructable commit.

Why this exists
---------------
Before FIR-04, eleven artifacts under `docs/audit/evidence/` were stamped with a
four-commit-old revision AND `dirty: true`. A dirty stamp corresponds to no
commit at all: nobody can check out "that tree", so nobody can reproduce the
measurement, and the artifact is decoration. The verifiers now refuse to emit
from a dirty tree -- but nothing checked the COMMITTED artifacts afterwards, so
a stale stamp could still sit in the repository indefinitely.

What it checks, per artifact
----------------------------
1. A `codeRevision` block exists.
2. `dirty` is exactly False -- not missing, not None, not "false".
3. `verifiedCodeRevision` is a real revision, not "unknown".
4. `treeHash` matches `git rev-parse <verifiedCodeRevision>^{tree}`. This is the
   check that cannot be faked by editing the JSON: the tree hash is git's, and a
   stamp naming a revision whose tree differs is either hand-edited or was
   produced against a tree that no longer exists.
5. Every artifact agrees on the SAME revision. Twelve artifacts measured at
   twelve different commits describe twelve different products.

Usage:
    python3 scripts/verify_evidence_provenance.py
    python3 scripts/verify_evidence_provenance.py --negative-control

Exit code 0 == EVIDENCE_PROVENANCE_PASS.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
EVIDENCE_DIR = REPO / "docs" / "audit" / "evidence"


def git_tree_of(revision: str) -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", f"{revision}^{{tree}}"],
        capture_output=True,
        text=True,
        cwd=REPO,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def check(evidence_dir: Path) -> list:
    problems: list[str] = []
    artifacts = sorted(evidence_dir.glob("*.json"))
    if not artifacts:
        return [f"NO_ARTIFACTS: {evidence_dir} contains no .json evidence"]

    revisions: dict[str, list] = {}
    for artifact in artifacts:
        name = artifact.name
        try:
            data = json.loads(artifact.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            problems.append(f"UNPARSEABLE {name}: {error}")
            continue

        revision = data.get("codeRevision")
        if not isinstance(revision, dict):
            problems.append(f"NO_CODE_REVISION {name}: no codeRevision block")
            continue

        if revision.get("dirty") is not False:
            problems.append(
                f"DIRTY_STAMP {name}: dirty={revision.get('dirty')!r}. A "
                f"measurement taken on a dirty tree corresponds to no commit, "
                f"so nobody can reproduce it."
            )

        verified = revision.get("verifiedCodeRevision")
        if not verified or verified == "unknown":
            problems.append(
                f"NO_REVISION {name}: verifiedCodeRevision={verified!r}"
            )
            continue

        tree = revision.get("treeHash")
        if not tree:
            problems.append(f"NO_TREE_HASH {name}: treeHash is absent")
            continue

        actual = git_tree_of(verified)
        if actual is None:
            problems.append(
                f"UNRESOLVABLE_REVISION {name}: {verified[:12]} is not a commit "
                f"in this repository, so the stamp names a tree nobody can "
                f"check out."
            )
        elif actual != tree:
            problems.append(
                f"TREE_HASH_MISMATCH {name}: stamped {tree[:12]}, but "
                f"{verified[:12]} has tree {actual[:12]}"
            )

        revisions.setdefault(verified, []).append(name)

    if len(revisions) > 1:
        summary = "; ".join(
            f"{rev[:8]} <- {', '.join(sorted(names))}"
            for rev, names in sorted(revisions.items())
        )
        problems.append(
            f"REVISION_DISAGREEMENT: artifacts name {len(revisions)} different "
            f"revisions ({summary}). One product, one measured tree."
        )

    return problems


def negative_control(evidence_dir: Path) -> int:
    """Rewrites one artifact's stamp three ways; each must be rejected."""
    baseline = check(evidence_dir)
    if baseline:
        print("NEGATIVE_CONTROL_FAIL evidence_provenance: baseline is not clean")
        for problem in baseline:
            print(f"  - {problem}")
        return 1

    victim = sorted(evidence_dir.glob("*.json"))[0]
    original = victim.read_text(encoding="utf-8")
    data = json.loads(original)

    mutations = {
        "DIRTY_STAMP": lambda block: block.update({"dirty": True}),
        "TREE_HASH_MISMATCH": lambda block: block.update(
            {"treeHash": "0" * 40}
        ),
        "UNRESOLVABLE_REVISION": lambda block: block.update(
            {"verifiedCodeRevision": "f" * 40}
        ),
    }

    failures = []
    try:
        for expected_rule, mutate in mutations.items():
            mutated = json.loads(original)
            mutate(mutated["codeRevision"])
            victim.write_text(
                json.dumps(mutated, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            problems = check(evidence_dir)
            fired = [p for p in problems if p.startswith(expected_rule)]
            if fired:
                print(f"  [PASS] {expected_rule}: {fired[0][:90]}")
            else:
                print(f"  [FAIL] {expected_rule}: did not fire")
                failures.append(expected_rule)
    finally:
        victim.write_text(original, encoding="utf-8")

    # The tree must be exactly as found, or this control has dirtied the repo.
    if victim.read_text(encoding="utf-8") != original:
        print("NEGATIVE_CONTROL_FAIL evidence_provenance: restore failed")
        return 1
    if failures:
        print(
            "NEGATIVE_CONTROL_FAIL evidence_provenance: "
            f"{len(failures)} of {len(mutations)} mutations were not caught"
        )
        return 1
    print(
        f"NEGATIVE_CONTROL_PASS evidence_provenance: {len(mutations)}/"
        f"{len(mutations)} stamp mutations rejected on {victim.name}, "
        "artifact restored byte-identically"
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

    problems = check(evidence_dir)
    if problems:
        print("EVIDENCE_PROVENANCE_FAIL")
        for problem in problems:
            print(f"- {problem}")
        return 1

    artifacts = sorted(evidence_dir.glob("*.json"))
    revision = json.loads(artifacts[0].read_text(encoding="utf-8"))[
        "codeRevision"
    ]["verifiedCodeRevision"]
    print(
        f"EVIDENCE_PROVENANCE_PASS artifacts={len(artifacts)} "
        f"revision={revision[:12]} dirty=false treeHashVerified=true"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
