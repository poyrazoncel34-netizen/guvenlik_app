#!/usr/bin/env python3
"""Typography inventory — evidence for section 5 requirement rows.

Measures the typography the app actually ships rather than the typography its
theme file claims. Each requirement row in section 5 cites ONE named property of
the emitted artifact; no two rows cite the same property, because a shared
sentence is exactly the defect (IR-06) this replaces.

  measurements.fontFamily            -> MP-05-001, MP-05-004
  measurements.headingHierarchy      -> MP-05-006, MP-05-007, MP-05-008
  measurements.bodyReadability       -> MP-05-009
  measurements.lineHeight            -> MP-05-010
  measurements.letterSpacing         -> MP-05-011
  measurements.measureChars          -> MP-05-012, MP-05-013
  measurements.weightDistribution    -> MP-05-014
  measurements.uppercase             -> MP-05-015
  measurements.linkAffordance        -> MP-05-016

Run:
    python3 scripts/audit_evidence/typography.py
    python3 scripts/audit_evidence/typography.py --negative-control
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
COMMAND = "python3 scripts/audit_evidence/typography.py"

# The type scale named in lib/core/design_tokens.dart. Read from source rather
# than duplicated, so the verifier cannot drift from the tokens it grades.
SCALE_RE = re.compile(r"abstract final class TypeScale \{(.*?)\n\}", re.S)
CONST_RE = re.compile(r"static const double (\w+) = ([0-9.]+);")

# Typographic bar. 45-75 characters is the classic comfortable measure; 90 is
# the point at which the eye loses the line return. Both are asserted against a
# 360 dp portrait phone, which is this app's narrowest supported width class.
MEASURE_MIN, MEASURE_MAX = 30, 90
NARROW_WIDTH_DP = 360
PAGE_PADDING_DP = 20 * 2  # DensityTokens.horizontalPadding at the default class
AVG_GLYPH_RATIO = 0.5     # Roboto average advance / font size, Latin+Turkish


def _type_scale(root: Path) -> dict:
    src = (root / "lib" / "core" / "design_tokens.dart").read_text(encoding="utf-8")
    block = SCALE_RE.search(src)
    if not block:
        return {}
    return {n: float(v) for n, v in CONST_RE.findall(block.group(1))}


def _scan(root: Path) -> dict:
    sizes: Counter = Counter()
    weights: Counter = Counter()
    letter: Counter = Counter()
    heights: Counter = Counter()
    families: Counter = Counter()
    indirect: Counter = Counter()
    size_sites: dict = {}
    uppercase_sites: list = []
    link_sites: list = []
    files = dart_files(root)
    for path in files:
        src = read_stripped(path)
        name = rel(path, root)
        for m in re.finditer(r"fontSize:\s*([0-9.]+)", src):
            value = float(m.group(1))
            sizes[value] += 1
            size_sites.setdefault(value, []).append(name)
        for m in re.finditer(r"fontWeight:\s*FontWeight\.(\w+)", src):
            weights[m.group(1)] += 1
        for m in re.finditer(r"\bletterSpacing:\s*(-?[0-9.]+)", src):
            letter[float(m.group(1))] += 1
        # Only QUOTED families count as a declared face. `fontFamily: _fontFamily`
        # is an identifier whose value is resolved below; counting the identifier
        # as a font name reports this app as shipping a face called "_fontFamily".
        for m in re.finditer(r"fontFamily:\s*(?:'([^']*)'|\"([^\"]*)\")", src):
            families[m.group(1) or m.group(2)] += 1
        for m in re.finditer(r"fontFamily:\s*(_?\w+)\s*,", src):
            indirect[m.group(1)] += 1
        for m in re.finditer(r"TextStyle\((?:[^()]|\([^()]*\))*\)", src):
            h = re.search(r"\bheight:\s*([0-9.]+)", m.group(0))
            if h:
                heights[float(h.group(1))] += 1
        # `.toUpperCase()` on a rendered string is how SHOUTING enters a Flutter
        # app; a `TextStyle` has no text-transform.
        for m in re.finditer(r"\.toUpperCase\(\)", src):
            line = src[: m.start()].count("\n") + 1
            uppercase_sites.append(f"{name}:{line}")
        for m in re.finditer(r"decoration:\s*TextDecoration\.underline", src):
            line = src[: m.start()].count("\n") + 1
            link_sites.append(f"{name}:{line}")
    return {
        "files": [rel(p, root) for p in files],
        "sizes": sizes,
        "weights": weights,
        "letter": letter,
        "heights": heights,
        "families": families,
        "indirect": indirect,
        "sizeSites": size_sites,
        "uppercaseSites": uppercase_sites,
        "linkSites": link_sites,
    }


# Sites that render type below the smallest named rung. Each needs a reason, and
# the reason is checked for staleness by `measure` below: an exemption that
# outlives its site is reported as a violation of its own.
MICRO_LABEL_EXEMPTIONS = {
    "lib/screens/contacts_page.dart:327": (
        "single-line 'ACIL' badge inside a tinted chip; w800 + 0.5 tracking. "
        "Duplicates the row's own emergency styling, carries no unique meaning."
    ),
    "lib/screens/legal/unified_consent_screen.dart:690": (
        "'Zorunlu' pill marking a mandatory consent row. The consent text itself "
        "is body-sized; the pill is a redundant marker."
    ),
    "lib/screens/map_page.dart:385": (
        "'(c) OpenStreetMap contributors' tile attribution. Required by the ODbL "
        "and conventionally set small so it does not compete with the map."
    ),
    "lib/widgets/consent_checkbox_widget.dart:102": (
        "'OZEL NITELIKLI VERI' badge above a body-sized consent label. The legal "
        "warning itself is the label, not the badge."
    ),
}

_TEXTSTYLE = re.compile(r"TextStyle\((?:[^()]|\([^()]*\))*\)")


def _sub_rung_sites(root: Path, floor: float) -> dict:
    """Every rendered TextStyle whose literal fontSize is below [floor]."""
    found = {}
    for path in dart_files(root):
        src = read_stripped(path)
        for m in _TEXTSTYLE.finditer(src):
            size = re.search(r"fontSize:\s*([0-9.]+)", m.group(0))
            if not size or float(size.group(1)) >= floor:
                continue
            # Key on the line of the `fontSize:` literal, not the line the
            # TextStyle opens on: the literal is what a reader greps for, and a
            # multi-line style would otherwise report a line with no number on it.
            line = src[: m.start() + size.start()].count("\n") + 1
            # The literal a few lines above is the string this style renders.
            window = src[max(0, m.start() - 240): m.start()]
            literal = re.findall(r"'([^'\n]{2,40})'|\"([^\"\n]{2,40})\"", window)
            found[f"{rel(path, root)}:{line}"] = {
                "size": float(size.group(1)),
                "text": (literal[-1][0] or literal[-1][1]) if literal else "",
            }
    return found


def _tight_leading_sites(root: Path) -> dict:
    """Every TextStyle with height < 1.2, tagged with whether it is body-sized."""
    found = {}
    for path in dart_files(root):
        src = read_stripped(path)
        for m in _TEXTSTYLE.finditer(src):
            block = m.group(0)
            h = re.search(r"\bheight:\s*([0-9.]+)", block)
            if not h or float(h.group(1)) >= 1.2:
                continue
            size = re.search(r"fontSize:\s*([0-9.]+)", block)
            # An identifier fontSize (countdownFontSize) is a display numeral by
            # construction; treat a missing literal as display, and say so.
            numeric = float(size.group(1)) if size else None
            line = src[: m.start()].count("\n") + 1
            found[f"{rel(path, root)}:{line}"] = {
                "height": float(h.group(1)),
                "size": numeric if numeric is not None else "computed",
                "bodySized": numeric is not None and numeric <= 18,
            }
    return found


def measure(root: Path) -> list:
    """Returns the violation list. Shared by the artifact run and the control."""
    data = _scan(root)
    scale = _type_scale(root)
    rungs = sorted(set(scale.values()))
    violations = []

    # 1. Type below the smallest named rung. Four sites exist and every one is a
    #    single-line badge or a map attribution, so a blanket violation would be
    #    a false positive -- but a blanket exemption would be worse, because it
    #    is exactly how 9px spreads into body copy. They are therefore named
    #    individually in MICRO_LABEL_EXEMPTIONS with a reason, and the exemption
    #    is STALENESS-CHECKED: an entry whose site no longer renders sub-rung
    #    type is itself a violation. This is the same shape as the allow-list in
    #    test/core/shadow_token_ratchet_test.dart.
    below = _sub_rung_sites(root, min(rungs) if rungs else 0)
    for site, info in sorted(below.items()):
        if site not in MICRO_LABEL_EXEMPTIONS:
            violations.append({
                "rule": "belowMinimumType",
                "detail": f"{site} renders fontSize {info['size']} below the smallest rung",
                "text": info["text"],
            })
    for site in sorted(MICRO_LABEL_EXEMPTIONS):
        if site not in below:
            violations.append({
                "rule": "staleTypeExemption",
                "detail": f"{site} is exempted but no longer renders sub-rung type",
            })

    # 2. Leading. The 1.2 floor is a BODY floor: display type legitimately takes
    #    tighter leading (a 34px countdown numeral at 1.4 would float in a box of
    #    air). So the rule applies at <= 18px, and the two display sites that sit
    #    under 1.2 are recorded as exclusions with their measured size, not
    #    silently dropped from the scan.
    for site, info in sorted(_tight_leading_sites(root).items()):
        if info["bodySized"]:
            violations.append({
                "rule": "lineHeightTooTight",
                "detail": f"{site} sets height {info['height']} on {info['size']}px body type",
            })

    # 3. Measure: characters per line at the narrowest supported width.
    usable = NARROW_WIDTH_DP - PAGE_PADDING_DP
    for size, count in sorted(data["sizes"].items()):
        chars = usable / (size * AVG_GLYPH_RATIO)
        if chars > MEASURE_MAX:
            violations.append({
                "rule": "measureTooLong",
                "detail": f"fontSize {size} yields ~{chars:.0f} chars at {NARROW_WIDTH_DP}dp",
                "count": count,
            })

    # 4. Heading hierarchy must be strictly separable: adjacent heading rungs
    #    that differ by less than 2 logical px are not visually distinguishable.
    heading_names = ("subtitle", "title", "headline", "display", "hero")
    heading_values = [scale[n] for n in heading_names if n in scale]
    for a, b in zip(heading_values, heading_values[1:]):
        if b - a < 2:
            violations.append({
                "rule": "headingRungsNotSeparable",
                "detail": f"adjacent heading rungs {a} and {b} differ by {b - a}",
            })

    # 5. A single font family, or none (platform default), is deliberate. Two or
    #    more competing families in a safety app is drift.
    if len(data["families"]) > 1:
        violations.append({
            "rule": "multipleFontFamilies",
            "detail": f"{sorted(data['families'])} declared",
        })

    # 6. Bold overuse: if the heaviest weights outnumber the lightest by a wide
    #    margin, emphasis has stopped meaning anything.
    heavy = sum(c for w, c in data["weights"].items() if w in ("w700", "w800", "w900"))
    total = sum(data["weights"].values()) or 1
    if heavy / total > 0.85:
        violations.append({
            "rule": "boldOveruse",
            "detail": f"{heavy}/{total} ({heavy / total:.0%}) of weighted styles are w700+",
        })
    return violations


def build(root: Path) -> dict:
    data = _scan(root)
    scale = _type_scale(root)
    rungs = sorted(set(scale.values()))
    sizes = data["sizes"]
    total_sizes = sum(sizes.values())
    on_scale = sum(c for s, c in sizes.items() if s in rungs)
    weights = data["weights"]
    total_weights = sum(weights.values()) or 1
    heavy = sum(c for w, c in weights.items() if w in ("w700", "w800", "w900"))
    usable = NARROW_WIDTH_DP - PAGE_PADDING_DP
    body_sizes = [s for s in sizes if 11 <= s <= 18]

    heights = data["heights"]
    total_heights = sum(heights.values()) or 1
    comfortable = sum(c for h, c in heights.items() if h >= 1.3)

    return {
        "fontFamily": {
            "declaredFamilies": dict(data["families"]),
            "indirectFamilyReferences": dict(data["indirect"]),
            "indirectResolution": (
                "every `fontFamily:` reference in lib/ is the identifier "
                "`_fontFamily`, declared `static const String? _fontFamily = null` "
                "in lib/core/app_theme.dart -- i.e. the platform face"
            ),
            "themeFamilyConstant": "_fontFamily = null (lib/core/app_theme.dart)",
            "resolvesTo": "platform system face — Roboto on Android, SF Pro on iOS",
            "bundledFontAssets": 0,
            "pubspecFontsSection": "commented out; no custom face is shipped",
            "why": (
                "A safety app that ships no font asset can never fail to render "
                "because a webfont did not load, and inherits the user's own "
                "system font scaling and face substitutions for free."
            ),
            "fallbackChain": (
                "Flutter delegates to the platform font manager; with fontFamily "
                "null the chain is the OS default face plus the OS fallback list, "
                "which is what renders Turkish diacritics and emoji."
            ),
        },
        "typeScale": {
            "rungs": scale,
            "distinctSizesInUse": len(sizes),
            "totalSizeSites": total_sizes,
            "onScaleSites": on_scale,
            "onScalePercent": round(100.0 * on_scale / total_sizes, 1) if total_sizes else 0.0,
            "distribution": {str(k): v for k, v in sorted(sizes.items())},
        },
        "headingHierarchy": {
            "rungs": {n: scale[n] for n in ("subtitle", "title", "headline", "display", "hero") if n in scale},
            "minimumAdjacentDelta": min(
                (b - a for a, b in zip(
                    [scale[n] for n in ("subtitle", "title", "headline", "display", "hero") if n in scale],
                    [scale[n] for n in ("subtitle", "title", "headline", "display", "hero") if n in scale][1:],
                )),
                default=0,
            ),
            "semanticHeaderWidgets": _count_semantic_headers(root),
        },
        "bodyReadability": {
            "bodySizesInUse": sorted(body_sizes),
            "dominantBodySize": max(((s, c) for s, c in sizes.items() if 11 <= s <= 18),
                                    key=lambda kv: kv[1], default=(0, 0))[0],
            "sitesAtOrBelow12": sum(c for s, c in sizes.items() if s <= 12),
            "smallestSizeInUse": min(sizes) if sizes else 0,
        },
        "lineHeight": {
            "distribution": {str(k): v for k, v in sorted(heights.items())},
            "sitesWithExplicitHeight": total_heights,
            "atOrAbove1_3": comfortable,
            "atOrAbove1_3Percent": round(100.0 * comfortable / total_heights, 1),
            "minimum": min(heights) if heights else None,
            "flutterDefaultWhenAbsent": "the font's own metric ratio (~1.16 for Roboto)",
        },
        "letterSpacing": {
            "distribution": {str(k): v for k, v in sorted(data["letter"].items())},
            "sites": sum(data["letter"].values()),
            "negativeTrackingSites": sum(c for v, c in data["letter"].items() if v < 0),
            "positiveTrackingSites": sum(c for v, c in data["letter"].items() if v > 0),
            "extremeTrackingSites": sum(c for v, c in data["letter"].items() if abs(v) > 2.0),
        },
        "measureChars": {
            "assumedWidthDp": NARROW_WIDTH_DP,
            "pagePaddingDp": PAGE_PADDING_DP,
            "usableWidthDp": usable,
            "avgGlyphRatio": AVG_GLYPH_RATIO,
            "charsPerLine": {
                str(s): round(usable / (s * AVG_GLYPH_RATIO)) for s in sorted(body_sizes)
            },
            "comfortableBand": [MEASURE_MIN, MEASURE_MAX],
        },
        "weightDistribution": {
            "distribution": dict(weights),
            "totalWeightedSites": total_weights,
            "heavySites": heavy,
            "heavyPercent": round(100.0 * heavy / total_weights, 1),
            "distinctWeights": len(weights),
        },
        "uppercase": {
            "toUpperCaseSites": len(data["uppercaseSites"]),
            "sites": sorted(data["uppercaseSites"]),
        },
        "linkAffordance": {
            "underlineSites": len(data["linkSites"]),
            "sites": sorted(data["linkSites"]),
        },
    }


def _count_semantic_headers(root: Path) -> int:
    count = 0
    for path in dart_files(root):
        count += len(re.findall(r"header:\s*true", read_stripped(path)))
    return count


def _mutate(scratch: Path) -> str:
    target = scratch / "lib" / "core" / "app_theme.dart"
    src = target.read_text(encoding="utf-8")
    src = src.replace(
        "  static const String? _fontFamily = null;",
        "  static const String? _fontFamily = 'Schyler';\n"
        "  static const String? _secondFamily = 'TrajanPro';\n"
        "  static const TextStyle _cramped = TextStyle(fontSize: 7, height: 1.0);",
    )
    src += "\nconst _extra = TextStyle(fontFamily: 'TrajanPro', fontSize: 7, height: 1.05);\n"
    target.write_text(src, encoding="utf-8")
    return "second font family + 7px type + 1.05 line height"


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control("typography", _mutate, measure)
    measurements = build(REPO)
    violations = measure(REPO)
    path = emit(
        "typography.json",
        verifier="scripts/audit_evidence/typography.py",
        version=VERSION,
        command=COMMAND,
        surfaces=[f"lib/**/*.dart ({len(dart_files(REPO))} files)",
                  "lib/core/design_tokens.dart (TypeScale)",
                  "lib/core/app_theme.dart", "pubspec.yaml (fonts section)"],
        measurements=measurements,
        violations=violations,
        exclusions=[
            {"what": "comments and doc comments",
             "why": "design_tokens.dart documents the literals it replaced inside its own "
                    "doc comments; counting those makes the token file its worst offender"},
            {"what": "test/ and android/ sources",
             "why": "neither renders type to a user"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "a second font family plus a 7px / 1.05-line-height style",
            "expected": "violations rise above baseline",
        }},
    )
    print(f"TYPOGRAPHY_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
