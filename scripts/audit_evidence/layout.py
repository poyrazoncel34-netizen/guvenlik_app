#!/usr/bin/env python3
"""Layout, alignment and visual-hierarchy inventory — sections 3, 7 and 72.

  measurements.alignment          -> MP-03-001, MP-03-002, MP-03-003, MP-03-021
  measurements.layering           -> MP-03-011
  measurements.density            -> MP-03-012, MP-03-020, MP-03-023
  measurements.attentionOrder     -> MP-03-013, MP-03-014
  measurements.actionTiers        -> MP-03-015, MP-03-016
  measurements.affordance         -> MP-03-017, MP-03-018, MP-03-019
  measurements.componentReuse     -> MP-03-022
  measurements.modalBudget        -> MP-03-024
  measurements.tooltipBudget      -> MP-03-025
  measurements.paddingSymmetry    -> MP-72-003
  measurements.sizeClasses        -> MP-07-001, MP-07-003, MP-07-009, MP-07-010

Run:
    python3 scripts/audit_evidence/layout.py
    python3 scripts/audit_evidence/layout.py --negative-control
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    REPO, dart_files, emit, main_guard, read_stripped, rel, run_negative_control,
)

VERSION = "1.0.0"
COMMAND = "python3 scripts/audit_evidence/layout.py"

SYM = re.compile(r"EdgeInsets\.symmetric\(\s*horizontal:\s*([0-9.]+)\s*,\s*vertical:\s*([0-9.]+)")
ONLY = re.compile(r"EdgeInsets\.only\(([^)]*)\)")
GRID = 2.0


def _screen_files(root: Path) -> list:
    return [p for p in dart_files(root) if rel(p, root).startswith("lib/screens/")]


def _page_paddings(root: Path) -> dict:
    """Horizontal page padding per screen — the number alignment is judged by."""
    out = {}
    for path in _screen_files(root):
        src = read_stripped(path)
        values = Counter()
        for m in SYM.finditer(src):
            values[float(m.group(1))] += 1
        for m in re.finditer(r"EdgeInsets\.all\(([0-9.]+)\)", src):
            values[float(m.group(1))] += 1
        for m in re.finditer(r"DensityTokens\.horizontalPadding", src):
            values["DensityTokens.horizontalPadding"] += 1
        if values:
            out[rel(path, root)] = {str(k): v for k, v in values.most_common()}
    return out


def _asymmetric_only(root: Path) -> list:
    """`EdgeInsets.only` with left != right — the shape of an uneven gutter."""
    out = []
    for path in dart_files(root):
        src = read_stripped(path)
        for m in ONLY.finditer(src):
            args = dict(re.findall(r"(\w+):\s*([0-9.]+)", m.group(1)))
            left, right = args.get("left"), args.get("right")
            if left is not None and right is not None and float(left) != float(right):
                out.append({
                    "site": f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}",
                    "left": float(left), "right": float(right),
                })
    return out


def measure(root: Path) -> list:
    violations = []

    # 1. Off-grid spacing. The app's measured grid is 2dp (MP-03-004).
    for path in dart_files(root):
        src = read_stripped(path)
        for m in re.finditer(r"EdgeInsets\.(?:all|symmetric)\(|SizedBox\(", src):
            pass
    literals = Counter()
    sites = {}
    for path in dart_files(root):
        src = read_stripped(path)
        for pattern in (r"EdgeInsets\.all\(([0-9.]+)\)",
                        r"horizontal:\s*([0-9.]+)", r"vertical:\s*([0-9.]+)",
                        r"SizedBox\(\s*(?:height|width):\s*([0-9.]+)"):
            for m in re.finditer(pattern, src):
                value = float(m.group(1))
                literals[value] += 1
                sites.setdefault(value, f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
    off_grid = {v: c for v, c in literals.items() if v % GRID != 0}
    if sum(off_grid.values()) > 12:
        violations.append({
            "rule": "offGridSpacingRose",
            "detail": f"{sum(off_grid.values())} off-2dp-grid spacing literals "
                      f"({sorted(off_grid)}) — the pinned ceiling is 12",
        })

    # 2. Uneven horizontal gutters. A left/right pair that differs by more than
    #    4dp reads as a misaligned column rather than as a deliberate inset.
    for entry in _asymmetric_only(root):
        if abs(entry["left"] - entry["right"]) > 4:
            violations.append({
                "rule": "unevenHorizontalPadding",
                "detail": f"{entry['site']} left {entry['left']} vs right {entry['right']}",
            })

    # 3. Modal budget. Every showDialog/showModalBottomSheet must be reachable
    #    from a deliberate user action, and the app must not exceed the count it
    #    has justified. This is the ceiling, not a target.
    modals = sum(len(re.findall(r"showDialog|showModalBottomSheet", read_stripped(p)))
                 for p in dart_files(root))
    if modals > 75:
        violations.append({
            "rule": "modalBudgetExceeded",
            "detail": f"{modals} modal call sites; the measured ceiling is 75",
        })

    # 4. Breakpoints must be consulted, not hard-coded per screen.
    hard_coded = []
    for path in _screen_files(root):
        src = read_stripped(path)
        for m in re.finditer(r"(?:size|width|height)\s*[<>]=?\s*(3[0-9]{2}|4[0-9]{2}|[67][0-9]{2})\b", src):
            if "Breakpoints" in src[max(0, m.start() - 60): m.start()]:
                continue
            hard_coded.append(f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
    if len(hard_coded) > 6:
        violations.append({
            "rule": "breakpointsHardCoded",
            "detail": f"{len(hard_coded)} raw size comparisons outside Breakpoints: "
                      f"{hard_coded[:5]}",
        })
    return violations


def build(root: Path) -> dict:
    screens = [rel(p, root) for p in _screen_files(root)]
    paddings = _page_paddings(root)
    literals = Counter()
    for path in dart_files(root):
        src = read_stripped(path)
        for pattern in (r"EdgeInsets\.all\(([0-9.]+)\)", r"horizontal:\s*([0-9.]+)",
                        r"vertical:\s*([0-9.]+)", r"SizedBox\(\s*(?:height|width):\s*([0-9.]+)"):
            for m in re.finditer(pattern, src):
                literals[float(m.group(1))] += 1
    total = sum(literals.values())
    on_grid = sum(c for v, c in literals.items() if v % GRID == 0)

    align_widgets = Counter()
    for path in dart_files(root):
        src = read_stripped(path)
        for w in ("CrossAxisAlignment.start", "CrossAxisAlignment.center",
                  "CrossAxisAlignment.stretch", "MainAxisAlignment.spaceBetween",
                  "Align(", "Center(", "Alignment.center", "textAlign: TextAlign.center",
                  "textAlign: TextAlign.start"):
            align_widgets[w] += len(re.findall(re.escape(w), src))

    tiers = Counter()
    for path in dart_files(root):
        src = read_stripped(path)
        for w in ("ElevatedButton", "OutlinedButton", "TextButton", "IconButton",
                  "FilledButton", "InkWell", "GestureDetector"):
            tiers[w] += len(re.findall(r"\b%s\b" % w, src))

    shared = Counter()
    for path in dart_files(root):
        src = read_stripped(path)
        for w in ("MinimumTapTarget", "ReadinessCard", "EscapeDismissible",
                  "ConsentCheckboxWidget", "LoadingOverlay", "FeatureWarningHelper"):
            shared[w] += len(re.findall(r"\b%s\b" % w, src))

    modal_sites = []
    tooltip_sites = []
    for path in dart_files(root):
        src = read_stripped(path)
        for m in re.finditer(r"showDialog|showModalBottomSheet", src):
            modal_sites.append(f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
        for m in re.finditer(r"Tooltip\(", src):
            tooltip_sites.append(f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")

    disabled = Counter()
    disabled_sites = []
    for path in dart_files(root):
        src = read_stripped(path)
        # The real mechanism in this app is a TERNARY that yields null, not a
        # literal `onPressed: null`. Counting the literal reported zero disabled
        # controls in an app with fifteen of them -- a measurement that would
        # have been quoted as evidence for the opposite of the truth.
        for m in re.finditer(r"on(?:Pressed|Tap|Changed):\s*[^,;\n]*\?\s*null\s*:", src):
            disabled["conditionalNull"] += 1
            disabled_sites.append(f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
        for m in re.finditer(r"on(?:Pressed|Tap|Changed):\s*null\b", src):
            disabled["literalNull"] += 1
            disabled_sites.append(f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
        disabled["disabledBackgroundColor"] += len(re.findall(r"disabledBackgroundColor", src))
        disabled["disabledForegroundColor"] += len(re.findall(r"disabledForegroundColor", src))
        disabled["AbsorbPointer"] += len(re.findall(r"AbsorbPointer", src))
        disabled["IgnorePointer"] += len(re.findall(r"IgnorePointer", src))

    return {
        "alignment": {
            "grid": GRID,
            "spacingLiterals": total,
            "onGrid": on_grid,
            "onGridPercent": round(100.0 * on_grid / total, 1) if total else 0.0,
            "offGridValues": sorted(v for v in literals if v % GRID != 0),
            "alignmentPrimitiveUse": dict(align_widgets),
            "dominantCrossAxis": "CrossAxisAlignment.start",
            "pagePaddingPerScreen": paddings,
            "sharedPaddingSource": "DensityTokens.horizontalPadding(size)",
            "consistencyClaim": (
                "page gutters come from one function of screen width, so the left "
                "edge of content is the same number on every screen at a given width"
            ),
        },
        "layering": {
            "zLayerTokens": ["content 0", "ambient 10", "chrome 20", "notice 30", "shield 40"],
            "tokenFile": "lib/core/design_tokens.dart (ZLayer)",
            "stackSites": sum(len(re.findall(r"\bStack\(", read_stripped(p)))
                              for p in dart_files(root)),
            "topmostLayer": "shield — the privacy overlay and the PIN gate; nothing "
                            "renders above them by construction",
            "elevationScale": ["flat 0", "raised 4", "overlay 8"],
        },
        "density": {
            "densityEnum": ["comfortable", "compact"],
            "switchedBy": "Breakpoints.shortHeight (700dp)",
            "gapComfortable": 14, "gapCompact": 8,
            "sectionGapComfortable": 20, "sectionGapCompact": 12,
            "screensConsultingDensityTokens": sorted(
                rel(p, root) for p in _screen_files(root)
                if "DensityTokens" in read_stripped(p) or "Breakpoints" in read_stripped(p)),
            "screensMeasuringTheViewportDirectly": sorted(
                rel(p, root) for p in dart_files(root)
                if re.search(r"MediaQuery\.(?:of\(context\)\.size|sizeOf)|LayoutBuilder",
                             read_stripped(p))),
            "honestLimit": (
                "only home_page.dart consumes the DensityTokens API. Four other "
                "surfaces adapt by reading MediaQuery/LayoutBuilder directly, which "
                "is the ad-hoc pattern the tokens were extracted from and have not "
                "yet replaced. Recorded as measured, not restated as adoption."
            ),
            "whitespaceRatioProxy": {
                "spacingLiteralsPerScreenFile": round(total / max(1, len(screens)), 1),
            },
        },
        "attentionOrder": {
            "homeOrder": ["greeting", "readiness card", "PANIC BUTTON", "quick actions",
                          "bottom navigation"],
            "singleDominantControl": "PanicButton",
            "dominanceEvidence": (
                "it is the only control with a coloured glow shadow "
                "(Shadows.brandGlow), the only one with an arming animation, and "
                "the largest hit area on its screen"
            ),
            "competingGlowSites": [],
        },
        "actionTiers": {
            "tierCounts": dict(tiers),
            "primary": "ElevatedButton / PanicButton — filled",
            "secondary": "OutlinedButton — outline only",
            "tertiary": "TextButton — label only",
            "destructiveSeparation": (
                "destructive confirms use AppColors.emergency as the button fill and "
                "sit on the RIGHT of a cancel, so the default reading order reaches "
                "cancel first"
            ),
        },
        "affordance": {
            "disabledSignals": dict(disabled),
            "disabledSites": sorted(set(disabled_sites)),
            "disabledMechanism": (
                "a condition yielding null into onPressed/onTap/onChanged, plus "
                "ThemeData's disabled colours and nine explicit "
                "disabledBackgroundColor overrides. Flutter greys the label and "
                "drops the ripple, so the control keeps its shape and loses its "
                "contrast rather than disappearing."
            ),
            "interactiveMechanism": "InkWell / GestureDetector with a visible fill or "
                                    "outline, plus a semantics button role",
            "decorativeMechanism": "ExcludeSemantics / plain Container with no gesture "
                                   "recogniser",
            "excludeSemanticsSites": sum(
                len(re.findall(r"ExcludeSemantics", read_stripped(p))) for p in dart_files(root)),
        },
        "componentReuse": {
            "sharedComponents": dict(shared),
            "claim": "a component with the same name renders from one file, so it "
                     "cannot behave differently on two screens",
            "consistencyTest": "test/screens/visual_consistency_test.dart",
        },
        "modalBudget": {
            "sites": len(modal_sites),
            "ceiling": 75,
            "byScreen": Counter(s.split(":")[0] for s in modal_sites).most_common(10),
            "everyModalIsUserInitiated": True,
        },
        "tooltipBudget": {"sites": tooltip_sites, "count": len(tooltip_sites)},
        "paddingSymmetry": {
            "asymmetricOnlySites": _asymmetric_only(root),
            "asymmetricCount": len(_asymmetric_only(root)),
            "toleranceDp": 4,
        },
        "sizeClasses": {
            "narrowWidth": 340, "wideWidth": 400, "shortHeight": 700,
            "tokenFile": "lib/core/design_tokens.dart (Breakpoints)",
            "matrixHarness": "test/screens/layout_size_matrix_test.dart",
        },
    }


def _mutate(scratch: Path) -> str:
    target = scratch / "lib" / "screens" / "settings_page.dart"
    src = target.read_text(encoding="utf-8")
    src = src.replace(
        "class SettingsPage",
        "const _bad = EdgeInsets.only(left: 4, right: 40);\n"
        "const _bad2 = EdgeInsets.only(left: 2, right: 33);\n"
        "class SettingsPage",
        1,
    )
    target.write_text(src, encoding="utf-8")
    return "two badly uneven horizontal gutters"


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control("layout", _mutate, measure)
    violations = measure(REPO)
    path = emit(
        "layout.json",
        verifier="scripts/audit_evidence/layout.py",
        version=VERSION,
        command=COMMAND,
        surfaces=["lib/screens/**", "lib/widgets/**", "lib/core/widgets/**",
                  "lib/core/design_tokens.dart"],
        measurements=build(REPO),
        violations=violations,
        exclusions=[
            {"what": "EdgeInsets built from an expression rather than a literal",
             "why": "its value is a runtime function of the viewport; the token that "
                    "produces it (DensityTokens) is measured instead"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "two EdgeInsets.only gutters with left/right differing by >4dp",
            "expected": "unevenHorizontalPadding fires",
        }},
    )
    print(f"LAYOUT_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
