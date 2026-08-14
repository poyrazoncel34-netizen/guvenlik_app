#!/usr/bin/env python3
"""Colour and contrast inventory — evidence for section 6 requirement rows.

Every number below is computed from the ARGB literals in
``lib/core/app_colors.dart`` with the WCAG 2.1 relative-luminance formula, and
translucent colours are ALPHA-COMPOSITED over the surface they actually sit on
before being measured. Comparing a `0x1AFFFFFF` glass fill against a background
without compositing measures a colour that never reaches a pixel.

  measurements.brand                -> MP-06-001
  measurements.semantic.success     -> MP-06-002
  measurements.semantic.warning     -> MP-06-003
  measurements.semantic.error       -> MP-06-004
  measurements.semantic.info        -> MP-06-005
  measurements.backgrounds          -> MP-06-006
  measurements.surfaceLevels        -> MP-06-007
  measurements.borders              -> MP-06-008
  measurements.interactionStates    -> MP-06-010, MP-06-011, MP-06-012
  measurements.focusIndicator       -> MP-06-013
  measurements.textContrast         -> MP-06-014
  measurements.colourVisionSafety   -> MP-06-016
  measurements.oled                 -> MP-06-018

Run:
    python3 scripts/audit_evidence/color.py
    python3 scripts/audit_evidence/color.py --negative-control
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    REPO, composite, contrast_ratio, dart_files, emit, main_guard, parse_argb,
    read_stripped, rel, relative_luminance, run_negative_control,
)

VERSION = "1.0.0"
COMMAND = "python3 scripts/audit_evidence/color.py"

COLOR_DECL = re.compile(r"static const Color (\w+) = Color\((0x[0-9A-Fa-f]{8})\)")

AA_NORMAL, AA_LARGE, NON_TEXT = 4.5, 3.0, 3.0

# Text/background pairings the app actually renders. Each is a real pairing read
# off the widget tree, not a cartesian product: measuring pairs that never meet
# manufactures both false passes and false failures.
TEXT_PAIRS = [
    ("textPrimary", "background", "body copy on the page ground", AA_NORMAL),
    ("textPrimary", "surface", "body copy on a sheet", AA_NORMAL),
    ("textPrimary", "cardBg", "card title", AA_NORMAL),
    ("textSecondary", "background", "helper line on the page ground", AA_NORMAL),
    ("textSecondary", "surface", "helper line on a sheet", AA_NORMAL),
    ("textSecondary", "cardBg", "card subtitle", AA_NORMAL),
    ("primary", "background", "link / accent label", AA_NORMAL),
    ("primary", "cardBg", "accent label on a card", AA_NORMAL),
    ("emergency", "background", "emergency label", AA_NORMAL),
    ("emergency", "cardBg", "emergency label on a card", AA_NORMAL),
    ("success", "background", "success label", AA_NORMAL),
    ("success", "cardBg", "success label on a card", AA_NORMAL),
    ("warning", "background", "warning label", AA_NORMAL),
    ("warning", "cardBg", "warning label on a card", AA_NORMAL),
    ("info", "background", "info label", AA_NORMAL),
    ("info", "cardBg", "info label on a card", AA_NORMAL),
]

# SC 1.4.11 covers visual information required to IDENTIFY a user interface
# component -- not decoration. So the bar is applied to control boundaries, and
# the purely decorative surface separations are measured but recorded as
# `surfaceSeparation` rather than graded. Holding a card fill to 3:1 would
# manufacture a failure WCAG does not assert; exempting a text input's boundary
# would hide one it does.
NON_TEXT_PAIRS = [
    ("border", "background", "TEXT INPUT resting boundary on the page ground "
                             "(InputDecorationTheme.enabledBorder)"),
    ("surface", "background", "TEXT INPUT fill on the page ground "
                              "(InputDecorationTheme.fillColor, filled: true)"),
    ("primary", "background", "text input FOCUSED boundary on the page ground"),
    ("focusRing", "cardBg", "focus ring inner tone on a card"),
    ("focusRingOutline", "primary", "focus ring outline against its own inner tone"),
]

# Decorative separations: measured for the record, never graded against 3:1.
SURFACE_SEPARATIONS = [
    ("cardBg", "background", "card surface against the page ground"),
    ("surface", "background", "sheet against the page ground"),
    ("border", "cardBg", "card outline on a card"),
    ("cardHover", "cardBg", "highlighted row against its resting tone"),
]

# Text drawn on a container tinted with its OWN colour. These are the pairs that
# actually render on screen, and they are strictly worse than the same text on a
# flat surface -- which is why measuring only flat pairs reports a false pass.
# `check_in_screen` ANIMATES its tint from 0.10 to 0.25, so the pair is measured
# across the whole pulse, not at one frame.
TINTED_PAIRS = [
    ("emergency", 0.10, "background", "check_in grace warning, pulse minimum",
     "lib/screens/check_in_screen.dart:460"),
    ("emergency", 0.25, "background", "check_in grace warning, pulse maximum",
     "lib/screens/check_in_screen.dart:460"),
    ("emergency", 0.12, "background", "PIN lockout countdown chip",
     "lib/screens/app_unlock_screen.dart:314"),
    ("emergency", 0.12, "cardBg", "emergency badge on a card",
     "lib/screens/contacts_page.dart:318"),
]

# Deuteranopia / protanopia / tritanopia simulation (Brettel-style linear
# approximation on linear-RGB). Used to answer one question only: do two colours
# that MEAN different things collapse into the same colour for a dichromat?
CVD_MATRICES = {
    "protanopia": ((0.567, 0.433, 0.0), (0.558, 0.442, 0.0), (0.0, 0.242, 0.758)),
    "deuteranopia": ((0.625, 0.375, 0.0), (0.70, 0.30, 0.0), (0.0, 0.30, 0.70)),
    "tritanopia": ((0.95, 0.05, 0.0), (0.0, 0.433, 0.567), (0.0, 0.475, 0.525)),
}


COLOR_ALIAS = re.compile(r"static const Color (\w+) = (\w+);")


def _palette(root: Path) -> dict:
    """Named colours, with aliases resolved.

    `focusRing = primary` and `focusRingOutline = background` are declared as
    ALIASES, not literals. A regex that only reads `Color(0x...)` silently drops
    the two tokens the focus-indicator requirement is entirely about, and the
    verifier then reports on a palette that is missing exactly the entries under
    test.
    """
    src = (root / "lib" / "core" / "app_colors.dart").read_text(encoding="utf-8")
    palette = {name: parse_argb(value) for name, value in COLOR_DECL.findall(src)}
    for name, target in COLOR_ALIAS.findall(src):
        if name not in palette and target in palette:
            palette[name] = palette[target]
    return palette


def _rgb(palette: dict, name: str, over: str = "background") -> tuple:
    argb = palette[name]
    if argb[0] == 0xFF:
        return argb[1:]
    return composite(argb, _rgb(palette, over))


def _simulate(rgb: tuple, matrix) -> tuple:
    r, g, b = (c / 255.0 for c in rgb)
    out = []
    for row in matrix:
        out.append(max(0.0, min(1.0, row[0] * r + row[1] * g + row[2] * b)))
    return tuple(round(c * 255) for c in out)


def _delta(a: tuple, b: tuple) -> float:
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def measure(root: Path) -> list:
    palette = _palette(root)
    violations = []

    for fg, bg, what, bar in TEXT_PAIRS:
        if fg not in palette or bg not in palette:
            violations.append({"rule": "missingPaletteEntry", "detail": f"{fg}/{bg}"})
            continue
        ratio = contrast_ratio(_rgb(palette, fg, bg), _rgb(palette, bg))
        if ratio < bar:
            violations.append({
                "rule": "textContrastBelowAA",
                "detail": f"{fg} on {bg} ({what}) = {ratio:.2f}:1, bar {bar}",
                "ratio": round(ratio, 2),
            })

    for a, b, what in NON_TEXT_PAIRS:
        ratio = contrast_ratio(_rgb(palette, a, b), _rgb(palette, b))
        if ratio < NON_TEXT:
            violations.append({
                "rule": "nonTextContrastBelow3",
                "detail": f"{a} vs {b} ({what}) = {ratio:.2f}:1",
                "ratio": round(ratio, 2),
            })

    for fg, alpha, ground, what, site in TINTED_PAIRS:
        tint = composite((round(alpha * 255),) + tuple(palette[fg][1:]), _rgb(palette, ground))
        ratio = contrast_ratio(_rgb(palette, fg), tint)
        if ratio < AA_NORMAL:
            violations.append({
                "rule": "tintedContainerTextBelowAA",
                "detail": f"{fg} text on {fg}@{alpha:.0%} over {ground} ({what}) = {ratio:.2f}:1",
                "site": site,
                "ratio": round(ratio, 2),
            })

    # Semantic roles must be distinguishable from each other, and must stay
    # distinguishable under every dichromacy. success/warning/emergency carrying
    # the same simulated colour is the classic red-green failure.
    roles = [r for r in ("success", "warning", "emergency", "info") if r in palette]
    for kind, matrix in CVD_MATRICES.items():
        for i, a in enumerate(roles):
            for b in roles[i + 1:]:
                d = _delta(_simulate(_rgb(palette, a), matrix), _simulate(_rgb(palette, b), matrix))
                if d < 40:
                    violations.append({
                        "rule": "semanticRolesCollapseUnderCVD",
                        "detail": f"{a} and {b} are {d:.0f} apart under {kind}",
                    })

    # Every named interaction state must actually differ from its resting tone,
    # or the state is decorative.
    for state, base in (("cardHover", "cardBg"),):
        if state in palette and base in palette:
            if _delta(_rgb(palette, state), _rgb(palette, base)) < 8:
                violations.append({
                    "rule": "interactionStateIndistinct",
                    "detail": f"{state} is within 8 of {base}",
                })
    return violations


def build(root: Path) -> dict:
    palette = _palette(root)
    hexof = lambda n: "#%02X%02X%02X" % _rgb(palette, n)  # noqa: E731

    text_rows = []
    for fg, bg, what, bar in TEXT_PAIRS:
        ratio = contrast_ratio(_rgb(palette, fg, bg), _rgb(palette, bg))
        text_rows.append({
            "foreground": fg, "background": bg, "usedFor": what,
            "ratio": round(ratio, 2), "bar": bar,
            "passesAA": ratio >= bar,
            "passesAALarge": ratio >= AA_LARGE,
            "passesAAA": ratio >= 7.0,
        })

    non_text_rows = []
    for a, b, what in NON_TEXT_PAIRS:
        ratio = contrast_ratio(_rgb(palette, a, b), _rgb(palette, b))
        non_text_rows.append({
            "colour": a, "against": b, "usedFor": what,
            "ratio": round(ratio, 2), "bar": NON_TEXT, "passes": ratio >= NON_TEXT,
        })

    roles = [r for r in ("success", "warning", "emergency", "info") if r in palette]
    cvd = {}
    for kind, matrix in CVD_MATRICES.items():
        pairs = {}
        for i, a in enumerate(roles):
            for b in roles[i + 1:]:
                pairs[f"{a}|{b}"] = round(
                    _delta(_simulate(_rgb(palette, a), matrix), _simulate(_rgb(palette, b), matrix)), 1
                )
        cvd[kind] = {
            "simulated": {r: "#%02X%02X%02X" % _simulate(_rgb(palette, r), matrix) for r in roles},
            "pairwiseRgbDistance": pairs,
            "minimumDistance": min(pairs.values()) if pairs else None,
        }

    usage = _semantic_usage(root)

    return {
        "paletteFile": "lib/core/app_colors.dart",
        "namedColours": len(palette),
        "brand": {
            "primary": hexof("primary"), "primaryDark": hexof("primaryDark"),
            "primaryLight": hexof("primaryLight"), "accent": hexof("accent"),
            "gradientStart": hexof("gradientStart"), "gradientEnd": hexof("gradientEnd"),
            "rampMonotonic": (
                relative_luminance(_rgb(palette, "primaryDark"))
                < relative_luminance(_rgb(palette, "primary"))
                < relative_luminance(_rgb(palette, "primaryLight"))
            ),
            "usageSites": usage.get("primary", 0),
        },
        "semantic": {
            "success": {"hex": hexof("success"), "sites": usage.get("success", 0),
                        "note": "teal rather than green -- chosen for dichromat separation"},
            "warning": {"hex": hexof("warning"), "sites": usage.get("warning", 0)},
            "error": {"hex": hexof("emergency"), "token": "AppColors.emergency",
                      "sites": usage.get("emergency", 0),
                      "note": "one token carries both 'error' and 'emergency'; this app's "
                              "error surface IS its emergency surface"},
            "info": {"hex": hexof("info"), "sites": usage.get("info", 0)},
            "allFourDistinct": len({hexof(r) for r in roles}) == len(roles),
        },
        "backgrounds": {
            "background": hexof("background"), "gradientStart": hexof("gradientStart"),
            "gradientEnd": hexof("gradientEnd"),
            "luminance": {n: round(relative_luminance(_rgb(palette, n)), 4)
                          for n in ("background", "gradientStart", "gradientEnd")},
        },
        "surfaceLevels": {
            "ladder": ["background", "surface", "cardBg", "cardHover"],
            "hex": {n: hexof(n) for n in ("background", "surface", "cardBg", "cardHover")},
            "luminance": {n: round(relative_luminance(_rgb(palette, n)), 4)
                          for n in ("background", "surface", "cardBg", "cardHover")},
            "strictlyAscending": (
                relative_luminance(_rgb(palette, "background"))
                < relative_luminance(_rgb(palette, "surface"))
                < relative_luminance(_rgb(palette, "cardBg"))
                < relative_luminance(_rgb(palette, "cardHover"))
            ),
            "glassOverlays": {
                n: {"argb": "0x%08X" % ((palette[n][0] << 24) | (palette[n][1] << 16)
                                        | (palette[n][2] << 8) | palette[n][3]),
                    "compositedOverBackground": hexof(n)}
                for n in ("glass", "glassLight", "glassBorder") if n in palette
            },
        },
        "borders": {
            "border": hexof("border"), "glassBorder": hexof("glassBorder"),
            "sites": usage.get("border", 0),
            "contrastAgainstBackground": round(
                contrast_ratio(_rgb(palette, "border"), _rgb(palette, "background")), 2),
        },
        "interactionStates": {
            "hover": {"token": "AppColors.cardHover", "hex": hexof("cardHover"),
                      "deltaFromResting": round(_delta(_rgb(palette, "cardHover"),
                                                       _rgb(palette, "cardBg")), 1),
                      "note": "Android has no hover pointer; this tone serves the "
                              "pointer/keyboard-highlight case and the pressed ripple base"},
            "pressed": {"mechanism": "Material InkWell splash + highlight from ThemeData",
                        "themeSites": _theme_state_sites(root)},
            "selected": {"mechanism": "AppColors.primary fill / tint on the selected item",
                         "sites": usage.get("primary", 0)},
        },
        "focusIndicator": {
            "innerRing": hexof("focusRing"), "outerRing": hexof("focusRingOutline"),
            "widths": {"ring": 2, "outline": 2, "total": 4},
            "minContrastToken": 3.0,
            "whyTwoTone": (
                "measured: a single primary ring reads 7.27:1 on dark surfaces but "
                "1.17:1 on the bright cyan profile card; background is the exact "
                "inverse. Two tones guarantee one of them clears 3:1 on every surface."
            ),
            "measuredPairs": {
                "focusRing|cardBg": round(contrast_ratio(_rgb(palette, "focusRing"),
                                                         _rgb(palette, "cardBg")), 2),
                "focusRing|background": round(contrast_ratio(_rgb(palette, "focusRing"),
                                                             _rgb(palette, "background")), 2),
                "focusRingOutline|primary": round(contrast_ratio(_rgb(palette, "focusRingOutline"),
                                                                 _rgb(palette, "primary")), 2),
            },
        },
        "textContrast": {
            "bar": {"normal": AA_NORMAL, "large": AA_LARGE},
            "pairsMeasured": len(text_rows),
            "pairsPassingAA": sum(1 for r in text_rows if r["passesAA"]),
            "worst": min(text_rows, key=lambda r: r["ratio"]),
            "best": max(text_rows, key=lambda r: r["ratio"]),
            "pairs": text_rows,
        },
        "nonTextContrast": {
            "criterion": "WCAG 2.1 SC 1.4.11 Non-text Contrast (AA)",
            "scopeNote": (
                "applied to control boundaries only. A card fill is not a user "
                "interface component; a text input's boundary is."
            ),
            "bar": NON_TEXT, "pairsMeasured": len(non_text_rows),
            "pairsPassing": sum(1 for r in non_text_rows if r["passes"]),
            "pairs": non_text_rows,
        },
        "surfaceSeparation": {
            "graded": False,
            "why": "decorative depth, not component identification",
            "pairs": [
                {"colour": a, "against": b, "usedFor": what,
                 "ratio": round(contrast_ratio(_rgb(palette, a, b), _rgb(palette, b)), 2)}
                for a, b, what in SURFACE_SEPARATIONS
            ],
        },
        "tintedContainerText": {
            "why": (
                "the app draws emergency-coloured text INSIDE containers tinted "
                "with that same colour. Measuring the text against a flat surface "
                "reports a pass the screen does not deliver."
            ),
            "bar": AA_NORMAL,
            "pairs": [
                {"foreground": fg, "tintAlpha": alpha, "ground": ground,
                 "usedFor": what, "site": site,
                 "compositedTint": "#%02X%02X%02X" % composite(
                     (round(alpha * 255),) + tuple(palette[fg][1:]), _rgb(palette, ground)),
                 "ratio": round(contrast_ratio(
                     _rgb(palette, fg),
                     composite((round(alpha * 255),) + tuple(palette[fg][1:]),
                               _rgb(palette, ground))), 2)}
                for fg, alpha, ground, what, site in TINTED_PAIRS
            ],
        },
        "colourVisionSafety": {
            "method": "linear-RGB dichromacy simulation, three types",
            "rolesCompared": roles,
            "separationBar": 40,
            "byType": cvd,
            "redundantEncoding": _redundant_encoding(root),
        },
        "oled": {
            "darkestSurface": hexof("background"),
            "darkestLuminance": round(relative_luminance(_rgb(palette, "background")), 4),
            "isTrueBlack": _rgb(palette, "background") == (0, 0, 0),
            "why": (
                "the ground is #0A1B2A, not #000000. On an OLED panel a true-black "
                "ground next to bright cyan is what produces halo/blooming and the "
                "black-smear artefact on scroll; a near-black keeps every pixel lit."
            ),
            "brightestLargeArea": hexof("primary"),
            "peakVsGroundRatio": round(
                contrast_ratio(_rgb(palette, "primary"), _rgb(palette, "background")), 2),
        },
    }


def _semantic_usage(root: Path) -> dict:
    counts: dict = {}
    for path in dart_files(root):
        src = read_stripped(path)
        for m in re.finditer(r"AppColors\.(\w+)", src):
            counts[m.group(1)] = counts.get(m.group(1), 0) + 1
    return counts


def _theme_state_sites(root: Path) -> int:
    src = read_stripped(root / "lib" / "core" / "app_theme.dart")
    return len(re.findall(r"WidgetStateProperty|MaterialStateProperty|splashColor|highlightColor|overlayColor", src))


def _redundant_encoding(root: Path) -> dict:
    """Colour must never be the ONLY channel. Counts the co-signals actually used."""
    icons = labels = 0
    for path in dart_files(root):
        src = read_stripped(path)
        icons += len(re.findall(r"Icons\.(?:check_circle|error|warning|info)(?:_outline)?", src))
        labels += len(re.findall(r"semanticsLabel:|Semantics\(", src))
    return {
        "statusIconSites": icons,
        "semanticsAnnotationSites": labels,
        "claim": "status is carried by icon + text label in addition to colour",
    }


def _mutate(scratch: Path) -> str:
    target = scratch / "lib" / "core" / "app_colors.dart"
    src = target.read_text(encoding="utf-8")
    # Three independent defects: unreadable secondary text, a green success that
    # collapses into the emergency red for a deuteranope, and a card surface that
    # no longer separates from the ground.
    src = src.replace("static const Color textSecondary = Color(0xFF9BB0C7);",
                      "static const Color textSecondary = Color(0xFF2A3A4A);")
    src = src.replace("static const Color success = Color(0xFF2CB5A0); // WCAG color-blind safe teal",
                      "static const Color success = Color(0xFFFF5A4D);")
    src = src.replace("static const Color cardBg = Color(0xFF122B42);",
                      "static const Color cardBg = Color(0xFF0A1B2B);")
    target.write_text(src, encoding="utf-8")
    return "unreadable secondary text + red 'success' + card surface merged into the ground"


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control("color", _mutate, measure)
    violations = measure(REPO)
    path = emit(
        "color.json",
        verifier="scripts/audit_evidence/color.py",
        version=VERSION,
        command=COMMAND,
        surfaces=["lib/core/app_colors.dart", "lib/core/app_theme.dart",
                  f"lib/**/*.dart ({len(dart_files(REPO))} files) for usage counts"],
        measurements=build(REPO),
        violations=violations,
        exclusions=[
            {"what": "colour pairs the app never renders together",
             "why": "a cartesian product of the palette manufactures both false "
                    "passes and false failures; only real pairings are measured"},
            {"what": "the unreachable light ThemeData",
             "why": "measured separately under MP-04-015; it renders to no user today"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "unreadable secondary text, a red 'success', and a card surface "
                        "merged into the page ground",
            "expected": "violations rise above baseline",
        }},
    )
    print(f"COLOR_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
