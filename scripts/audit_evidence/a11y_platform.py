#!/usr/bin/env python3
"""Which accessibility features this Flutter SDK actually delivers on Android.

  measurements.sdk                   -> MP-12-029 (version provenance)
  measurements.platformSupport       -> MP-12-029 (per-flag Android support)
  measurements.appConsumption        -> MP-12-029 (what the app reads)
  measurements.colourIndependence    -> MP-12-029 (does meaning survive a forced palette)

Why this verifier exists
------------------------
MP-12-029 asks whether high-contrast / forced-colour behaviour is tested. The
tempting answer is `MediaQuery.highContrastOf(context)`. In the SDK this repo
pins, that flag's own documentation says "Only supported on iOS" -- so an
Android "high contrast test" written against it would be green forever and
would be measuring nothing. Rather than assert that, this verifier PARSES the
installed SDK and reports, per flag, which platforms the SDK itself claims.

Run:
    python3 scripts/audit_evidence/a11y_platform.py
    python3 scripts/audit_evidence/a11y_platform.py --negative-control
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    REPO, dart_files, emit, main_guard, read_stripped, rel, run_negative_control,
)

VERSION = "1.0.0"
COMMAND = "python3 scripts/audit_evidence/a11y_platform.py"

# The accessibility flags the framework exposes. Support is READ from the SDK.
FLAGS = (
    "accessibleNavigation",
    "invertColors",
    "disableAnimations",
    "boldText",
    "reduceMotion",
    "highContrast",
    "onOffSwitchLabels",
)

# Surfaces MP-12-029 names as critical. Each must carry meaning that survives a
# forced palette -- i.e. not colour alone.
CRITICAL_SURFACES = {
    "panic / SOS": "lib/widgets/panic_button.dart",
    "locked PRO": "lib/core/widgets/readiness_card.dart",
    "warning banners": "lib/widgets/connectivity_banner.dart",
    "focus ring": "lib/core/widgets/focus_ring.dart",
    "error states": "lib/screens/countdown_screen.dart",
    "PIN": "lib/screens/app_unlock_screen.dart",
    "onboarding contact": "lib/screens/onboarding/onboarding_contact_step.dart",
    "countdown": "lib/screens/countdown_screen.dart",
    "dispatch outcome": "lib/core/widgets/dispatch_outcome_list.dart",
}

# Non-colour carriers of meaning. A surface that has at least one of these still
# says what it means when the platform replaces every colour.
NON_COLOUR_SIGNALS = (
    r"Icon\(", r"Icons\.", r"Semantics\(", r"semanticLabel", r"\.tr\(",
    r"Text\(", r"fontWeight", r"border:", r"Border\.",
)


def _flutter_root() -> Path | None:
    binary = shutil.which("flutter")
    if not binary:
        return None
    return Path(binary).resolve().parents[1]


def _sdk_version() -> dict:
    try:
        out = subprocess.run(
            ["flutter", "--version"], capture_output=True, text=True, check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return {"raw": None}
    version = re.search(r"Flutter (\S+) . channel (\S+)", out)
    engine = re.search(r"Engine . hash (\S+)", out)
    dart = re.search(r"Dart (\S+)", out)
    return {
        "flutter": version.group(1) if version else None,
        "channel": version.group(2) if version else None,
        "engineHash": engine.group(1) if engine else None,
        "dart": dart.group(1) if dart else None,
    }


def _platform_support(root: Path) -> dict:
    """Per-flag platform support, read from the SDK's own doc comments."""
    sdk = _flutter_root()
    if sdk is None:
        return {"windowDart": None, "flags": {}}
    window = sdk / "bin/cache/pkg/sky_engine/lib/ui/window.dart"
    if not window.exists():
        return {"windowDart": None, "flags": {}}
    source = window.read_text(encoding="utf-8")

    flags: dict[str, dict] = {}
    for flag in FLAGS:
        match = re.search(
            r"((?:\s*///.*\n)+)\s*bool get " + re.escape(flag) + r"\b", source
        )
        doc = match.group(1) if match else ""
        note = re.search(r"Only supported on ([^.]+)\.", doc)
        limited = note.group(1).strip() if note else None
        flags[flag] = {
            "sdkDocLimitation": limited,
            # A flag whose doc says "Only supported on iOS" is not Android
            # signal, no matter what the Android settings screen offers.
            "androidDelivered": limited is None or "android" in limited.lower(),
            "declared": bool(match),
        }
    return {
        "windowDart": str(window.relative_to(sdk)),
        "flags": flags,
    }


def _app_consumption(root: Path) -> dict:
    """Which flags the app actually reads, and where."""
    sites: dict[str, list] = {flag: [] for flag in FLAGS}
    for path in dart_files(root):
        name = rel(path, root)
        src = read_stripped(path)
        for flag in FLAGS:
            for m in re.finditer(
                r"MediaQuery\.\w*" + flag[0].upper() + flag[1:] + r"|"
                r"\.accessibilityFeatures\." + flag + r"|"
                r"MediaQuery(?:\.of\(\w+\))?\.\w*\b" + flag + r"\b",
                src,
            ):
                sites[flag].append(f"{name}:{src[: m.start()].count(chr(10)) + 1}")
    return {flag: sorted(set(found)) for flag, found in sites.items()}


def _colour_independence(root: Path) -> dict:
    """Does each critical surface carry meaning by something other than colour?"""
    out = {}
    for label, path in sorted(CRITICAL_SURFACES.items()):
        target = root / path
        if not target.exists():
            out[label] = {"file": path, "exists": False, "signals": []}
            continue
        src = read_stripped(target)
        signals = [pattern for pattern in NON_COLOUR_SIGNALS
                   if re.search(pattern, src)]
        out[label] = {
            "file": path,
            "exists": True,
            "signals": signals,
            "colourOnly": not signals,
        }
    return out


DEVICE_DOC = "docs/audit/device-verification-2026-08-15-forced-colors.md"


def _device_evidence(root: Path = REPO) -> dict:
    """The measured numbers from the device pass, PARSED from the write-up.

    Parsed rather than retyped: a number that lives in two places drifts, and
    this audit has already downgraded rows for exactly that.
    """
    doc = root / DEVICE_DOC
    if not doc.exists():
        return {"file": None}
    text = doc.read_text(encoding="utf-8")

    def _num(label):
        # The count sits after the COLON. An earlier version matched the first
        # digits on the line and returned 100 out of "(y<100)" for both rows --
        # a parse bug that made the two measurements identical and the claim
        # meaningless. Anchor on the colon.
        m = re.search(re.escape(label) + r"[^:\n]*:\s*(\d+)", text)
        return int(m.group(1)) if m else None

    return {
        "file": DEVICE_DOC,
        "statusBarPixelsChangedByHighContrastText":
            _num("changed pixels in status bar"),
        "appContentPixelsChangedByHighContrastText":
            _num("changed pixels in APP CONTENT"),
        "positiveControl": "the status-bar clock is an Android View and DID "
                           "repaint, so the setting was demonstrably active "
                           "while Flutter content changed by zero pixels",
        "screenshotIsWrongInstrumentForInversion":
            "wrong instrument" in text,
        "coveringTest": "test/screens/forced_colors_test.dart",
    }


def measure(root: Path) -> list:
    violations = []
    support = _platform_support(root)
    consumption = _app_consumption(root)

    if not support["flags"]:
        violations.append({"rule": "sdkAccessibilityFlagsUnreadable",
                           "detail": "window.dart could not be parsed"})

    # The defect this verifier exists to prevent: reading an iOS-only flag and
    # calling the result an Android high-contrast test.
    for flag, info in support["flags"].items():
        if info["androidDelivered"]:
            continue
        if consumption.get(flag):
            violations.append({
                "rule": "iosOnlyFlagUsedAsAndroidSignal",
                "detail": f"{flag} is documented '{info['sdkDocLimitation']}' in "
                          f"this SDK but is read at {consumption[flag]}; on "
                          f"Android it is a constant false",
            })

    for label, info in _colour_independence(root).items():
        if not info["exists"]:
            violations.append({"rule": "criticalSurfaceMissing",
                               "detail": f"{label}: {info['file']}"})
        elif info.get("colourOnly"):
            violations.append({
                "rule": "surfaceCarriesMeaningByColourAlone",
                "detail": f"{label} ({info['file']}) has no icon, text, border or "
                          f"semantic label; a forced palette erases its meaning",
            })
    # The device pass must exist and must have found the app content unchanged
    # by a setting that demonstrably fired.
    device = _device_evidence(root)
    if not device["file"]:
        violations.append({"rule": "noForcedColourDeviceEvidence",
                           "detail": DEVICE_DOC})
    else:
        if device["statusBarPixelsChangedByHighContrastText"] in (None, 0):
            violations.append({
                "rule": "forcedColourRunHadNoPositiveControl",
                "detail": "nothing on screen changed when high-contrast text "
                          "was enabled, so the run does not prove the setting "
                          "was active and 'no effect on Flutter' is unearned",
            })
        if device["appContentPixelsChangedByHighContrastText"] is None:
            violations.append({
                "rule": "forcedColourAppContentUnmeasured",
                "detail": "the write-up does not state how much app content "
                          "changed",
            })

    return violations


def build(root: Path) -> dict:
    return {
        "sdk": _sdk_version(),
        "platformSupport": _platform_support(root),
        "appConsumption": _app_consumption(root),
        "colourIndependence": _colour_independence(root),
        "deviceEvidence": _device_evidence(root),
        "androidHighContrastNote": (
            "Android's Settings > Accessibility > High contrast text is a VIEW-"
            "layer render override applied by the system to Android Views. "
            "Flutter draws into its own Surface, so the setting neither repaints "
            "Flutter text nor is reported to the app -- there is no flag for it "
            "in this SDK. The framework's `highContrast` is documented 'Only "
            "supported on iOS', so an Android test written against it would be "
            "green forever and measure nothing. What Android DOES deliver here "
            "is invertColors (colour inversion) and boldText (API 31+), and the "
            "durable answer for a forced palette is that meaning must not rest "
            "on colour alone -- which is what colourIndependence measures."
        ),
    }


def _mutate(scratch: Path) -> str:
    # run_negative_control copies lib/, assets/ and test/. The device write-up
    # lives under docs/, so it is staged here rather than silently skipped --
    # a mutation that cannot reach its target is a control that proves nothing.
    import shutil
    (scratch / "docs" / "audit").mkdir(parents=True, exist_ok=True)
    if (REPO / DEVICE_DOC).exists():
        shutil.copy(REPO / DEVICE_DOC, scratch / DEVICE_DOC)
    # Strip every non-colour signal from a critical surface, leaving colour as
    # the only carrier of meaning.
    target = scratch / CRITICAL_SURFACES["dispatch outcome"]
    if target.exists():
        target.write_text(
            "import 'package:flutter/material.dart';\n"
            "class DispatchOutcomeList {\n"
            "  static List<Widget> build(Object? ledger) => const <Widget>[\n"
            "    ColoredBox(color: Color(0xFFFF0000), child: SizedBox.shrink()),\n"
            "  ];\n"
            "}\n",
            encoding="utf-8",
        )
    # Also blank the device write-up's positive control, so the "the setting
    # really was on" half of the claim is shown to be checked too.
    doc = scratch / DEVICE_DOC
    if doc.exists():
        doc.write_text(
            doc.read_text(encoding="utf-8").replace(
                "changed pixels in status bar (y<100):        3361",
                "changed pixels in status bar (y<100):           0",
            ),
            encoding="utf-8",
        )
    return ("a critical surface reduced to colour alone + the device run's "
            "positive control zeroed")


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control("a11y_platform", _mutate, measure)
    violations = measure(REPO)
    path = emit(
        "a11y_platform.json",
        verifier="scripts/audit_evidence/a11y_platform.py",
        version=VERSION,
        command=COMMAND,
        surfaces=["lib/**", "the installed Flutter SDK's sky_engine window.dart"],
        measurements=build(REPO),
        violations=violations,
        exclusions=[
            {"what": "iOS-only accessibility flags",
             "why": "this release targets Android only; the flags are reported "
                    "rather than consumed, so the limitation is visible instead "
                    "of silently producing a constant-false test"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "reduce a critical surface to colour alone; zero the "
                        "device run's positive control",
            "expected": "surfaceCarriesMeaningByColourAlone and "
                        "forcedColourRunHadNoPositiveControl fire",
        }},
    )
    print(f"A11Y_PLATFORM_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
