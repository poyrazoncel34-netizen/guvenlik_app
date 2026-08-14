#!/usr/bin/env python3
"""Generates RESOLUTION_QUEUE.md from the unresolved rows of PRODUCTION_AUDIT.md.

A hand-kept queue drifts from the audit the same way the summary tables did, and
then work gets silently dropped. This regenerates it, so the queue can never
claim progress the audit does not carry, and no unresolved requirement can be
left off it.

The scope classification is a FIRST PASS derived from each row's own recorded
gap and remediation text. Rows whose scope has been decided by hand are pinned
in SCOPE_OVERRIDES so a regeneration cannot silently undo a human judgement.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

# Hand-decided scopes. Each entry needs a reason, so a later reader can
# challenge the judgement rather than inherit it.
SCOPE_OVERRIDES: dict[str, tuple[str, str]] = {
    # --- P1s the heuristic read as in-repo but are not --------------------
    "MP-54-023": (
        "EXTERNAL_BLOCKER",
        "Trial start cannot be observed without a Play internal-test account "
        "and a RevenueCat sandbox key (E1).",
    ),
    "MP-54-024": (
        "EXTERNAL_BLOCKER",
        "Trial EXPIRY needs a real trial to elapse on a Play test account (E1).",
    ),
    "MP-59-029": (
        "EXTERNAL_BLOCKER",
        "Play policy acceptance of the sensitive-permission declarations is a "
        "decision Google makes (E3).",
    ),
    "MP-74-007": (
        "EXTERNAL_BLOCKER",
        "An indeterminate payment outcome only occurs against a real billing "
        "backend (E1).",
    ),
    # --- misclassified by the gap-text heuristic; corrected by hand ----------
    # An emulator HAS a hardware keyboard and a measurable pixel grid, so these
    # are verifiable in this environment. Filing them as external would have
    # been using EXTERNAL_BLOCKER as a place to put work.
    **{
        f"MP-12-{i:03d}": (
            "RUNTIME_VERIFIABLE_NOW",
            "Keyboard operability is verifiable with the emulator's hardware "
            "keyboard; no physical device is required to reach a real verdict.",
        )
        for i in range(1, 10)
    },
    "MP-08-003": ("RUNTIME_VERIFIABLE_NOW", "Focus visibility is observable with the emulator's hardware keyboard."),
    "MP-08-004": ("RUNTIME_VERIFIABLE_NOW", "Focus order is observable with the emulator's hardware keyboard."),
    "MP-08-015": ("RUNTIME_VERIFIABLE_NOW", "Keyboard-driven operation is observable on the emulator."),
    "MP-12-017": (
        "IN_REPO_RESOLVABLE",
        "`Semantics(header: true)` on screen titles is a source change with a "
        "widget-test assertion. Nothing external is involved.",
    ),
    "MP-12-030": ("RUNTIME_VERIFIABLE_NOW", "Tap-target geometry is measurable on the emulator at a known density."),
    "MP-09-020": ("RUNTIME_VERIFIABLE_NOW", "Frame cost is measurable on the emulator."),
    **{
        f"MP-27-{i:03d}": (
            "RUNTIME_VERIFIABLE_NOW",
            "Memory and listener-leak behaviour is observable on the emulator.",
        )
        for i in (10, 11, 12)
    },
    "MP-40-022": ("RUNTIME_VERIFIABLE_NOW", "Memory consumption is measurable on the emulator."),
    **{
        f"MP-41-{i:03d}": (
            "RUNTIME_VERIFIABLE_NOW",
            "Cold/warm start is measurable on the emulator; a physical-device "
            "number is better evidence but is not required for a verdict.",
        )
        for i in (1, 2, 3)
    },
    # --- deliberate product scope, not an external dependency ---------------
    **{
        f"MP-07-{i:03d}": (
            "PRODUCT_DECISION_REQUIRED",
            "Portrait-phone-only is an explicit recorded product decision. "
            "Closing this means reversing that decision, which is the owner's.",
        )
        for i in (4, 5, 6, 7, 8, 11, 14)
    },
    "MP-47-013": ("PRODUCT_DECISION_REQUIRED", "Tablet/desktop form factors are deliberately out of scope."),
    "MP-47-014": ("PRODUCT_DECISION_REQUIRED", "Tablet/desktop form factors are deliberately out of scope."),
    "MP-59-018": ("PRODUCT_DECISION_REQUIRED", "Multiple screen sizes deliberately deferred (section 7)."),
    "MP-59-022": ("PRODUCT_DECISION_REQUIRED", "Foldable/large-screen support deliberately deferred to API 37."),
    "MP-59-023": ("PRODUCT_DECISION_REQUIRED", "Foldable/large-screen support deliberately deferred to API 37."),
    "MP-74-005": ("PRODUCT_DECISION_REQUIRED", "Tablets and foldables are deliberately unsupported."),
    "MP-50-012": ("PRODUCT_DECISION_REQUIRED", "No runtime feature flags exist; adding them is a product decision."),
    "MP-75-016": ("PRODUCT_DECISION_REQUIRED", "No runtime feature flags exist; adding them is a product decision."),
    "MP-46-028": (
        "PRODUCT_DECISION_REQUIRED",
        "Image-level visual regression means golden tests, which "
        ".claude/rules/dart/testing.md forbids in this repository. Closing this "
        "requires reversing that rule, which is an owner decision.",
    ),
    "MP-46-030": (
        "EXTERNAL_BLOCKER",
        "Manual screen-reader verification needs TalkBack on real hardware.",
    ),

    # --- 2026-08-14 convergence pass: reclassified WITH the measurement that
    # --- justifies it, never on difficulty. Each reason names the evidence.
    "MP-02-016": (
        "EXTERNAL_BLOCKER",
        "Whether the information architecture matches a USER'S mental model is a "
        "claim about people, not about source. flows.json measures the structure "
        "(depth 2, five destinations, one name per concept, 963 parity-tested "
        "keys); it cannot measure comprehension. Five real users, section 71.",
    ),
    "MP-03-013": (
        "EXTERNAL_BLOCKER",
        "Same class: layout.json measures visual dominance (one glow shadow, one "
        "arming animation, largest hit area) but 'the user understands where to "
        "look' is an observation of users, not of pixels.",
    ),
    "MP-04-015": (
        "PRODUCT_DECISION_REQUIRED",
        "design_tokens.json measures it: main.dart wires theme: AppTheme.lightTheme "
        "AND themeMode: ThemeMode.dark, so the light theme is maintained and "
        "unreachable. The two exits are 'ship light mode' or 'delete it'; both are "
        "the owner's call, and leaving it is the one option that lets it rot.",
    ),
    "MP-06-014": (
        "PRODUCT_DECISION_REQUIRED",
        "color.json measures the shortfall exactly: emergency text on its own 25% "
        "tint is 3.97:1 against a 4.5 bar, and the text input's resting boundary is "
        "1.50:1 against a 3.0 bar. The minimal fix is a brand-palette change "
        "(#FF6B6B clears both), which is a rendered-pixel change CLAUDE.md rule 4 "
        "reserves to the owner.",
    ),
    "MP-07-015": (
        "PRODUCT_DECISION_REQUIRED",
        "Portrait is locked in the manifest by the recorded portrait-only decision.",
    ),
    "MP-27-023": (
        "PRODUCT_DECISION_REQUIRED",
        "flows.json: no runtime feature-flag surface exists in lib/. Adding one is "
        "the same product decision already recorded for MP-50-012 / MP-75-016.",
    ),
    **{
        rid: (
            "EXTERNAL_BLOCKER",
            "Measured on the API 36 emulator and recorded in "
            "docs/audit/device-verification-2026-08-14-perf-resources.md; the "
            "irreducible remainder is an ABSOLUTE number on real silicon, which an "
            "emulator cannot produce. The emulator verdict (no leak signature, no "
            ">=2x-budget frame, no app-uid traffic) is kept, not discarded.",
        )
        for rid in ("MP-41-004", "MP-41-006", "MP-41-009", "MP-41-010", "MP-41-011")
    },
    "MP-46-031": (
        "EXTERNAL_BLOCKER",
        "A numeric performance-regression gate needs a physical-device baseline to "
        "be a threshold rather than a record of emulator jitter.",
    ),
    "MP-69-012": (
        "EXTERNAL_BLOCKER",
        "text_scale.json covers six logical viewports including the density-560 "
        "class; a real high-DPI PANEL is hardware.",
    ),
    "MP-69-013": (
        "EXTERNAL_BLOCKER",
        "Same: the 320dp width class is covered logically; a low-DPI panel is hardware.",
    ),
    "MP-77-022": (
        "EXTERNAL_BLOCKER",
        "The runbook now exists (incident_runbook.md) and records the drill as NOT "
        "REHEARSED. Rehearsing it means halting a real Play rollout.",
    ),
    "MP-80-017": (
        "EXTERNAL_BLOCKER",
        "Same drill. incident_runbook.md section 3 states the 4h target the "
        "rehearsal will be measured against, and section 8 records that it is unmet.",
    ),
    "MP-32-040": (
        "PRODUCT_DECISION_REQUIRED",
        "storage.json records the gap precisely: the five gates that run are pattern "
        "and type checks, not dataflow analysis. Adding Semgrep or CodeQL adds a "
        "third-party analysis service to a project whose envelope forbids a "
        "developer backend and analytics -- that boundary is the owner's to move.",
    ),
}

EXTERNAL_MARKERS = (
    "physical device", "physical aggressive", "real device", "real hardware",
    "hardware", "oem", "talkback", "screen reader", "five real users",
    "play console", "play internal", "revenuecat sandbox", "sandbox key", "mfa",
    "branch protection", "google play review", "play policy", "play app signing",
    "internal-test", "test account", "staged rollout", "canary", "keystore",
    "console", "licensed tester", "real telephony", "incoming call",
)
RUNTIME_MARKERS = (
    "unmeasured", "profiling", "startup time", "memory", "leak",
    "one device at one density", "not exercised", "not been exercised",
    "contrast is unmeasured", "keyboard operability", "frame", "jank",
)
PRODUCT_MARKERS = (
    "golden", "visual regression", "permanently unavailable", "deliberate",
    "by design", "accepted with rationale", "support is an unmanaged email inbox",
)

STATUS_ORDER = {"FAIL": 1, "PARTIAL": 2, "UNVERIFIED": 3, "BLOCKED": 4}
SEVERITY_ORDER = {"P0": 0, "P1": 1, "P2": 2, "P3": 3, "-": 4}


def parse_rows(audit: Path) -> list[dict]:
    rows: list[dict] = []
    section: int | None = None
    in_body = False
    for line in audit.read_text(encoding="utf-8").splitlines():
        heading = re.match(r"^##\s+(\d+)\.\s", line)
        if heading:
            section = int(heading.group(1))
            in_body = True
            continue
        if not in_body or not re.match(r"^\| `MP-\d+-\d+` \|", line):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) != 9:
            continue
        rows.append(
            {
                "id": cells[0].strip("`"),
                "text": cells[1],
                "status": cells[3].replace("*", "").strip(),
                "severity": cells[4],
                "gap": cells[6],
                "remediation": cells[7],
                "section": section,
            }
        )
    return rows


def classify(row: dict) -> tuple[str, str]:
    override = SCOPE_OVERRIDES.get(row["id"])
    if override:
        return override
    blob = f"{row['gap']} {row['remediation']}".lower()
    if row["status"] == "BLOCKED":
        return "EXTERNAL_BLOCKER", "recorded as BLOCKED in the audit"
    for marker in EXTERNAL_MARKERS:
        if marker in blob:
            return "EXTERNAL_BLOCKER", f"gap names an external dependency: {marker!r}"
    for marker in PRODUCT_MARKERS:
        if marker in blob:
            return "PRODUCT_DECISION_REQUIRED", f"gap names a policy constraint: {marker!r}"
    for marker in RUNTIME_MARKERS:
        if marker in blob:
            return "RUNTIME_VERIFIABLE_NOW", f"gap names a runtime measurement: {marker!r}"
    return "IN_REPO_RESOLVABLE", "no external dependency recorded in the gap"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", default="PRODUCTION_AUDIT.md")
    parser.add_argument("--output", default="RESOLUTION_QUEUE.md")
    args = parser.parse_args()

    rows = parse_rows(Path(args.audit))
    if not rows:
        print("QUEUE_FAIL: no requirement rows parsed")
        return 1

    unresolved = [r for r in rows if r["status"] in STATUS_ORDER]
    for row in unresolved:
        row["scope"], row["scopeReason"] = classify(row)
    unresolved.sort(
        key=lambda r: (
            SEVERITY_ORDER.get(r["severity"], 9),
            STATUS_ORDER[r["status"]],
            r["section"],
            int(r["id"].rsplit("-", 1)[1]),
        )
    )

    counts = Counter(r["scope"] for r in unresolved)
    per_status: dict[str, Counter] = defaultdict(Counter)
    for row in unresolved:
        per_status[row["status"]][row["scope"]] += 1

    out: list[str] = [
        "# RESOLUTION QUEUE",
        "",
        "> Generated from the unresolved rows of `PRODUCTION_AUDIT.md` by",
        "> `scripts/generate_resolution_queue.py`. Never hand-maintained: a hand-kept queue",
        "> drifts from the audit exactly the way the summary tables did, and then work gets",
        "> silently dropped. Regenerate after every batch.",
        "",
        "**Every unresolved applicable requirement appears here.** Nothing is deferred to",
        '"future work": each row carries a remediation scope naming who can close it and',
        "with what. Difficulty and time cost are never a scope — only the absence of an",
        "external system, device, account or product decision is.",
        "",
        "## Scope vocabulary",
        "",
        "| Scope | Meaning |",
        "|---|---|",
        "| `IN_REPO_RESOLVABLE` | Closable by writing code, tests or row-specific evidence in this repository. |",
        "| `RUNTIME_VERIFIABLE_NOW` | Needs the app running; an emulator in this environment suffices. |",
        "| `EXTERNAL_BLOCKER` | Needs a system, device, account or decision outside this repository. See `EXTERNAL_LAUNCH_BLOCKERS.md`. |",
        "| `PRODUCT_DECISION_REQUIRED` | Blocked on an owner decision, or on a repository rule that forbids the usual remedy. |",
        "| `TRUE_NA` | Genuinely not applicable. Already `N/A` in the audit; does not appear here. |",
        "",
        "## Totals",
        "",
        "| Metric | Count |",
        "|---|---|",
        f"| Unresolved requirements queued | {len(unresolved)} |",
    ]
    for scope in (
        "IN_REPO_RESOLVABLE",
        "RUNTIME_VERIFIABLE_NOW",
        "EXTERNAL_BLOCKER",
        "PRODUCT_DECISION_REQUIRED",
    ):
        out.append(f"| {scope} | {counts.get(scope, 0)} |")
    out += [
        "",
        "| Status | IN_REPO | RUNTIME | EXTERNAL | PRODUCT |",
        "|---|---|---|---|---|",
    ]
    for status in ("FAIL", "PARTIAL", "UNVERIFIED", "BLOCKED"):
        c = per_status[status]
        out.append(
            f"| {status} | {c.get('IN_REPO_RESOLVABLE', 0)} | "
            f"{c.get('RUNTIME_VERIFIABLE_NOW', 0)} | {c.get('EXTERNAL_BLOCKER', 0)} | "
            f"{c.get('PRODUCT_DECISION_REQUIRED', 0)} |"
        )
    out += [
        "",
        "## Queue",
        "",
        "Ordered by severity, then status, then section. A row leaves this queue only when",
        "its audit row changes status, so the queue can never claim progress the audit does",
        "not already carry.",
        "",
        "| # | ID | Sev | Status | Scope | Requirement | Concrete gap | Verification needed |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for index, row in enumerate(unresolved, 1):
        gap = row["gap"].replace("|", "/") or "-"
        remediation = row["remediation"].replace("|", "/") or "-"
        if gap == "-":
            gap = "(none recorded)"
        if remediation == "-":
            remediation = "(none recorded)"
        out.append(
            f"| {index} | `{row['id']}` | {row['severity']} | {row['status']} | "
            f"`{row['scope']}` | {row['text'][:90]} | {gap[:200]} | {remediation[:200]} |"
        )
    out.append("")

    Path(args.output).write_text("\n".join(out) + "\n", encoding="utf-8")
    print(
        "QUEUE_OK unresolved=%d %s"
        % (len(unresolved), " ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
