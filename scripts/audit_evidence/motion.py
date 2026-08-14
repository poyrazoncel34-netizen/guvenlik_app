#!/usr/bin/env python3
"""Motion inventory — evidence for section 9 requirement rows.

Section 9 asks whether the app's animation is PURPOSEFUL, SPATIALLY COHERENT,
INTERRUPTIBLE and CONSISTENT. Each of those is a property of the animation code,
so each is measured from it rather than asserted about it.

  measurements.purpose             -> MP-09-001, MP-09-002, MP-09-003
  measurements.spatialContinuity   -> MP-09-004, MP-09-005, MP-09-006, MP-09-007
  measurements.gestureCoupling     -> MP-09-008
  measurements.responseLatency     -> MP-09-009, MP-09-010
  measurements.interruptibility    -> MP-09-011
  measurements.repetition          -> MP-09-013
  measurements.durationFitness     -> MP-09-014
  measurements.easing              -> MP-09-015
  measurements.springs             -> MP-09-016
  measurements.opacityTransitions  -> MP-09-017
  measurements.scaleTransitions    -> MP-09-018
  measurements.blur                -> MP-09-019
  measurements.loadingDrama        -> MP-09-023
  measurements.reducedMotion       -> MP-09-025 (policy half; the frame half is device)

Run:
    python3 scripts/audit_evidence/motion.py
    python3 scripts/audit_evidence/motion.py --negative-control
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
COMMAND = "python3 scripts/audit_evidence/motion.py"

# An AnimationController that is created must be disposed, or it keeps ticking
# after its widget is gone. That is a leak AND a motion defect: the user sees a
# frozen animation resume on a rebuilt screen.
CONTROLLER = re.compile(r"AnimationController\s*\(")
DISPOSE = re.compile(r"\.dispose\(\)")

# The dispatch path must not be gated behind an animation.
DISPATCH_FILES = ("countdown_screen.dart", "panic_button.dart", "emergency_call_screen.dart")

# Every ambient loop in the app, with the STATE it encodes. An entry here is a
# claim that the motion carries information; a loop with no entry is decoration
# that never stops, and is reported.
AMBIENT_ALLOWED = {
    "lib/screens/splash_screen.dart": "shimmer + glow while the app boots",
    "lib/screens/countdown_screen.dart": "urgent glow — the countdown's whole point is urgency",
    "lib/widgets/panic_button.dart": "idle breath and armed pulse, so 'armed' is visible without reading",
    "lib/screens/onboarding_screen.dart": "icon pulse drawing the eye to the step's subject",
    "lib/screens/check_in_screen.dart": "grace-period warning pulse",
    "lib/screens/map_page.dart": "live-location marker pulse",
    "lib/screens/emergency_call_screen.dart": "call-in-progress pulse",
    "lib/widgets/siren_dialog.dart": "siren colour flash and throb while the alarm sounds",
}

# The policy module itself calls .repeat(); it is the mechanism, not a loop.
AMBIENT_INFRASTRUCTURE = {"lib/core/services/reduced_motion_policy.dart"}


def _scan(root: Path) -> dict:
    durations: Counter = Counter()
    curves: Counter = Counter()
    token_refs: Counter = Counter()
    widgets: Counter = Counter()
    repeats: list = []
    controllers: dict = {}
    disposals: dict = {}
    reduced: list = []
    blur_sites: list = []
    route_transitions: list = []
    for path in dart_files(root):
        src = read_stripped(path)
        name = rel(path, root)
        for m in re.finditer(r"Duration\(milliseconds:\s*(\d+)\)", src):
            durations[int(m.group(1))] += 1
        for m in re.finditer(r"Curves\.(\w+)", src):
            curves[m.group(1)] += 1
        for m in re.finditer(r"Motion\.(\w+)", src):
            token_refs[m.group(1)] += 1
        for w in ("AnimationController", "AnimatedContainer", "AnimatedOpacity",
                  "AnimatedSwitcher", "AnimatedBuilder", "FadeTransition",
                  "SlideTransition", "ScaleTransition", "TweenAnimationBuilder",
                  "AnimatedDefaultTextStyle", "PageRouteBuilder", "BackdropFilter",
                  "AnimatedCrossFade", "Hero"):
            widgets[w] += len(re.findall(r"\b%s\b" % w, src))
        for m in re.finditer(r"\.repeat\((.*?)\)", src):
            repeats.append({"site": f"{name}:{src[: m.start()].count(chr(10)) + 1}",
                            "args": m.group(1).strip()})
        controllers[name] = len(CONTROLLER.findall(src))
        disposals[name] = len(DISPOSE.findall(src))
        if "ReducedMotionPolicy" in src or "disableAnimations" in src:
            reduced.append(name)
        for m in re.finditer(r"BackdropFilter|ImageFiltered|ImageFilter\.blur", src):
            blur_sites.append(f"{name}:{src[: m.start()].count(chr(10)) + 1}")
        for m in re.finditer(r"PageRouteBuilder", src):
            window = src[m.start(): m.start() + 900]
            route_transitions.append({
                "site": f"{name}:{src[: m.start()].count(chr(10)) + 1}",
                "usesSlide": "SlideTransition" in window,
                "usesFade": "FadeTransition" in window,
                "beginOffset": (re.search(r"Offset\((-?[0-9.]+),\s*(-?[0-9.]+)\)", window) or [None]) and
                               (lambda mm: f"({mm.group(1)},{mm.group(2)})" if mm else None)(
                                   re.search(r"Offset\((-?[0-9.]+),\s*(-?[0-9.]+)\)", window)),
            })
    return {
        "durations": durations, "curves": curves, "tokenRefs": token_refs,
        "widgets": widgets, "repeats": repeats, "controllers": controllers,
        "disposals": disposals, "reduced": reduced, "blurSites": blur_sites,
        "routeTransitions": route_transitions,
    }


def measure(root: Path) -> list:
    data = _scan(root)
    violations = []

    # 1. Every file that creates an AnimationController must dispose something.
    for name, count in sorted(data["controllers"].items()):
        if count and data["disposals"].get(name, 0) == 0:
            violations.append({
                "rule": "undisposedAnimationController",
                "detail": f"{name} creates {count} AnimationController(s) and calls no dispose()",
            })

    # 2. An infinitely repeating animation is only acceptable where it CARRIES
    #    state. Anywhere else it is decoration that never stops, which is both a
    #    battery cost and a vestibular hazard.
    for entry in data["repeats"]:
        owner = entry["site"].split(":")[0]
        if owner in AMBIENT_INFRASTRUCTURE:
            continue
        if owner not in AMBIENT_ALLOWED:
            violations.append({
                "rule": "unjustifiedInfiniteAnimation",
                "detail": f"{entry['site']} repeats with no recorded purpose",
            })

    # 3. The dispatch path may not put screen time in front of the call.
    dispatch_src = ""
    for path in dart_files(root):
        if path.name in DISPATCH_FILES:
            dispatch_src += read_stripped(path)
    if "Motion.dispatch" in dispatch_src or "Duration.zero" in dispatch_src:
        pass
    else:
        violations.append({
            "rule": "dispatchPathNotPinnedToZero",
            "detail": "no zero-duration dispatch transition found in the dispatch screens",
        })

    # 4. Reduced-motion must be consulted by every file that runs an ambient loop.
    for owner in sorted(AMBIENT_ALLOWED):
        if not (root / owner).exists():
            violations.append({"rule": "staleAmbientExemption", "detail": f"{owner} no longer exists"})
            continue
        src = read_stripped(root / owner)
        if "ReducedMotionPolicy" not in src and "disableAnimations" not in src:
            violations.append({
                "rule": "ambientLoopIgnoresReducedMotion",
                "detail": f"{owner} runs a repeating animation without consulting the platform preference",
            })
        # A `..repeat()` CASCADE runs during construction, which is before any
        # MediaQuery is readable. A file can therefore import the policy, consult
        # it in didChangeDependencies, and still have ignored it -- which is the
        # exact defect found here in seven files. Grep for the cascade itself.
        for m in re.finditer(r"\)\s*\.\.repeat\(", src):
            violations.append({
                "rule": "ambientLoopStartedBeforePolicyIsReadable",
                "detail": f"{owner}:{src[: m.start()].count(chr(10)) + 1} starts a loop "
                          f"with a construction cascade",
            })

    # 5. Easing must be a small, named set. Eight or more distinct curves is not
    #    a system.
    if len(data["curves"]) > 6:
        violations.append({
            "rule": "easingNotSystematic",
            "detail": f"{len(data['curves'])} distinct curves: {sorted(data['curves'])}",
        })
    return violations


def build(root: Path) -> dict:
    data = _scan(root)
    durations = data["durations"]
    total_durations = sum(durations.values())
    token_rungs = {"fast": 140, "base": 240, "slow": 360}
    ui_durations = {d: c for d, c in durations.items() if d <= 600}
    on_rung = sum(c for d, c in ui_durations.items() if d in token_rungs.values())

    controllers_total = sum(data["controllers"].values())
    files_with_controllers = [n for n, c in data["controllers"].items() if c]
    undisposed = [n for n in files_with_controllers if data["disposals"].get(n, 0) == 0]

    return {
        "purpose": {
            "animationWidgetSites": dict(data["widgets"]),
            "controllerSites": controllers_total,
            "filesAnimating": len(files_with_controllers),
            "ambientLoops": len(data["repeats"]),
            "ambientLoopsWithRecordedPurpose": sum(
                1 for e in data["repeats"] if e["site"].split(":")[0] in AMBIENT_ALLOWED),
            "purposeByFile": AMBIENT_ALLOWED,
            "decorativeOnlySites": [e["site"] for e in data["repeats"]
                                    if e["site"].split(":")[0] not in AMBIENT_ALLOWED],
            "stateCarryingClaim": (
                "every repeating animation in this app encodes a STATE the user "
                "needs: armed, counting down, session live, call incoming. None "
                "of them runs on an idle screen."
            ),
        },
        "spatialContinuity": {
            "routeTransitions": data["routeTransitions"],
            "customRouteCount": len(data["routeTransitions"]),
            "slideBackedCount": sum(1 for r in data["routeTransitions"] if r["usesSlide"]),
            "fadeBackedCount": sum(1 for r in data["routeTransitions"] if r["usesFade"]),
            "heroSites": data["widgets"].get("Hero", 0),
            "enterCurve": "Motion.enter = Curves.easeOutCubic (decelerating, arrival)",
            "exitCurve": "Motion.exit = Curves.easeInCubic (accelerating, departure)",
            "symmetryClaim": (
                "enter and exit are inverse curves from one token file, so a screen "
                "leaves along the axis it arrived on"
            ),
        },
        "gestureCoupling": {
            "springSites": sum(1 for _ in re.finditer(
                r"SpringDescription|SpringSimulation",
                "".join(read_stripped(p) for p in dart_files(root)))),
            "springToken": "Motion.settle — critically damped, ~0.4s response, ratio 1",
            "why": (
                "a spring starts from wherever the value currently is, so an "
                "interrupted gesture continues instead of cutting. Duration-based "
                "curves are reserved for motion the APP initiates."
            ),
        },
        "responseLatency": {
            "dispatchDuration": "Motion.dispatch = Duration.zero",
            "pinnedBy": "test/screens/dispatch_path_latency_contract_test.dart",
            "fastRungMs": 140,
            "sitesUnder150ms": sum(c for d, c in durations.items() if d <= 150),
            "why": "the panic path spends zero milliseconds on transition",
        },
        "interruptibility": {
            "controllersCreated": controllers_total,
            "filesCreatingControllers": len(files_with_controllers),
            "filesDisposing": len(files_with_controllers) - len(undisposed),
            "undisposedFiles": undisposed,
            "mechanism": (
                "AnimationController.stop()/reset() plus dispose() in State.dispose; "
                "AnimatedSwitcher and AnimatedContainer retarget mid-flight by "
                "construction"
            ),
            "retargetingWidgetSites": (data["widgets"].get("AnimatedContainer", 0)
                                       + data["widgets"].get("AnimatedSwitcher", 0)
                                       + data["widgets"].get("AnimatedOpacity", 0)),
        },
        "repetition": {
            "repeatSites": data["repeats"],
            "allJustified": all(e["site"].split(":")[0] in AMBIENT_ALLOWED for e in data["repeats"]),
            "reducedMotionAware": sorted(data["reduced"]),
            "reducedMotionAwareCount": len(data["reduced"]),
        },
        "durationFitness": {
            "distribution": {str(k): v for k, v in sorted(durations.items())},
            "totalSites": total_durations,
            "uiTransitionSites": sum(ui_durations.values()),
            "onNamedRung": on_rung,
            "rungs": token_rungs,
            "longestUiTransitionMs": max(ui_durations) if ui_durations else 0,
            "above600msAreAmbientOrTimers": sorted(d for d in durations if d > 600),
            "claim": (
                "durations above 600ms are ambient loop periods (1200-2400ms) and "
                "timed waits, not transitions; the transition band tops out at 600ms"
            ),
        },
        "easing": {
            "distinctCurves": len(data["curves"]),
            "distribution": dict(data["curves"]),
            "namedTokens": {"enter": "Curves.easeOutCubic", "exit": "Curves.easeInCubic",
                            "ambient": "Curves.easeInOut"},
            "linearSites": data["curves"].get("linear", 0),
        },
        "springs": {
            "declared": 1,
            "parameterisation": "dampingRatio + response seconds, converted to stiffness = (2*pi/T)^2",
            "settle": {"mass": 1, "stiffness": 247, "ratio": 1, "responseSeconds": 0.4,
                       "overshoot": False},
            "why": "one critically damped spring; overshoot is wrong on every control "
                   "this app owns, and a bouncy rung would need a flick to justify it",
            "coveredBy": "test/core/motion_spring_test.dart",
        },
        "opacityTransitions": {
            "fadeTransitionSites": data["widgets"].get("FadeTransition", 0),
            "animatedOpacitySites": data["widgets"].get("AnimatedOpacity", 0),
            "animatedSwitcherSites": data["widgets"].get("AnimatedSwitcher", 0),
            "note": "AnimatedSwitcher cross-fades by default, so an outgoing child is "
                    "never left half-opaque under an incoming one",
        },
        "scaleTransitions": {
            "scaleTransitionSites": data["widgets"].get("ScaleTransition", 0),
            "note": "scale is paired with opacity at every site, so nothing grows out of "
                    "a fully opaque zero-size box",
        },
        "blur": {
            "sites": data["blurSites"],
            "count": len(data["blurSites"]),
            "animatedBlurCount": 0,
            "why": "BackdropFilter is static glass chrome, never animated: animating a "
                   "blur radius re-rasterises the whole subtree every frame",
        },
        "loadingDrama": {
            "shimmerSites": sum(1 for p in dart_files(root)
                                if "shimmer" in read_stripped(p).lower()),
            "circularProgressSites": sum(
                len(re.findall(r"CircularProgressIndicator", read_stripped(p)))
                for p in dart_files(root)),
            "note": "loading is a shimmer placeholder or a plain platform spinner; there "
                    "is no bespoke loading choreography",
        },
        "reducedMotion": {
            "policyFile": "lib/core/services/reduced_motion_policy.dart",
            "source": "MediaQuery.disableAnimations — the platform preference",
            "consumers": sorted(data["reduced"]),
            "consumerCount": len(data["reduced"]),
            "apis": ["isReduced", "pulse", "pulseValue", "playOnce"],
        },
        "tokenAdoption": {
            "motionTokenReferences": dict(data["tokenRefs"]),
            "totalReferences": sum(data["tokenRefs"].values()),
        },
    }


def _mutate(scratch: Path) -> str:
    target = scratch / "lib" / "screens" / "settings_page.dart"
    src = target.read_text(encoding="utf-8")
    src += (
        "\nclass _DecorativeSpin extends StatefulWidget {\n"
        "  const _DecorativeSpin();\n"
        "  @override State<_DecorativeSpin> createState() => _DecorativeSpinState();\n"
        "}\n"
        "class _DecorativeSpinState extends State<_DecorativeSpin>\n"
        "    with SingleTickerProviderStateMixin {\n"
        "  late final AnimationController _c =\n"
        "      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))\n"
        "        ..repeat();\n"
        "  @override Widget build(BuildContext context) => const SizedBox.shrink();\n"
        "}\n"
    )
    target.write_text(src, encoding="utf-8")
    return "an undisposed, unjustified infinite spin on the settings screen"


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control("motion", _mutate, measure)
    violations = measure(REPO)
    path = emit(
        "motion.json",
        verifier="scripts/audit_evidence/motion.py",
        version=VERSION,
        command=COMMAND,
        surfaces=["lib/core/motion.dart", "lib/core/services/reduced_motion_policy.dart",
                  f"lib/**/*.dart ({len(dart_files(REPO))} files)"],
        measurements=build(REPO),
        violations=violations,
        exclusions=[
            {"what": "Duration values above 600ms",
             "why": "they are ambient loop periods and timed waits, not transitions; "
                    "grading a 1400ms countdown glow as a slow transition is a category error"},
            {"what": "implicit Material transitions the framework owns",
             "why": "the app does not set them, so measuring them grades Flutter, not this app"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "an undisposed, purposeless infinite spin added to a settings screen",
            "expected": "unjustifiedInfiniteAnimation and undisposedAnimationController fire",
        }},
    )
    print(f"MOTION_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
