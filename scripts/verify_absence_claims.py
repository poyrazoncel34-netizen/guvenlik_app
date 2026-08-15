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

  field      - which canonical cell the claim lives in: "evidence" (default),
               "gap" or "remediation". A claim is checked against THAT cell, so
               an entry cannot drift onto a different sentence and keep passing.
  claim      - the exact phrase, quoted from the row. If the cell changes so the
               phrase is gone, the entry is stale and this fails.
  refutedBy  - repository paths (optionally `path#heading`) whose EXISTENCE would
               make the claim false. Empty means the claim is about something
               outside the repository (a device pass, a Play account, a human
               decision), and that must be said in `why`.
  why        - why the claim is still true, in one sentence a reader can check.

The check then fails if any `refutedBy` target exists. A row that says a document
is absent, in a tree that contains it, is a defect -- whatever else is true.

Why the gap and remediation cells are scanned too (RER-03)
----------------------------------------------------------
The first version read `cells[4]` -- the evidence cell -- and nothing else. That
is one third of the surface a stale claim can live on. `MP-32-046` and
`MP-32-047` both carried the remediation "Document explicitly in the
incident-response runbook that post-incident evidence depends on the user
submitting their local log", against a tree whose `docs/release/incident_runbook.md`
section 6 already said exactly that. A reader following either remediation would
have written a sentence the repository already carried. No absence phrase in the
evidence cell could ever have caught it, because the defect was an IMPERATIVE in
the remediation cell.

Scanning every cell for every absence-shaped word would have produced ~90 rows
needing registration, of which the reviewer's own hand-review found one real
defect. Ceremony at that ratio is not verification -- it is boilerplate, and this
audit's value rests on not having any.

So the gap and remediation cells use a NARROWER, higher-signal rule
(`STALE_REPO_REFERENCE`): a claim of absence, or an imperative asking for work,
that NAMES A REPOSITORY ARTEFACT WHICH EXISTS. The referent is resolved
deterministically -- either a cited path, or a prose alias from `DOC_ALIASES`
below -- so the rule ties requirement ID + field + claimed absence + the exact
path being tested, and decides without reading English. On the tree that
introduced it, it fired on exactly the two rows that were wrong.

The bound of that rule, stated because certification found it (CERT-01/02)
--------------------------------------------------------------------------
The rule can only fire on a remediation that NAMES A FILE. It is structurally
blind to one that asks for a FACT or a BEHAVIOUR the repository already has:

    MP-67-001..004  "Name Play Console vitals as the alerting source and set a
                     checking cadence"   -- both already in observability_and_slo.md
                                            and incident_runbook.md section 2
    MP-23-012       "Ensure the paywall links out to the Play subscription
                     settings"           -- already implemented at two call sites

Neither names a path or a DOC_ALIASES phrase, so no widening of WORK_PHRASES
reaches them; deciding them needs someone to read the sentence and go look.
That is a real limit, and it is written here rather than left for a reader to
discover the way this pass did. What the widening below DOES buy is the class
that names a file and was missed on a technicality.

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

# Imperatives that ask a future engineer to PRODUCE something. A remediation is
# stale exactly when the thing it asks for is already in the tree.
#
# Widened after certification (CERT-05). The list used to hold eight verbs and
# was matched CASE-SENSITIVELY, while the absence check one line below it used
# `re.I`. `MP-50-012` said "... and document that in the rollout runbook" in
# lower case, naming a live DOC_ALIASES target, and slipped through on the
# capital letter alone. The verbs the audit actually uses in unresolved
# remediations were counted rather than guessed: Run 17, Add 14, Confirm 8,
# Verify 7, Include 7, Name 4, Rehearse 4, Document 3, Measure 2, plus single
# uses of Ensure, Cover, Require, Introduce and Adopt.
WORK_PHRASES = [
    r"\bDocument\b",
    r"\bAdd\b",
    r"\bCreate\b",
    r"\bWrite\b",
    r"\bImplement\b",
    r"\bExtend\b",
    r"\bAuthor\b",
    r"\bPublish\b",
    r"\bDefine\b",
    r"\bRecord\b",
    r"\bNote\b",
    r"\bInclude\b",
    r"\bIntroduce\b",
    r"\bRequire\b",
    r"\bCover\b",
    r"\bAdopt\b",
    r"\bEnsure\b",
    r"\bName\b",
]

# Prose names the audit uses for repository documents, mapped to the file each
# one denotes. This is what lets a claim be resolved to a PATH without parsing
# English: the row says "the incident-response runbook", the map says which file
# that is, and the tree says whether it exists.
DOC_ALIASES = {
    r"incident[- ]response runbook|incident runbook": "docs/release/incident_runbook.md",
    r"real[- ]device QA matrix|device QA matrix|QA matrix": "store/REAL_DEVICE_QA_MATRIX.md",
    r"master production checklist": "docs/MASTER_PRODUCTION_CHECKLIST.md",
    r"DR and key custody|key custody": "docs/release/dr_and_key_custody.md",
    r"production audit": "PRODUCTION_AUDIT.md",
    r"rollout runbook|staged[- ]rollout": "docs/release/incident_runbook.md",
    r"manual smoke test": "store/MANUAL_SMOKE_TEST_SCRIPT.md",
    r"play submission": "docs/play-submission.md",
    r"handover": "docs/HANDOVER.md",
    r"changelog": "CHANGELOG.md",
}

# The canonical 9-column row: ID | Requirement | Appl. | Status | Sev | Evidence
# | Gap | Remediation | Verif. Indices are into the cells AFTER the ID.
FIELD_INDEX = {"evidence": 4, "gap": 5, "remediation": 6}
DEFAULT_FIELD = "evidence"

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
        if len(cells) < 7:
            continue
        rows[match.group(1)] = {
            "requirement": cells[0],
            "status": cells[2].replace("*", "").strip(),
            **{name: cells[i] for name, i in FIELD_INDEX.items()},
        }
    return rows


def referenced_existing_artifact(repo: Path, text: str) -> str | None:
    """The repository file this text names, if the tree actually contains it.

    Two deterministic forms: a cited path (`lib/...dart`, `docs/...md`) and a
    prose alias from DOC_ALIASES. Returns the path, or None when the text names
    nothing the repository has -- in which case there is nothing to be stale
    ABOUT and the row is left alone.
    """
    for cited in CITED_DOC_PATH.findall(text):
        if (repo / cited).exists():
            return cited
    for pattern, path in DOC_ALIASES.items():
        if re.search(pattern, text, re.I) and (repo / path).exists():
            return path
    return None


def claims_needing_registration(rows: dict, repo: Path | None = None) -> list:
    """Every (requirement id, field) pair that must carry a registry entry.

    EVIDENCE keeps the original contract: any absence phrase needs registration,
    because the evidence cell is what a reader treats as fact.

    GAP and REMEDIATION use the narrower STALE_REPO_REFERENCE rule described in
    the module docstring: a claim of absence, or an imperative asking for work,
    that names a repository artefact the tree already contains.
    """
    base = repo or REPO
    out = []
    for rid, row in sorted(rows.items()):
        if row["status"] in RESOLVED:
            continue
        if any(re.search(p, row["evidence"], re.I) for p in ABSENCE_PHRASES):
            out.append((rid, "evidence"))
        for field in ("gap", "remediation"):
            text = row.get(field, "")
            claims_absence = any(
                re.search(p, text, re.I) for p in ABSENCE_PHRASES
            )
            # `re.I`, matching the absence check above it. The asymmetry was
            # not a decision; it was a missing flag (CERT-05).
            asks_for_work = any(re.search(p, text, re.I) for p in WORK_PHRASES)
            if not (claims_absence or asks_for_work):
                continue
            if referenced_existing_artifact(base, text):
                out.append((rid, field))
    return out


def registry_entries(registry: dict, rid: str) -> list:
    """Normalises the two accepted shapes into a list of field-tagged entries.

    A row with one claim stays a plain object (44 of them predate the field
    model and are all `evidence`); a row whose gap AND remediation both carry a
    claim becomes a list. Both are read the same way here.
    """
    raw = registry.get(rid)
    if raw is None:
        return []
    items = raw if isinstance(raw, list) else [raw]
    return [{**item, "field": item.get("field", DEFAULT_FIELD)} for item in items]


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


# A path a row cites as evidence. Restricted to the four repository-internal
# trees whose files are named in full; `android/.../Foo.kt` is an established
# abbreviation in this document and is deliberately not matched.
CITED_PATH = re.compile(
    r"\b((?:lib|test|scripts|config)/[A-Za-z0-9_./-]+\.(?:dart|py|json|sh|yaml))"
)

# A DOCUMENT path a gap or remediation cell names. Wider than CITED_PATH because
# the stale-remediation class is about prose deliverables (`docs/`, `store/`),
# not source files.
CITED_DOC_PATH = re.compile(
    r"\b((?:docs|store|config|scripts)/[A-Za-z0-9_./-]+\.(?:md|json|sh|py))"
)


def missing_cited_paths(audit: Path) -> list:
    """Rows whose evidence cites a repository file that does not exist.

    The mirror image of a stale absence claim: a row can rot either by denying
    something present or by pointing at something gone. `MP-15-013` cited
    `auth_gate.dart` as proof of the returning-user path -- a file that never
    took part in that decision and was deleted as dead code (FIR-07).
    """
    problems = []
    for line in audit.read_text(encoding="utf-8").splitlines():
        match = ROW.match(line)
        if not match:
            continue
        for cited in sorted(set(CITED_PATH.findall(match.group(2)))):
            if not (audit.parent / cited).exists():
                problems.append(
                    f"CITED_PATH_MISSING {match.group(1)}: evidence names "
                    f"{cited}, which does not exist. Re-point the row at what "
                    f"actually carries the behaviour."
                )
    return problems


def check(repo: Path, audit: Path, registry_path: Path) -> list:
    problems = missing_cited_paths(audit)
    rows = audit_rows(audit)
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    entries = registry["claims"]

    for rid, field in claims_needing_registration(rows, repo):
        registered = {e["field"] for e in registry_entries(entries, rid)}
        if field in registered:
            continue
        if field == "evidence":
            problems.append(
                f"UNREGISTERED_ABSENCE_CLAIM {rid}: its evidence asserts an "
                f"absence but no entry names what would refute it. Add one to "
                f"{registry_path.name}."
            )
        else:
            artefact = referenced_existing_artifact(repo, rows[rid][field])
            problems.append(
                f"STALE_REPO_REFERENCE {rid} [{field}]: the cell claims an "
                f"absence or asks for work while naming {artefact}, which "
                f"EXISTS. Either the work is already done and the cell must say "
                f"so, or register the claim in {registry_path.name} with the "
                f"field set to {field!r} and say why it is still open."
            )

    for rid in sorted(entries):
        row = rows.get(rid)
        if row is None:
            problems.append(f"UNKNOWN_ROW {rid}: registered but not in the audit.")
            continue
        for entry in registry_entries(entries, rid):
            field = entry["field"]
            if field not in FIELD_INDEX:
                problems.append(
                    f"UNKNOWN_FIELD {rid}: {field!r} is not one of "
                    f"{sorted(FIELD_INDEX)}."
                )
                continue
            cell = row[field]
            if entry["claim"] not in cell:
                problems.append(
                    f"STALE_REGISTRY_ENTRY {rid} [{field}]: the registered "
                    f"phrase {entry['claim']!r} no longer appears in the row's "
                    f"{field} cell, so nothing here is checking the claim the "
                    f"row now makes."
                )
            for target in entry.get("refutedBy", []):
                if target_exists(repo, target):
                    problems.append(
                        f"REFUTED_ABSENCE_CLAIM {rid} [{field}]: the row asserts "
                        f"{entry['claim']!r}, but {target} EXISTS. Re-grade the "
                        f"row against the tree instead of restating the claim."
                    )
            if not entry.get("refutedBy") and not entry.get("why"):
                problems.append(
                    f"UNJUSTIFIED_CLAIM {rid} [{field}]: no refuting path and "
                    f"no reason given."
                )
    return problems


def _control_registered_claim_refuted(
    repo: Path, audit: Path, registry_path: Path, field: str
) -> tuple:
    """Registers a claim, on `field`, refuted by a file that certainly exists.

    Run for `evidence` AND for a gap/remediation cell, because the whole point of
    RER-03 is that a rule which only ever ran against one cell proved nothing
    about the other two.
    """
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    rows = audit_rows(audit)
    victim = next(
        (
            rid
            for rid, row in sorted(rows.items())
            if row["status"] not in RESOLVED and row.get(field, "").strip()
        ),
        None,
    )
    if victim is None:
        return (field, False, f"no unresolved row has a non-empty {field} cell")
    baseline = check(repo, audit, registry_path)
    registry["claims"][victim] = {
        "field": field,
        "claim": rows[victim][field][:40],
        "refutedBy": ["PRODUCTION_AUDIT.md"],
        "why": "negative control",
    }
    scratch = registry_path.parent / f"_absence_claims_control_{field}.json"
    scratch.write_text(json.dumps(registry, indent=2), encoding="utf-8")
    try:
        mutated = check(repo, audit, scratch)
    finally:
        scratch.unlink()
    fired = [
        problem
        for problem in mutated
        if problem.startswith("REFUTED_ABSENCE_CLAIM") and f"[{field}]" in problem
    ]
    if not fired or len(mutated) <= len(baseline):
        return (
            field,
            False,
            f"a {field} claim refuted by an existing file did not fire "
            f"({len(baseline)} -> {len(mutated)})",
        )
    return (
        field,
        True,
        f"REFUTED_ABSENCE_CLAIM fired on {victim} [{field}]; problems "
        f"{len(baseline)} -> {len(mutated)}",
    )


def _control_stale_repo_reference(
    repo: Path, audit: Path, registry_path: Path
) -> tuple:
    """Mutates a REMEDIATION cell to demand work that the tree already contains.

    This is the RER-03 defect reproduced deliberately: an imperative naming an
    existing document, with nothing registered against it. It exercises the
    ENUMERATION rule, which the refuted-claim controls above never touch --
    they mutate the registry, so they can only ever prove the consumption half.
    """
    baseline = check(repo, audit, registry_path)
    rows = audit_rows(audit)
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    victim = next(
        (
            rid
            for rid, row in sorted(rows.items())
            if row["status"] not in RESOLVED
            and "remediation"
            not in {e["field"] for e in registry_entries(registry["claims"], rid)}
        ),
        None,
    )
    if victim is None:
        return ("staleRepoReference", False, "no unregistered unresolved row to mutate")

    injected = (
        "Document explicitly in the incident-response runbook that post-incident "
        "evidence depends on the user submitting their local log."
    )
    lines = audit.read_text(encoding="utf-8").splitlines(keepends=True)
    out, patched = [], False
    for line in lines:
        match = ROW.match(line)
        if match and match.group(1) == victim and not patched:
            cells = match.group(2).split("|")
            if len(cells) >= 7:
                cells[6] = f" {injected} "
                line = f"| `{victim}` |" + "|".join(cells)
                if not line.endswith("\n"):
                    line += "\n"
                patched = True
        out.append(line)
    if not patched:
        return ("staleRepoReference", False, f"could not patch {victim}'s remediation")

    scratch = audit.parent / "PRODUCTION_AUDIT._control.md"
    scratch.write_text("".join(out), encoding="utf-8")
    try:
        mutated = check(repo, scratch, registry_path)
    finally:
        scratch.unlink()
    fired = [
        problem
        for problem in mutated
        if problem.startswith(f"STALE_REPO_REFERENCE {victim} [remediation]")
    ]
    if not fired or len(mutated) <= len(baseline):
        return (
            "staleRepoReference",
            False,
            f"an imperative naming an existing document did not fire on {victim} "
            f"({len(baseline)} -> {len(mutated)})",
        )
    return (
        "staleRepoReference",
        True,
        f"STALE_REPO_REFERENCE fired on {victim} [remediation]; problems "
        f"{len(baseline)} -> {len(mutated)}",
    )


def negative_control(repo: Path, audit: Path, registry_path: Path) -> int:
    """Three controls, one per rule this verifier actually enforces.

    A single control over one cell was how the evidence-only blind spot survived
    review: the control mutated a known evidence claim, so it exercised the
    consumption logic and never the enumeration, and never the other two cells.
    """
    results = [
        _control_registered_claim_refuted(repo, audit, registry_path, "evidence"),
        _control_registered_claim_refuted(repo, audit, registry_path, "remediation"),
        _control_stale_repo_reference(repo, audit, registry_path),
    ]
    failed = [r for r in results if not r[1]]
    for name, ok, message in results:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}: {message}")
    if failed:
        print(
            "NEGATIVE_CONTROL_FAIL absence_claims: "
            f"{len(failed)} of {len(results)} controls did not fire"
        )
        return 1
    print(
        f"NEGATIVE_CONTROL_PASS absence_claims: {len(results)}/{len(results)} controls "
        "fired -- REFUTED_ABSENCE_CLAIM on the evidence and remediation cells, "
        "STALE_REPO_REFERENCE on an imperative naming an existing document"
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
