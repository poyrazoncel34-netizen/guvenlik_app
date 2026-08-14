#!/usr/bin/env python3
"""Design-token ADOPTION — not existence.

Section 4 asks whether each scale exists. Existence is cheap: a scale is a Dart
file. What decides whether the scale is a system is whether anything READS it.
`test/core/shadow_token_ratchet_test.dart` already states the principle in this
repository -- "a token nobody uses is worse than the convention it replaced" --
and this artifact applies the same test to the other nine scales.

The measurement falsified three rows that were recorded PASS.

  measurements.adoption   -> MP-04-008, MP-04-012, MP-04-013 (downgraded on this)
  measurements.themes     -> MP-04-015

Run:
    python3 scripts/audit_evidence/tokens.py
    python3 scripts/audit_evidence/tokens.py --negative-control
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    REPO, dart_files, emit, main_guard, read_stripped, rel, run_negative_control,
)

VERSION = "1.0.0"
COMMAND = "python3 scripts/audit_evidence/tokens.py"

SCALES = ("Spacing", "Radii", "Elevation", "Shadows", "IconSizes", "TypeScale",
          "ZLayer", "Breakpoints", "DensityTokens", "FocusIndicator", "Motion")

TOKEN_FILE = "lib/core/design_tokens.dart"
MOTION_FILE = "lib/core/motion.dart"


def _adoption(root: Path) -> dict:
    out = {s: {"references": 0, "consumerFiles": []} for s in SCALES}
    for path in dart_files(root):
        name = rel(path, root)
        if name in (TOKEN_FILE, MOTION_FILE):
            continue  # the definition is not a consumer
        src = read_stripped(path)
        for scale in SCALES:
            hits = len(re.findall(r"\b%s\.\w" % scale, src))
            if hits:
                out[scale]["references"] += hits
                out[scale]["consumerFiles"].append(name)
    for scale in SCALES:
        out[scale]["consumerFiles"] = sorted(out[scale]["consumerFiles"])
        out[scale]["consumerCount"] = len(out[scale]["consumerFiles"])
    return out


def measure(root: Path) -> list:
    """A scale with no consumer is reported. That is the whole point."""
    violations = []
    adoption = _adoption(root)
    for scale, info in sorted(adoption.items()):
        if info["consumerCount"] == 0:
            violations.append({
                "rule": "tokenScaleHasNoConsumer",
                "detail": f"{scale} is defined but read by no file outside its own "
                          f"definition; it cannot enforce anything",
            })
    return violations


def _themes(root: Path) -> dict:
    src = read_stripped(root / "lib" / "core" / "app_theme.dart")
    dark = len(re.findall(r"Brightness\.dark", src))
    light = len(re.findall(r"Brightness\.light", src))
    component_themes = sorted(set(re.findall(r"(\w+Theme(?:Data)?):", src)))
    # Which theme actually reaches MaterialApp?
    main_src = read_stripped(root / "lib" / "main.dart")
    return {
        "darkDeclarations": dark,
        "lightDeclarations": light,
        "componentThemesDeclared": component_themes,
        "componentThemeCount": len(component_themes),
        "wiredInMain": sorted(set(re.findall(r"(theme|darkTheme|themeMode):\s*([\w.]+)", main_src))),
        "themeSelectorScreen": "lib/screens/settings_page.dart",
        "themeSelectorTest": "test/screens/settings_page_contains_theme_selector_test.dart",
    }


def build(root: Path) -> dict:
    adoption = _adoption(root)
    defined = len(SCALES)
    adopted = sum(1 for v in adoption.values() if v["consumerCount"])
    return {
        "adoption": {
            "scalesDefined": defined,
            "scalesWithAtLeastOneConsumer": adopted,
            "byScale": adoption,
            "zeroConsumerScales": sorted(s for s, v in adoption.items() if not v["consumerCount"]),
            "principle": (
                "a scale that nothing reads cannot enforce consistency; it is a "
                "parallel definition sitting beside the literals it was meant to "
                "replace. test/core/shadow_token_ratchet_test.dart already asserts "
                "this for shadows (>=8 consumer files); the other scales had no "
                "equivalent bar, and three of them have none at all."
            ),
            "consequence": (
                "MP-04-008 (ZLayer), MP-04-012 (IconSizes) and MP-04-013 "
                "(DensityTokens) were once recorded PASS on existence and were "
                "downgraded to PARTIAL on this measurement, matching MP-04-004. "
                "ZLayer, Breakpoints and DensityTokens were then migrated with "
                "zero rendered change; IconSizes followed on 2026-08-15, once "
                "the scale itself was rebuilt from measured usage."
            ),
            "notDoneAndWhy": (
                "TypeScale remains unmigrated and that is deliberate: it covers "
                "329 inline fontSize sites and the honest fix is a TextTheme, "
                "which is a real refactor rather than a rename -- MP-04-004 is "
                "PARTIAL for exactly that. IconSizes is DONE, and WHY it had "
                "failed before is the useful part: the invented scale omitted "
                "18 dp (24 sites) and 22 dp (19 sites), the two most common "
                "sizes after 20, so adopting it would have moved 43 rendered "
                "icons -- a visual change CLAUDE.md rule 4 reserves to the "
                "owner. Rebuilding the scale from the census made the migration "
                "pixel-neutral: 139 of 162 sites now read a role, and the "
                "remaining 23 are one-offs enumerated in "
                "IconSizes.documentedExceptions and guarded by "
                "test/core/icon_size_migration_test.dart."
            ),
        },
        "themes": _themes(root),
        "ratchet": {
            "test": "test/core/design_token_ratchet_test.dart",
            "buildsAllowedSetFromTokenFile": True,
            "shadowTest": "test/core/shadow_token_ratchet_test.dart",
        },
    }


def _mutate(scratch: Path) -> str:
    # Remove every Radii consumer reference, which should turn a well-adopted
    # scale into a zero-consumer one.
    changed = 0
    for path in dart_files(scratch):
        if rel(path, scratch) == TOKEN_FILE:
            continue
        src = path.read_text(encoding="utf-8")
        if "Radii." in src:
            path.write_text(src.replace("Radii.", "12.0 + 0 * "), encoding="utf-8")
            changed += 1
    return f"stripped every Radii consumer ({changed} files)"


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control("tokens", _mutate, measure)
    violations = measure(REPO)
    path = emit(
        "design_tokens.json",
        verifier="scripts/audit_evidence/tokens.py",
        version=VERSION,
        command=COMMAND,
        surfaces=[TOKEN_FILE, MOTION_FILE, "lib/core/app_theme.dart", "lib/main.dart",
                  f"lib/**/*.dart ({len(dart_files(REPO))} files)"],
        measurements=build(REPO),
        violations=violations,
        exclusions=[
            {"what": "the token file and motion.dart themselves",
             "why": "a definition referencing its own rungs is not adoption; counting "
                    "it is how a zero-consumer scale reports as adopted"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "strip every Radii consumer reference",
            "expected": "Radii joins the zero-consumer list",
        }},
    )
    print(f"TOKENS_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
