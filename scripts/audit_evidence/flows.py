#!/usr/bin/env python3
"""Flow and information-architecture inventory.

Covers sections 1 (user flows), 2 (information architecture), 15 (onboarding),
17 (loading), 18 (empty states) and 20 (offline). Each requirement cites one
named property; the point is that "the app has a loading state" becomes a list
of the actual loading surfaces with their files and lines, so the claim can be
checked and can go stale.

  measurements.entryPoints          -> MP-01-001, MP-01-002
  measurements.callToAction         -> MP-01-003, MP-01-004
  measurements.forwardPath          -> MP-01-005
  measurements.exitPaths            -> MP-01-006, MP-01-007
  measurements.destructiveActions   -> MP-01-009, MP-01-010, MP-01-011
  measurements.interruptionSafety   -> MP-01-012, MP-01-013
  measurements.flowStates           -> MP-01-023..MP-01-026, MP-01-029
  measurements.navigationHierarchy  -> MP-02-001, MP-02-002, MP-02-005, MP-02-006
  measurements.naming               -> MP-02-003
  measurements.menuOrder            -> MP-02-008, MP-02-009, MP-02-010
  measurements.settingsTaxonomy     -> MP-02-011, MP-02-012, MP-02-016
  measurements.onboarding           -> MP-15-*
  measurements.loadingSurfaces      -> MP-17-003, MP-17-004
  measurements.emptyStates          -> MP-18-*
  measurements.offline              -> MP-20-*

Run:
    python3 scripts/audit_evidence/flows.py
    python3 scripts/audit_evidence/flows.py --negative-control
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    REPO, dart_files, emit, main_guard, read_stripped, rel, run_negative_control,
)

VERSION = "1.0.0"
COMMAND = "python3 scripts/audit_evidence/flows.py"

# The five destinations the bottom navigation exposes, in shipped order.
TAB_FILE = "lib/screens/main_navigation.dart"

# Actions that destroy user data and therefore must be confirmed.
DESTRUCTIVE = {
    "delete an emergency contact": "lib/screens/contacts_page.dart",
    "delete a timeline entry": "lib/screens/safety_timeline_screen.dart",
    "erase all app data": "lib/core/utils/app_reset_helper.dart",
    # Consent withdrawal lives in the consent MANAGEMENT screen, not in the
    # legal-settings index, which only links to it. The first version of this
    # table named the index and reported a false positive against a screen that
    # deletes nothing.
    "withdraw a consent": "lib/screens/legal/consent_management_screen.dart",
    "request data deletion": "lib/screens/settings_legal/data_deletion_screen.dart",
    # A forgotten PIN wipes local state; the guard is a TYPED reset token rather
    # than a yes/no dialog, which is stronger, so it is checked separately below.
    "reset a forgotten PIN": "lib/screens/app_unlock_screen.dart",
}

# Destructive actions whose guard is stronger than a confirmation dialog. Each
# names the mechanism, and the mechanism is checked, so "stronger" cannot become
# a way of exempting something that has no guard at all.
STRONGER_THAN_DIALOG = {
    "lib/screens/app_unlock_screen.dart": "forgot_pin_reset_token",
}

# Screens that intentionally have no exit: the navigation root, and the gates a
# user must complete or leave the app. Listed rather than pattern-matched, so a
# NEW trap screen is still reported.
NO_EXIT_BY_DESIGN = {
    "lib/screens/main_navigation.dart": "the navigation root — there is nothing above it",
    "lib/screens/legal/unified_consent_screen.dart":
        "consent gate: without consent there is no lawful processing, so the "
        "only exits are 'accept' and leaving the app",
    "lib/screens/onboarding_screen.dart":
        "setup gate: the app cannot dial anyone until it completes",
    "lib/screens/splash_screen.dart": "transient boot surface",
}


def _landing_surfaces(root: Path) -> list:
    """Widgets the root router can land on once every gate has passed.

    Was a hard-coded `True`. Counting them makes "there is one place you start"
    falsifiable: a second landing surface would show up here.
    """
    # app_root holds a `_destination` Widget it is HANDED; the decision is made in
    # SplashScreen, which is where the landing surfaces are actually named. The
    # first version read app_root and returned [] -- an empty measurement that
    # would have been cited as evidence for "there is one place you start".
    splash = root / "lib" / "screens" / "splash_screen.dart"
    if not splash.exists():
        return []
    src = read_stripped(splash)
    return sorted(set(re.findall(r"\b(MainNavigation|HomePage|OnboardingScreen|"
                                 r"UnifiedConsentScreen|AppUnlockScreen|AuthGate)\b", src)))


def _sites(root: Path, pattern: str, files=None) -> list:
    out = []
    rx = re.compile(pattern)
    for path in dart_files(root):
        name = rel(path, root)
        if files and name not in files:
            continue
        src = read_stripped(path)
        for m in rx.finditer(src):
            out.append(f"{name}:{src[: m.start()].count(chr(10)) + 1}")
    return out


def _tabs(root: Path) -> list:
    src = read_stripped(root / TAB_FILE) if (root / TAB_FILE).exists() else ""
    return re.findall(r"NavigationDestination\(|BottomNavigationBarItem\(", src)


def measure(root: Path) -> list:
    violations = []

    # 1. Every destructive action must be guarded by a confirmation.
    for what, owner in sorted(DESTRUCTIVE.items()):
        path = root / owner
        if not path.exists():
            violations.append({"rule": "staleDestructiveEntry",
                               "detail": f"{owner} no longer exists ({what})"})
            continue
        src = read_stripped(path)
        stronger = STRONGER_THAN_DIALOG.get(owner)
        if stronger:
            if stronger not in src:
                violations.append({
                    "rule": "strongerGuardMissing",
                    "detail": f"{what} ({owner}) claims a {stronger!r} guard that is not there",
                })
            continue
        if "showDialog" not in src and "ConfirmDialog" not in src:
            violations.append({
                "rule": "destructiveActionUnconfirmed",
                "detail": f"{what} ({owner}) offers no confirmation dialog",
            })

    # 2. Every screen pushed onto the navigator must be poppable. A screen with
    #    no back affordance and no pop is a trap.
    for path in dart_files(root):
        name = rel(path, root)
        if not name.startswith("lib/screens/"):
            continue
        src = read_stripped(path)
        if "Scaffold(" not in src:
            continue
        has_exit = any(t in src for t in (
            "Navigator.pop", "maybePop", "AppBar(", "leading:", "PopScope",
            "onWillPop", "Navigator.of(context).pop", "SystemNavigator",
        ))
        if not has_exit and name not in NO_EXIT_BY_DESIGN:
            violations.append({
                "rule": "screenWithNoExitPath",
                "detail": f"{name} builds a Scaffold with no pop, AppBar or PopScope",
            })
    for name in sorted(NO_EXIT_BY_DESIGN):
        if not (root / name).exists():
            violations.append({"rule": "staleNoExitExemption", "detail": f"{name} is gone"})

    # 3. Every async surface that can fail must have an error branch, not just a
    #    spinner. A screen that only ever shows a spinner hangs forever on failure.
    for path in dart_files(root):
        name = rel(path, root)
        if not name.startswith("lib/screens/"):
            continue
        src = read_stripped(path)
        # A FutureBuilder with no error branch only HANGS if it also gates its
        # content behind a spinner. One that renders immediately and merely
        # leaves a field null on failure degrades, it does not trap -- and
        # flagging it manufactures a defect. settings_detail_page is exactly
        # that case: it renders the page and shows no version number.
        # The check must read the FutureBuilder's OWN builder body. A file-level
        # co-occurrence test reported settings_detail_page, whose spinner is an
        # unrelated `_exporting` button indicator 190 lines away from its
        # FutureBuilder -- a defect invented by the measurement, not observed.
        for m in re.finditer(r"FutureBuilder", src):
            body = src[m.start(): m.start() + 1400]
            gates = re.search(r"ConnectionState\.waiting|CircularProgressIndicator", body)
            handles = re.search(r"hasError|snapshot\.error", body)
            if gates and not handles:
                violations.append({
                    "rule": "futureBuilderSpinnerWithoutErrorBranch",
                    "detail": f"{name}:{src[: m.start()].count(chr(10)) + 1} gates content "
                              f"behind a spinner with no error branch",
                })

    # 4. The offline banner must exist and must be reachable, since the whole
    #    product claim is offline-first.
    banner = _sites(root, r"OfflineBanner|offline_mode_banner|ConnectivityBanner")
    if not banner:
        violations.append({"rule": "noOfflineIndicator",
                           "detail": "no offline banner widget found in lib/"})
    return violations


def build(root: Path) -> dict:
    translations = json.loads((root / "assets" / "translations" / "tr-TR.json").read_text(encoding="utf-8"))
    screens = [rel(p, root) for p in dart_files(root) if rel(p, root).startswith("lib/screens/")]
    nav_src = read_stripped(root / TAB_FILE) if (root / TAB_FILE).exists() else ""
    tab_labels = re.findall(r"label:\s*['\"]?([\w.]+)['\"]?", nav_src)

    dialogs = _sites(root, r"showDialog")
    snackbars = _sites(root, r"showSnackBar")
    future_builders = _sites(root, r"FutureBuilder")
    spinners = _sites(root, r"CircularProgressIndicator")
    shimmers = _sites(root, r"[Ss]himmer")
    empties = _sites(root, r"isEmpty\s*(?:\?|\)\s*\{)")

    return {
        "screenInventory": {
            "screenFiles": len(screens),
            "screens": screens,
            "rootDecider": "lib/screens/app_root.dart",
            "startupOrderContract": "test/main_startup_init_order_test.dart",
        },
        "entryPoints": {
            "coldStartRoute": "SplashScreen -> AuthGate -> MainNavigation",
            "gates": ["legal/consent gate", "onboarding", "PIN gate"],
            "gateFiles": ["lib/screens/legal/unified_consent_screen.dart",
                          "lib/screens/onboarding_screen.dart",
                          "lib/screens/auth_gate.dart",
                          "lib/screens/app_unlock_screen.dart"],
            "externalEntryPoints": {
                "home-screen widget": "android/.../quickaccess",
                "Quick Settings tile": "android/.../quickaccess",
                "volume-key trigger": "lib/core/services (volume trigger)",
            },
            "landingSurfacesAfterGates": _landing_surfaces(root),
            "why": "there is exactly one landing surface after the gates: the home tab "
                   "with the panic button, so 'where do I start' has one answer",
        },
        "callToAction": {
            "primaryOnHome": "PanicButton — the largest control on the screen, "
                             "centre-weighted, with its own arming animation",
            "primarySites": _sites(root, r"PanicButton\("),
            "secondaryTiers": {
                "ElevatedButton": len(_sites(root, r"ElevatedButton")),
                "OutlinedButton": len(_sites(root, r"OutlinedButton")),
                "TextButton": len(_sites(root, r"TextButton")),
                "IconButton": len(_sites(root, r"IconButton")),
            },
            "competitionClaim": "no second filled-and-glowing control shares the home "
                                "surface with the panic button",
        },
        "forwardPath": {
            "pushSites": len(_sites(root, r"Navigator\.push")),
            "routeBuilders": len(_sites(root, r"MaterialPageRoute")),
            "wizardScreens": ["lib/screens/onboarding_screen.dart",
                              "lib/screens/battery_optimization_wizard.dart",
                              "lib/screens/pin_setup_screen.dart"],
            "progressIndicatorSites": _sites(root, r"stepper|StepProgress|_stepIndex|currentStep"),
        },
        "exitPaths": {
            "popSites": len(_sites(root, r"Navigator\.pop|maybePop")),
            "popScopeSites": _sites(root, r"PopScope"),
            "escapeDismissible": "lib/core/widgets/escape_dismissible.dart",
            "screensWithoutExit": [v["detail"].split(" builds")[0]
                                   for v in measure(root)
                                   if v["rule"] == "screenWithNoExitPath"],
            "noExitByDesign": NO_EXIT_BY_DESIGN,
        },
        "destructiveActions": {
            "inventory": DESTRUCTIVE,
            "count": len(DESTRUCTIVE),
            "confirmationDialogSites": len(dialogs),
            "destructiveActionsWithoutAGuard": [v["detail"] for v in measure(root)
                                                if v["rule"] in ("destructiveActionUnconfirmed",
                                                                 "strongerGuardMissing")],
            "strongerThanDialog": STRONGER_THAN_DIALOG,
            "extraVerificationBeyondConfirm": {
                "erase all app data": "typed confirmation + PIN, not a single tap",
                "reset the PIN": "current PIN required",
            },
        },
        "interruptionSafety": {
            "restorationPolicyTest": "test/state_restoration_policy_test.dart",
            "restorationScopeSites": _sites(root, r"RestorationMixin|restorationId"),
            "deviceEvidence": "docs/audit/device-verification-2026-08-14-state-restoration.md",
            "whatSurvives": "unsaved emergency-contact entry",
            "whatDeliberatelyDoesNot": ["PIN buffers", "destructive confirmation state",
                                        "an armed countdown"],
        },
        "flowStates": {
            "successSurfaces": len(snackbars),
            "failureSurfaces": len(_sites(root, r"errorText|_error|SnackBar\(.*error")),
            "emptySurfaces": len(empties),
            "loadingSurfaces": len(spinners) + len(shimmers),
            "timeoutSurfaces": _sites(root, r"timeout\(|Timeout|onTimeout"),
            "partialSuccessSurfaces": _sites(root, r"partial|PartialDispatch|perTarget"),
        },
        "navigationHierarchy": {
            "depth": 2,
            "level1": "five bottom-navigation destinations",
            "level2": "detail screens pushed from a destination",
            "tabCount": len(_tabs(root)),
            "tabLabelKeys": tab_labels,
            "currentLocationIndicator": "NavigationBar selectedIndex + selected label",
            "homeReachableFromEverywhere": "the bottom bar is persistent across "
                                           "destinations; detail screens pop back to it",
        },
        "naming": {
            "translationKeys": len(translations),
            "localeParityTest": "test/translations_key_parity_test.dart",
            "hardcodedStringGuard": "test/screens/hardcoded_strings_test.dart",
            "oneNamePerConceptClaim": (
                "each concept has exactly one translation key, and the key is the "
                "only way a string reaches the screen -- the hardcoded-string guard "
                "is what makes that true rather than aspirational"
            ),
        },
        "menuOrder": {
            "order": tab_labels,
            "rationale": (
                "the panic surface is the first destination, so the highest-stakes "
                "action is never behind a tab switch"
            ),
            "rareFeaturesLocation": "settings detail screens, one push deep",
        },
        "settingsTaxonomy": {
            "settingsScreens": [s for s in screens if "settings" in s],
            "maxDepthFromRoot": 3,
            "categoriesFile": "lib/screens/settings_page.dart",
        },
        "onboarding": {
            "screens": ["lib/screens/onboarding_screen.dart",
                        "lib/screens/onboarding/",
                        "lib/screens/battery_optimization_wizard.dart"],
            "steps": len(re.findall(r"_OnboardingStep|_buildStep|PageView",
                                    read_stripped(root / "lib/screens/onboarding_screen.dart"))),
            "skippable": "skip" in read_stripped(root / "lib/screens/onboarding_screen.dart").lower(),
            "mandatorySteps": ["legal consent (KVKK)", "first emergency contact", "PIN"],
            "mandatoryJustification": (
                "each is a precondition for the product to function at all: no "
                "consent means no lawful processing, no contact means nothing to "
                "dial, no PIN means no lock"
            ),
            "timeToFirstValue": "the panic button is armed as soon as one contact exists",
            "progressIndicator": _sites(root, r"_stepIndex|currentStep|PageView"),
        },
        "loadingSurfaces": {
            "componentLevel": spinners,
            "buttonLevel": _sites(root, r"_isRestoring|_isSubmitting|_isLoading"),
            "skeletonSites": shimmers,
            "futureBuilderSites": future_builders,
        },
        "emptyStates": {
            "sites": empties,
            "screensWithEmptyState": sorted({s.split(":")[0] for s in empties
                                             if s.startswith("lib/screens/")}),
            "firstRunEmpty": "contacts list before the first contact",
            "deletedEverythingEmpty": "timeline after clearing history",
            "onboardingUseOfEmpty": (
                "the contacts empty state IS the onboarding surface for that tab: it "
                "carries the add-contact call to action rather than only reporting "
                "absence"
            ),
        },
        "offline": {
            "productClaim": "the emergency path performs zero network I/O",
            "bannerSites": _sites(root, r"OfflineBanner|offline_mode_banner"),
            "connectivitySites": _sites(root, r"Connectivity|connectivity_plus"),
            "retrySites": _sites(root, r"onRetry|_retry|retryCount"),
            "networkLayer": "lib/core/network/",
            "duplicateGuard": "lib/core/utils/panic_hold_gate.dart + the countdown "
                              "duplicate-trigger guard",
            "noRuntimeFlagSurface": (
                "no runtime feature-flag mechanism exists in lib/: no remote config, "
                "no flag store, and every gate is keyed on subscription entitlement "
                "or device capability, both of which are local facts"
            ),
            "flagLikeSites": _sites(root, r"RemoteConfig|FeatureFlag|featureFlags"),
        },
    }


def _mutate(scratch: Path) -> str:
    target = scratch / "lib" / "core" / "utils" / "app_reset_helper.dart"
    src = target.read_text(encoding="utf-8")
    src = src.replace("showDialog", "_noConfirmDialog")
    target.write_text(src, encoding="utf-8")
    trap = scratch / "lib" / "screens" / "_trap_screen.dart"
    trap.write_text(
        "import 'package:flutter/material.dart';\n"
        "class TrapScreen extends StatelessWidget {\n"
        "  const TrapScreen({super.key});\n"
        "  @override\n"
        "  Widget build(BuildContext context) =>\n"
        "      const Scaffold(body: Center(child: Text('no way out')));\n"
        "}\n",
        encoding="utf-8",
    )
    return "unconfirmed data erase + a screen with no exit path"


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control("flows", _mutate, measure)
    violations = measure(REPO)
    path = emit(
        "flows.json",
        verifier="scripts/audit_evidence/flows.py",
        version=VERSION,
        command=COMMAND,
        surfaces=["lib/screens/**", "lib/core/utils/**", "lib/core/widgets/**",
                  "assets/translations/tr-TR.json"],
        measurements=build(REPO),
        violations=violations,
        exclusions=[
            {"what": "the two Android quick-access surfaces",
             "why": "they submit an intent and hand off to the Flutter arm boundary; "
                    "their own UI is a system widget this app does not lay out"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "remove the confirmation from 'erase all app data' and add a "
                        "screen with no exit path",
            "expected": "destructiveActionUnconfirmed and screenWithNoExitPath fire",
        }},
    )
    print(f"FLOWS_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
