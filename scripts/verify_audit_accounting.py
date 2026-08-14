#!/usr/bin/env python3
"""Deterministic accounting gate between the canonical checklist and the audit.

The audit must DESCRIBE the checklist. The checklist is never rewritten to fit
the audit, so this script only ever reports; it never edits either file.

It exists because counting lines is not the same as accounting. Round 1 of the
independent review found five mutually contradictory summary tables and 24
requirements (the section-77 launch matrix, expressed as a tab-separated table
rather than checkboxes) that a checkbox-only parser silently dropped. Checks
here therefore compare IDs, section association, requirement TEXT in order, and
every derived total against the rows they claim to summarise.

Usage:
    python3 scripts/verify_audit_accounting.py \
        --checklist docs/MASTER_PRODUCTION_CHECKLIST.md \
        --audit PRODUCTION_AUDIT.md \
        [--output out.json]

Exit code 0 == AUDIT_ACCOUNTING_PASS.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

VALID_STATUSES = {"PASS", "FAIL", "PARTIAL", "BLOCKED", "N/A", "UNVERIFIED"}
VALID_SEVERITIES = {"P0", "P1", "P2", "P3", "-"}
VALID_METHODS = {"SRC", "RUN", "TEST", "DOC", "NONE", "CMD"}

# The opening of an evidence cell that claims a measured, requirement-specific
# result. Rows that carry it are held to distinctness; rows that state a shared
# fact (no AI dependency, no ios/ directory, no server) are not.
MEASURED_EVIDENCE_MARKER = "MEASURED, not asserted"

SECTION_HEADING = re.compile(r"^##\s+(\d+)\.\s+(.*?)\s*$")
CHECKBOX = re.compile(r"^\s*-\s\[ \]\s+(.*?)\s*$")
AUDIT_ROW = re.compile(r"^\|\s*`(MP-(\d+)-(\d+))`\s*\|(.*)$")


def normalise(text: str) -> str:
    """NFC + case/punctuation-insensitive comparison key.

    The audit renders a few requirement strings with typographic substitutions
    (a pipe inside a code span becomes `//`, quotes get straightened). Those are
    presentation, not a different requirement, so they must not be reported as
    text mismatches -- but a genuinely different sentence still must be.
    """
    text = unicodedata.normalize("NFC", text)
    text = text.replace("’", "'").replace("‘", "'")
    text = text.replace("“", '"').replace("”", '"')
    text = text.replace("–", "-").replace("—", "-")
    text = re.sub(r"[^\w\s]", "", text, flags=re.UNICODE)
    text = re.sub(r"\s+", " ", text)
    return text.strip().casefold()


def parse_checklist(path: Path) -> tuple[list[dict], list[str]]:
    """Returns (requirements, problems).

    A requirement is every `- [ ]` checkbox PLUS every row of the section-77
    launch matrix, which is a two-column tab-separated table with an `Alan`
    header rather than checkboxes.
    """
    problems: list[str] = []
    requirements: list[dict] = []
    section: int | None = None
    section_titles: dict[int, str] = {}
    in_launch_matrix = False

    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        heading = SECTION_HEADING.match(raw)
        if heading:
            section = int(heading.group(1))
            section_titles[section] = heading.group(2)
            in_launch_matrix = False
            continue

        box = CHECKBOX.match(raw)
        if box:
            if section is None:
                problems.append(f"checklist:{lineno}: checkbox before any section heading")
                continue
            requirements.append(
                {"section": section, "text": box.group(1), "line": lineno, "kind": "checkbox"}
            )
            continue

        # Section 77's launch matrix. Detected by its own header row so a future
        # tab-separated table elsewhere cannot be swept in by accident.
        if section == 77 and raw.startswith("Alan\t"):
            in_launch_matrix = True
            continue
        if in_launch_matrix:
            if not raw.strip() or raw.startswith("#"):
                in_launch_matrix = False
                continue
            if "\t" not in raw:
                in_launch_matrix = False
                continue
            area, gate = raw.split("\t", 1)
            requirements.append(
                {
                    "section": 77,
                    "text": f"{area.strip()} — {gate.strip()}",
                    "line": lineno,
                    "kind": "launch-matrix",
                }
            )

    return requirements, problems


def parse_audit(path: Path) -> tuple[list[dict], dict, list[str]]:
    """Returns (rows, tables, problems).

    Only rows inside a `## <n>.` section body are requirement rows. The P0/P1
    register near the top legitimately re-lists P1 IDs and must be excluded, or
    every P1 reads as a duplicate.
    """
    problems: list[str] = []
    rows: list[dict] = []
    section: int | None = None
    in_body = False
    summary: dict[str, int] = {}
    severity: dict[str, int] = {}
    section_index: dict[int, dict[str, int]] = {}
    register_ids: list[str] = []

    lines = path.read_text(encoding="utf-8").splitlines()
    mode = None
    for lineno, raw in enumerate(lines, 1):
        heading = SECTION_HEADING.match(raw)
        if heading:
            section = int(heading.group(1))
            in_body = True
            mode = None
            continue

        if raw.startswith("### P0 / P1 register"):
            mode = "register"
            continue
        if raw.startswith("### Section index"):
            mode = "section-index"
            continue
        if raw.startswith("### Severity of non-PASS findings"):
            mode = "severity"
            continue
        if raw.startswith("## Result summary"):
            mode = "summary"
            continue

        if mode == "summary" and raw.startswith("|"):
            cells = [c.strip() for c in raw.strip("|").split("|")]
            if len(cells) == 2:
                label = cells[0].replace("*", "").strip().upper()
                value = cells[1].replace("*", "").strip()
                digits = re.match(r"^(\d+)", value)
                if digits and label in {
                    "PASS", "FAIL", "PARTIAL", "BLOCKED", "N/A", "UNVERIFIED",
                    "CHECKLIST REQUIREMENTS", "AUDIT REQUIREMENTS", "UNACCOUNTED",
                    "MISSING", "DUPLICATED",
                }:
                    summary[label] = int(digits.group(1))

        if mode == "severity" and raw.startswith("|"):
            cells = [c.strip() for c in raw.strip("|").split("|")]
            if len(cells) == 2 and cells[0] in VALID_SEVERITIES:
                if cells[1].isdigit():
                    severity[cells[0]] = int(cells[1])

        if mode == "section-index" and raw.startswith("|"):
            cells = [c.strip() for c in raw.strip("|").split("|")]
            if len(cells) == 7 and cells[0].isdigit():
                section_index[int(cells[0])] = {
                    "PASS": int(cells[1]), "FAIL": int(cells[2]),
                    "PARTIAL": int(cells[3]), "BLOCKED": int(cells[4]),
                    "N/A": int(cells[5]), "UNVERIFIED": int(cells[6]),
                }

        match = AUDIT_ROW.match(raw)
        if not match:
            continue
        req_id, sec_str, item_str = match.group(1), match.group(2), match.group(3)
        if mode == "register" and not in_body:
            register_ids.append(req_id)
            continue
        if not in_body or section is None:
            problems.append(f"audit:{lineno}: requirement row {req_id} outside any section body")
            continue

        cells = [c.strip() for c in raw.strip("|").split("|")]
        if len(cells) != 9:
            problems.append(
                f"audit:{lineno}: {req_id} has {len(cells)} columns, expected 9"
            )
            continue
        status = cells[3].replace("*", "").strip()
        sev = cells[4].strip()
        method = cells[8].strip().strip("`").strip()
        rows.append(
            {
                "id": req_id,
                "section": int(sec_str),
                "item": int(item_str),
                "heading_section": section,
                "text": cells[1],
                "applicability": cells[2],
                "status": status,
                "severity": sev,
                "evidence": cells[5],
                "verification": method,
                "line": lineno,
            }
        )

    return rows, {
        "summary": summary,
        "severity": severity,
        "sectionIndex": section_index,
        "registerIds": register_ids,
    }, problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checklist", default="docs/MASTER_PRODUCTION_CHECKLIST.md")
    parser.add_argument("--audit", default="PRODUCTION_AUDIT.md")
    parser.add_argument("--output")
    args = parser.parse_args()

    checklist_path = Path(args.checklist)
    audit_path = Path(args.audit)
    for path in (checklist_path, audit_path):
        if not path.is_file():
            print(f"AUDIT_ACCOUNTING_FAIL\n- MISSING_FILE {path}")
            return 1

    requirements, problems = parse_checklist(checklist_path)
    rows, tables, audit_problems = parse_audit(audit_path)
    problems.extend(audit_problems)

    # ---- identity: one canonical audit row per requirement --------------
    id_counts = Counter(row["id"] for row in rows)
    duplicated = sorted(i for i, n in id_counts.items() if n > 1)
    for dup in duplicated:
        problems.append(f"DUPLICATED_ROW {dup} appears {id_counts[dup]} times")

    by_section_checklist: dict[int, list[dict]] = defaultdict(list)
    for req in requirements:
        by_section_checklist[req["section"]].append(req)

    by_section_audit: dict[int, list[dict]] = defaultdict(list)
    for row in rows:
        by_section_audit[row["section"]].append(row)

    expected_ids: list[str] = []
    for section in sorted(by_section_checklist):
        for index in range(1, len(by_section_checklist[section]) + 1):
            expected_ids.append(f"MP-{section:02d}-{index:03d}")

    actual_ids = {row["id"] for row in rows}
    missing = [i for i in expected_ids if i not in actual_ids]
    unaccounted = sorted(actual_ids - set(expected_ids))
    for item in missing:
        problems.append(f"MISSING_ROW {item} has no canonical audit row")
    for item in unaccounted:
        problems.append(f"UNACCOUNTED_ROW {item} has no checklist requirement")

    # ---- section association, contiguity, vocabulary --------------------
    for row in rows:
        if row["section"] != row["heading_section"]:
            problems.append(
                f"SECTION_MISMATCH {row['id']} sits under heading "
                f"{row['heading_section']}"
            )
        if row["status"] not in VALID_STATUSES:
            problems.append(f"INVALID_STATUS {row['id']} = {row['status']!r}")
        if row["severity"] not in VALID_SEVERITIES:
            problems.append(f"INVALID_SEVERITY {row['id']} = {row['severity']!r}")
        if row["verification"] not in VALID_METHODS:
            problems.append(
                f"INVALID_METHOD {row['id']} = {row['verification']!r}"
            )
        if row["status"] == "N/A" and row["severity"] != "-":
            problems.append(f"NA_WITH_SEVERITY {row['id']} = {row['severity']}")
        if row["status"] == "PASS" and row["severity"] != "-":
            problems.append(f"PASS_WITH_SEVERITY {row['id']} = {row['severity']}")
        if row["status"] not in {"PASS", "N/A"} and row["severity"] == "-":
            problems.append(f"UNRESOLVED_WITHOUT_SEVERITY {row['id']}")
        if not row["evidence"] or row["evidence"] == "-":
            problems.append(f"EMPTY_EVIDENCE {row['id']}")

    for section in sorted(by_section_audit):
        items = sorted(r["item"] for r in by_section_audit[section])
        if items != list(range(1, len(items) + 1)):
            problems.append(f"NON_CONTIGUOUS_NUMBERING section {section}")

    # ---- requirement text equality, in order, per section ---------------
    text_mismatches = 0
    for section in sorted(by_section_checklist):
        expected = by_section_checklist[section]
        actual = sorted(by_section_audit.get(section, []), key=lambda r: r["item"])
        if len(expected) != len(actual):
            problems.append(
                f"SECTION_COUNT_DELTA section {section}: checklist "
                f"{len(expected)} vs audit {len(actual)}"
            )
        for req, row in zip(expected, actual):
            if normalise(req["text"]) != normalise(row["text"]):
                text_mismatches += 1
                problems.append(
                    f"TEXT_MISMATCH {row['id']}: checklist {req['text']!r} != "
                    f"audit {row['text']!r}"
                )

    # ---- derived tables must be regenerated, not hand-maintained --------
    actual_status = Counter(row["status"] for row in rows)
    for status in sorted(VALID_STATUSES):
        declared = tables["summary"].get(status)
        if declared is None:
            problems.append(f"SUMMARY_MISSING {status}")
        elif declared != actual_status.get(status, 0):
            problems.append(
                f"SUMMARY_DRIFT {status}: table says {declared}, rows say "
                f"{actual_status.get(status, 0)}"
            )

    actual_severity = Counter(
        row["severity"] for row in rows if row["severity"] != "-"
    )
    for sev in ("P0", "P1", "P2", "P3"):
        declared = tables["severity"].get(sev)
        if declared is None:
            problems.append(f"SEVERITY_MISSING {sev}")
        elif declared != actual_severity.get(sev, 0):
            problems.append(
                f"SEVERITY_DRIFT {sev}: table says {declared}, rows say "
                f"{actual_severity.get(sev, 0)}"
            )

    for section in sorted(by_section_audit):
        declared = tables["sectionIndex"].get(section)
        if declared is None:
            problems.append(f"SECTION_INDEX_MISSING section {section}")
            continue
        counted = Counter(r["status"] for r in by_section_audit[section])
        for status in sorted(VALID_STATUSES):
            if declared.get(status, 0) != counted.get(status, 0):
                problems.append(
                    f"SECTION_INDEX_DRIFT section {section} {status}: "
                    f"table {declared.get(status, 0)} vs rows "
                    f"{counted.get(status, 0)}"
                )

    total_declared = tables["summary"].get("AUDIT REQUIREMENTS")
    if total_declared != len(rows):
        problems.append(
            f"TOTAL_DRIFT: table says {total_declared}, rows say {len(rows)}"
        )
    checklist_declared = tables["summary"].get("CHECKLIST REQUIREMENTS")
    if checklist_declared != len(requirements):
        problems.append(
            f"CHECKLIST_TOTAL_DRIFT: table says {checklist_declared}, checklist "
            f"has {len(requirements)}"
        )
    if sum(actual_status.values()) != len(rows):
        problems.append("STATUS_SUM_DRIFT: statuses do not sum to row count")

    # ---- the register must list every P0/P1 row, and only those ---------
    register = set(tables["registerIds"])
    critical = {row["id"] for row in rows if row["severity"] in {"P0", "P1"}}
    for item in sorted(critical - register):
        problems.append(f"REGISTER_MISSING {item} is P0/P1 but not registered")
    for item in sorted(register - critical):
        problems.append(f"REGISTER_STALE {item} is registered but not P0/P1")

    # ---- MEASURED evidence must be requirement-specific (the IR-06 guard) -
    #
    # IR-06 was 135 rows carrying one SECTION-LEVEL sentence that did not answer
    # the row. `apply_evidence_matrix.py` refuses to GENERATE two identical
    # evidence strings, which closed that. But it only covers rows it generates,
    # and this pass proved the gap: three notification rows were written straight
    # into the audit with `set_audit_row.py`, sharing one sentence, and every
    # check stayed green. The audit table is what a reader sees, so the
    # invariant has to hold in the table.
    #
    # Scoped deliberately. 662 N/A rows share a genuinely identical FACT -- 76 of
    # them say "no AI/LLM dependency exists", others "no ios/ or web/ directory",
    # "no server component". Those requirements really do have one and the same
    # answer, and writing 76 differently-worded sentences for one fact is exactly
    # the defect IR-06 warned about, reproduced in different words. Sharing a
    # true fact is not boilerplate.
    #
    # What IS checked: rows whose evidence CLAIMS a measured, requirement-
    # specific result. Two of those answering with one sentence means at least
    # one of them was never actually measured.
    seen_evidence: dict[str, str] = {}
    duplicated_evidence: list[str] = []
    for row in rows:
        evidence = row.get("evidence", "")
        if not evidence.startswith(MEASURED_EVIDENCE_MARKER):
            continue
        first = seen_evidence.get(evidence)
        if first is not None:
            duplicated_evidence.append(f"{row['id']} == {first}")
        else:
            seen_evidence[evidence] = row["id"]
    for item in duplicated_evidence:
        problems.append(
            f"EVIDENCE_DUPLICATED {item}: both claim a MEASURED, "
            f"requirement-specific result and answer with the same sentence, so "
            f"at least one of them was not measured"
        )

    payload = {
        "checklistRequirements": len(requirements),
        "auditRequirements": len(rows),
        "duplicatedEvidence": len(duplicated_evidence),
        "missing": len(missing),
        "duplicated": len(duplicated),
        "unaccounted": len(unaccounted),
        "textMismatches": text_mismatches,
        "sections": len(by_section_checklist),
        "launchMatrixRequirements": sum(
            1 for r in requirements if r["kind"] == "launch-matrix"
        ),
        "checkboxRequirements": sum(
            1 for r in requirements if r["kind"] == "checkbox"
        ),
        "status": dict(sorted(actual_status.items())),
        "severity": dict(sorted(actual_severity.items())),
        "problems": problems,
        "pass": not problems,
    }

    if args.output:
        Path(args.output).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    if problems:
        print("AUDIT_ACCOUNTING_FAIL")
        for problem in problems[:60]:
            print(f"- {problem}")
        if len(problems) > 60:
            print(f"- ... and {len(problems) - 60} more")
        return 1

    print(
        "AUDIT_ACCOUNTING_PASS "
        f"checklist={len(requirements)} audit={len(rows)} missing=0 "
        f"duplicated=0 unaccounted=0 sections={len(by_section_checklist)} "
        f"launchMatrix={payload['launchMatrixRequirements']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
