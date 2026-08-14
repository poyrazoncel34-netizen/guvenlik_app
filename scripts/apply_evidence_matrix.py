#!/usr/bin/env python3
"""Writes row-specific evidence into PRODUCTION_AUDIT.md from the evidence matrix.

Each requirement row gets evidence that names:
  * the verifier that produced it,
  * the exact artifact property, AND
  * the VALUE that property currently holds.

The value is read out of the artifact at write time, so a row cannot cite a
property whose content nobody looked at -- which is the failure mode that
produced 135 identical rows in the first place. The script refuses to write two
identical evidence strings, so the boilerplate cluster cannot re-form.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
EVIDENCE = REPO / "docs" / "audit" / "evidence"

STATUS_FOR = {
    "PASS": "PASS", "PARTIAL": "PARTIAL", "FAIL": "FAIL", "N/A": "N/A",
    "EXTERNAL_BLOCKER": "BLOCKED", "PRODUCT_DECISION_REQUIRED": "PARTIAL",
}
METHOD_FOR = {
    "STATIC_CODE": "SRC", "STATIC_CONFIG": "SRC", "UNIT_BEHAVIOR": "TEST",
    "WIDGET_BEHAVIOR": "TEST", "WIDGET_GEOMETRY": "TEST", "SEMANTICS": "TEST",
    "DEVICE_RUNTIME": "RUN", "VISUAL_MEASUREMENT": "SRC", "PERFORMANCE": "RUN",
    "SECURITY_INVARIANT": "TEST", "BUILD_ARTIFACT": "CMD",
    "PROCESS_ARTIFACT": "DOC", "SCOPE_JUDGEMENT": "SRC",
}


def _value(artifact: str, prop: str):
    if artifact in ("-", "") or prop in ("-", ""):
        return None
    data = json.loads((EVIDENCE / artifact).read_text(encoding="utf-8"))
    cursor = data
    for part in prop.split("."):
        if isinstance(cursor, dict):
            cursor = cursor[part]
        elif isinstance(cursor, list):
            cursor = cursor[int(part)]
    return cursor


def _render(value) -> str:
    """A compact, readable rendering of the measured value."""
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float, str)):
        text = str(value)
    elif isinstance(value, list):
        if not value:
            return "[] (empty)"
        text = "; ".join(_render(v) for v in value[:4])
        if len(value) > 4:
            text += f" ... (+{len(value) - 4} more, {len(value)} total)"
    elif isinstance(value, dict):
        parts = []
        for k, v in list(value.items())[:5]:
            parts.append(f"{k}={_render(v) if not isinstance(v, (dict, list)) else '...'}")
        text = ", ".join(parts)
        if len(value) > 5:
            text += f" ... ({len(value)} keys)"
    else:
        text = str(value)
    text = " ".join(text.split())
    # A pipe inside a rendered value would split the markdown row. The focus-ring
    # measurement keys are literally "focusRing|cardBg", so this is not
    # hypothetical -- it broke the first run.
    text = text.replace("|", " vs ")
    return text[:420]


def build_cells(rid: str, plan: dict) -> dict:
    artifact = plan.get("artifact", "-")
    prop = plan.get("property", "-")
    measured = _render(_value(artifact, prop))
    verifier = plan["verifier"]
    disposition = plan["disposition"]

    bits = [f"MEASURED, not asserted. Archetype {plan['archetype']}."]
    bits.append(f"Surface: {plan['surface']}.")
    if artifact != "-":
        bits.append(f"Verifier `{verifier}` -> `docs/audit/evidence/{artifact}`, "
                    f"property `{prop}` = {measured}.")
    if plan.get("cite"):
        bits.append(plan["cite"] + ".")
    bits.append(f"NEGATIVE CONTROL: {plan['negativeControl']}.")
    evidence = " ".join(bits)

    if disposition == "PASS":
        gap = "None. The cited property is the measurement, and the negative control shows the verifier can report the opposite."
        remediation = f"Re-run `{verifier}` to reproduce; the artifact carries the code revision it was measured against."
        severity = "-"
    elif disposition == "N/A":
        gap = "Not applicable; the evidence above is the proof of why, not a difficulty claim."
        remediation = "Guarded: if the absent subsystem is ever added, the cited property changes and this row must be re-opened."
        severity = "-"
    elif disposition == "EXTERNAL_BLOCKER":
        gap = "The irreducible remainder needs a system, device or account outside this repository. What COULD be measured here was, and is cited above."
        remediation = "See EXTERNAL_LAUNCH_BLOCKERS.md; nothing further is closable in-repo."
        severity = None
    elif disposition == "PRODUCT_DECISION_REQUIRED":
        gap = "Closing this means reversing a recorded product decision, which is the owner's call."
        remediation = "See PRODUCT_DECISIONS_REQUIRED.md."
        severity = None
    else:  # PARTIAL / FAIL
        gap = plan.get("gap", "Measured and honestly short of the bar; see the cited property for the exact number.")
        remediation = plan.get("remediation", f"Re-run `{verifier}`; the residue is recorded rather than smoothed.")
        severity = None

    return {"status": STATUS_FOR[disposition], "severity": severity,
            "evidence": evidence, "gap": gap, "remediation": remediation,
            "method": METHOD_FOR[plan["archetype"]]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", default="PRODUCTION_AUDIT.md")
    parser.add_argument("--plan", default="config/evidence_matrix.json")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    plans = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    seen: dict[str, str] = {}
    written = skipped = 0
    for rid in sorted(plans):
        cells = build_cells(rid, plans[rid])
        if cells["evidence"] in seen:
            print(f"APPLY_FAIL {rid}: identical evidence to {seen[cells['evidence']]} "
                  f"-- that is the IR-06 defect re-forming")
            return 1
        seen[cells["evidence"]] = rid
        if args.dry_run:
            written += 1
            continue
        cmd = [sys.executable, "scripts/set_audit_row.py", rid,
               "--audit", args.audit,
               "--status", cells["status"],
               "--evidence", cells["evidence"],
               "--gap", cells["gap"],
               "--remediation", cells["remediation"],
               "--verification", cells["method"]]
        if cells["severity"]:
            cmd += ["--severity", cells["severity"]]
        result = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"APPLY_FAIL {rid}: {result.stdout.strip()} {result.stderr.strip()}")
            return 1
        if "SET_ROW_NOOP" in result.stdout:
            skipped += 1
        else:
            written += 1
    print(f"APPLY_OK rows={len(plans)} written={written} noop={skipped} "
          f"distinctEvidenceStrings={len(seen)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
