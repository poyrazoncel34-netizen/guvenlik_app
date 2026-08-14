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


# Words a dispatch outcome may NOT contain. An Android app hands an intent to
# the platform; it never observes the far end, so an outcome named "delivered"
# or "answered" would be an unprovable claim wearing a state's clothes.
UNPROVABLE_OUTCOME_WORDS = ("delivered", "ringing", "answered", "connected",
                            "completed")

MODEL_FILE = "lib/core/services/dispatch_outcome.dart"


def _enum_members(src: str, name: str) -> list:
    """The member names of `enum <name> { ... }`, comments already stripped."""
    match = re.search(r"enum\s+" + re.escape(name) + r"\s*\{(.*?)\n\}", src, re.S)
    if not match:
        return []
    return [
        m.group(1)
        for m in re.finditer(r"^\s*([a-z][A-Za-z0-9]*)\s*,", match.group(1), re.M)
    ]


def _per_target_outcome_surface(root: Path) -> dict:
    """MP-01-027: is each dispatch target's outcome separately observable?

    Everything below is COMPUTED from the tree. The predecessor of this function
    was `_sites(root, r"partial|PartialDispatch|perTarget")`, which matched the
    word "partial" inside two translation keys on a screen that had no
    per-target surface at all -- a measurement that answered a different
    question than the one asked.
    """
    model = read_stripped(root / MODEL_FILE) if (root / MODEL_FILE).exists() else ""
    targets = _enum_members(model, "DispatchTarget")
    outcomes = _enum_members(model, "DispatchTargetOutcome")
    reachability = _enum_members(model, "DispatchReachability")

    # Where outcomes are RECORDED, and where they are RENDERED. A model with no
    # renderer is the same defect in a nicer wrapper.
    recording = sorted({site.split(":")[0] for site in
                        _sites(root, r"\.recordOutcome\(|recordCallTargets\(")})
    rendering = sorted({site.split(":")[0] for site in
                        _sites(root, r"DispatchOutcomeList\.build\(|"
                                     r"row\.outcome\.messageKey|"
                                     r"row\.target\.labelKey")})
    partial_predicate = _sites(root, r"bool get isPartial")

    unprovable = [o for o in outcomes
                  if any(w in o.lower() for w in UNPROVABLE_OUTCOME_WORDS)]

    return {
        "modelFile": MODEL_FILE if model else None,
        "targetKinds": targets,
        "outcomeStates": outcomes,
        "reachabilityClasses": reachability,
        "recordingFiles": recording,
        "renderingFiles": rendering,
        "partialPredicateSites": partial_predicate,
        "unprovableOutcomeNames": unprovable,
    }


DEEP_LINK_MODEL = "lib/core/navigation/app_destination.dart"
DEEP_LINK_PARSER = "lib/core/navigation/deep_link_parser.dart"
DEEP_LINK_PARK = "lib/core/navigation/pending_destination_service.dart"
DEEP_LINK_ROUTER = "lib/core/navigation/destination_router.dart"
MANIFEST = "android/app/src/main/AndroidManifest.xml"

# Words a destination slug may not contain. An external link may put the user in
# front of a surface; it may never perform a safety action on their behalf.
FORBIDDEN_DESTINATION_WORDS = ("arm", "dial", "call", "panic", "sos", "cancel",
                               "unlock", "pin", "trigger", "emergency")


def _deep_link_surface(root: Path) -> dict:
    """MP-26-008: the validated destination model, measured from the tree."""
    model = read_stripped(root / DEEP_LINK_MODEL) if (root / DEEP_LINK_MODEL).exists() else ""
    parser = read_stripped(root / DEEP_LINK_PARSER) if (root / DEEP_LINK_PARSER).exists() else ""
    park = read_stripped(root / DEEP_LINK_PARK) if (root / DEEP_LINK_PARK).exists() else ""
    router = read_stripped(root / DEEP_LINK_ROUTER) if (root / DEEP_LINK_ROUTER).exists() else ""
    manifest = (root / MANIFEST).read_text(encoding="utf-8") if (root / MANIFEST).exists() else ""

    slugs = re.findall(r"AppDestination\.\w+ => '([^']+)'", model)
    rejections_block = re.search(r"enum DeepLinkRejection\s*\{([^}]*)\}", model, re.S)
    rejections = ([r.strip() for r in re.findall(r"^\s*(\w+),", rejections_block.group(1), re.M)]
                  if rejections_block else [])

    # Who may CONSUME a parked destination. More than one consumer means more
    # than one place that could run ahead of the PIN gate.
    consumers = sorted({
        site.split(":")[0]
        for site in _sites(root, r"PendingDestinationService\.instance\.consume\(\)")
        if not site.startswith(DEEP_LINK_PARK)
    })

    action_like = [s for s in slugs
                   if any(w in s.lower() for w in FORBIDDEN_DESTINATION_WORDS)]

    return {
        "scheme": (re.search(r"scheme = '(\w+)'", parser) or [None, None])[1]
                  if re.search(r"scheme = '(\w+)'", parser) else None,
        "manifestSchemes": sorted(set(re.findall(r'android:scheme="([^"]+)"', manifest))),
        "autoVerifyDeclared": 'android:autoVerify="true"' in manifest,
        "destinationSlugs": slugs,
        "actionLikeDestinations": action_like,
        "rejectionReasons": rejections,
        "gatedDestinations": re.findall(r"AppDestination\.(\w+) => PremiumFeature\.", model),
        "parkFile": DEEP_LINK_PARK if park else None,
        "parkConsumers": consumers,
        "singleConsume": "_pending = null;" in park,
        "boundedRejectionLog": "maxRecordedRejections" in park,
        "routerAsksSubscriptionGate": "SubscriptionGate.ensureAccess" in router,
        "parserIsPure": bool(parser) and "Navigator" not in parser
                        and "BuildContext" not in parser,
        "coveringTests": ["test/core/navigation/deep_link_test.dart",
                          "test/android/release_surface_audit_test.dart"],
        "appLinkNote": (
            "an https App Link is deliberately ABSENT rather than deferred. "
            "autoVerify requires /.well-known/assetlinks.json at the DOMAIN "
            "ROOT, and this project's public pages are a GitHub Pages *project* "
            "site, so the root belongs to github.io and cannot be served by us. "
            "That is a fact about the hosting, not a difficulty, so it is not an "
            "external blocker to be parked -- a custom scheme claims no domain "
            "ownership and the whole surface is provable here."
        ),
    }


# Every path that erases local data. A subscriber must hear the same thing on
# each of them, or the honest path is just the one they did not take.
LOCAL_ERASE_PATHS = (
    "lib/screens/settings_legal/data_deletion_screen.dart",
    "lib/core/utils/app_reset_helper.dart",
)
DELETION_NOTICE = "lib/core/widgets/subscription_deletion_notice.dart"


def _subscription_deletion_notice(root: Path) -> dict:
    """MP-23-015: does a subscriber learn that deletion is not cancellation?

    Computed over the real catalogue, not over key existence: the sentence a
    user reads is the artifact this row is about.
    """
    notice = read_stripped(root / DELETION_NOTICE) if (root / DELETION_NOTICE).exists() else ""
    tr = json.loads((root / "assets" / "translations" / "tr-TR.json")
                    .read_text(encoding="utf-8"))
    en = json.loads((root / "assets" / "translations" / "en-US.json")
                    .read_text(encoding="utf-8"))
    tr_body = tr.get("subscription_survives_deletion_body", "")
    en_body = en.get("subscription_survives_deletion_body", "")

    shown_on = [path for path in LOCAL_ERASE_PATHS
                if "SubscriptionDeletionNotice(" in
                read_stripped(root / path) if (root / path).exists()]

    return {
        "noticeWidget": DELETION_NOTICE if notice else None,
        "localErasePaths": list(LOCAL_ERASE_PATHS),
        "shownOn": shown_on,
        "sitesInDeletionScreen": len(re.findall(
            r"SubscriptionDeletionNotice\(",
            read_stripped(root / LOCAL_ERASE_PATHS[0])
            if (root / LOCAL_ERASE_PATHS[0]).exists() else "")),
        "trNamesGooglePlay": "Google Play" in tr_body,
        "enNamesGooglePlay": "Google Play" in en_body,
        "trStatesNotCancelled": "iptal etmez" in tr_body,
        "enStatesNotCancelled": "does not cancel" in en_body.lower(),
        "trCoversUninstall": "kaldırmak" in tr_body.lower(),
        "enCoversUninstall": "uninstall" in en_body.lower(),
        "linksToPlaySubscriptions": "googlePlaySubscriptionsUrl" in notice,
        "offersAnImpossibleCancel": any(
            token in notice for token in ("cancelSubscription", "Purchases.cancel")),
        "bodyLengths": {"tr": len(tr_body), "en": len(en_body)},
        "coveringTests": ["test/screens/subscription_deletion_copy_test.dart"],
    }


SCROLL_SERVICE = "lib/core/services/scroll_restoration.dart"
TIMELINE = "lib/screens/safety_timeline_screen.dart"
SETTINGS = "lib/screens/settings_page.dart"


def _scroll_restoration(root: Path) -> dict:
    """MP-10-023: is a scroll position restored, and by the RIGHT mechanism?

    Two long lists, two different answers, and the difference is the finding:
    `ListView.restorationId` restores a raw pixel offset, which is exactly right
    for the fixed settings list and wrong for the timeline, whose rows are
    PREPENDED (sorted timestamp DESC) so a restored offset lands on a different
    event than the one the user was reading.
    """
    service = read_stripped(root / SCROLL_SERVICE) if (root / SCROLL_SERVICE).exists() else ""
    timeline = read_stripped(root / TIMELINE) if (root / TIMELINE).exists() else ""
    settings = read_stripped(root / SETTINGS) if (root / SETTINGS).exists() else ""

    return {
        "anchorModel": SCROLL_SERVICE if service else None,
        "pixelOffsetLists": sorted(
            {site.split(":")[0] for site in _sites(root, r"restorationId:\s*'")}
        ),
        "identityAnchoredLists": sorted(
            {site.split(":")[0]
             for site in _sites(root, r"KeyedListScrollRestorer\(")}
        ),
        "anchorCarriesIdentity": "topItemId" in service,
        "anchorCarriesIndex": "topItemIndex" in service,
        "twoPhaseRestore": "estimateOffset" in service and "offsetOf(" in service,
        "clampsToCurrentExtent": "maxScrollExtent" in service,
        "degradesWhenUnregistered": "isAttached" in service,
        "schedulesItsOwnFrame": "ensureVisualUpdate" in service,
        "timelineRegistersAnchor":
            "registerForRestoration(_restorer.anchor" in timeline,
        "settingsUsesPixelOffset": "restorationId: 'settings_page_scroll'" in settings,
        "bucketTransportEvidence":
            "docs/audit/device-verification-2026-08-14-state-restoration.md",
        "coveringTests": ["test/screens/scroll_restoration_test.dart"],
    }


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

    # 5. MP-01-027: every dispatch target must have an independently observable
    #    outcome, and no outcome may claim more than an intent handoff proves.
    surface = _per_target_outcome_surface(root)
    if not surface["modelFile"]:
        violations.append({"rule": "noPerTargetOutcomeModel",
                           "detail": f"{MODEL_FILE} is missing"})
    if len(surface["targetKinds"]) < 2:
        violations.append({
            "rule": "singleDispatchTarget",
            "detail": "fewer than two dispatch targets are modelled, so a "
                      "partial outcome cannot be expressed at all",
        })
    if not surface["recordingFiles"]:
        violations.append({"rule": "outcomesNeverRecorded",
                           "detail": "no file records a per-target outcome"})
    if not surface["renderingFiles"]:
        violations.append({
            "rule": "outcomesNeverRendered",
            "detail": "outcomes are recorded but no surface shows them; a model "
                      "the user cannot read is the same aggregate defect",
        })
    if not surface["partialPredicateSites"]:
        violations.append({"rule": "noPartialPredicate",
                           "detail": "nothing computes whether a dispatch was partial"})
    for name in surface["unprovableOutcomeNames"]:
        violations.append({
            "rule": "unprovableDispatchOutcome",
            "detail": f"outcome {name!r} claims more than an intent handoff proves",
        })
    # 6. MP-26-008: a deep link must not bypass a gate, and must not be able to
    #    ask for a safety ACTION.
    links = _deep_link_surface(root)
    if links["scheme"]:
        for slug in links["actionLikeDestinations"]:
            violations.append({
                "rule": "deepLinkDestinationPerformsSafetyAction",
                "detail": f"destination {slug!r} names an action; an external "
                          f"link may show a surface, never perform one",
            })
        if len(links["parkConsumers"]) != 1:
            violations.append({
                "rule": "multipleDestinationConsumers",
                "detail": f"{links['parkConsumers']} each consume a parked "
                          f"destination; a second consumer can run before the "
                          f"PIN gate",
            })
        if not links["singleConsume"]:
            violations.append({"rule": "destinationNotSingleConsume",
                               "detail": "a parked destination can re-fire"})
        if not links["boundedRejectionLog"]:
            violations.append({"rule": "unboundedRejectionLog",
                               "detail": "a hostile burst of links grows memory"})
        if not links["routerAsksSubscriptionGate"]:
            violations.append({
                "rule": "deepLinkBypassesEntitlementGate",
                "detail": "the router does not call SubscriptionGate.ensureAccess",
            })
        if not links["parserIsPure"]:
            violations.append({
                "rule": "linkParserCanNavigate",
                "detail": "the parser reaches a Navigator or a BuildContext, so "
                          "a link could route before the gates",
            })
        for scheme in links["manifestSchemes"]:
            if scheme in {"http", "https"}:
                violations.append({
                    "rule": "unprovableAppLinkDeclared",
                    "detail": "an https intent filter asserts domain ownership "
                              "this project cannot publish assetlinks.json for",
                })
        if links["autoVerifyDeclared"]:
            violations.append({
                "rule": "autoVerifyWithoutAssetLinks",
                "detail": "autoVerify claims a Digital Asset Links association "
                          "that cannot be served from a GitHub Pages project site",
            })

    # 7. MP-23-015: erasing local data must not silently imply cancelling a
    #    Play subscription, which Google bills and which survives an uninstall.
    notice = _subscription_deletion_notice(root)
    if not notice["noticeWidget"]:
        violations.append({"rule": "noSubscriptionDeletionNotice",
                           "detail": DELETION_NOTICE})
    else:
        for path in notice["localErasePaths"]:
            if path not in notice["shownOn"]:
                violations.append({
                    "rule": "eraseePathWithoutSubscriptionNotice",
                    "detail": f"{path} erases local data without telling a "
                              f"subscriber that billing continues",
                })
        for flag, detail in (
            ("trStatesNotCancelled", "the Turkish copy does not say the "
                                     "subscription is NOT cancelled"),
            ("enStatesNotCancelled", "the English copy does not say the "
                                     "subscription is NOT cancelled"),
            ("trCoversUninstall", "the Turkish copy does not cover uninstalling"),
            ("enCoversUninstall", "the English copy does not cover uninstalling"),
            ("linksToPlaySubscriptions", "there is no route to the screen that "
                                         "can actually cancel"),
        ):
            if not notice[flag]:
                violations.append({"rule": "subscriptionDeletionCopyIncomplete",
                                   "detail": detail})
        if notice["offersAnImpossibleCancel"]:
            violations.append({
                "rule": "appClaimsItCanCancelPlaySubscription",
                "detail": "a control that looks like it cancels is a worse lie "
                          "than the silence this row is about",
            })

    # 8. MP-10-023: a scroll position must be restored by the mechanism that
    #    suits the list's content.
    scroll = _scroll_restoration(root)
    if not scroll["anchorModel"]:
        violations.append({"rule": "noScrollRestoration", "detail": SCROLL_SERVICE})
    else:
        if not scroll["settingsUsesPixelOffset"]:
            violations.append({
                "rule": "fixedListWithoutScrollRestoration",
                "detail": "the settings list has fixed content, so the built-in "
                          "pixel restoration is exactly right and is missing",
            })
        if not scroll["timelineRegistersAnchor"]:
            violations.append({
                "rule": "growingListWithoutIdentityAnchor",
                "detail": "the timeline prepends rows, so a restored pixel "
                          "offset lands on a different event",
            })
        if TIMELINE in scroll["pixelOffsetLists"]:
            violations.append({
                "rule": "growingListUsesPixelOffset",
                "detail": f"{TIMELINE} restores a raw offset into a list that "
                          f"prepends rows",
            })
        for flag, detail in (
            ("anchorCarriesIdentity", "the anchor is a bare offset again"),
            ("anchorCarriesIndex", "without the capture index a lazy list cannot "
                                   "build the anchored item to correct against"),
            ("twoPhaseRestore", "the restore no longer corrects its estimate "
                                "against real geometry"),
            ("clampsToCurrentExtent", "a restored offset from a longer list can "
                                      "throw or snap on resume"),
            ("degradesWhenUnregistered", "writing an unregistered RestorableValue "
                                         "asserts, so a scroll outside a "
                                         "restoration scope would crash"),
            ("schedulesItsOwnFrame", "addPostFrameCallback alone schedules no "
                                     "frame, so the restore silently never runs"),
        ):
            if not scroll[flag]:
                violations.append({"rule": "scrollRestorationWeakened",
                                   "detail": detail})

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
                "deep link": "korubeni://open/<destination>",
            },
            "deepLinks": _deep_link_surface(root),
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
            "subscriptionSurvivesDeletion": _subscription_deletion_notice(root),
        },
        "interruptionSafety": {
            "restorationPolicyTest": "test/state_restoration_policy_test.dart",
            "restorationScopeSites": _sites(root, r"RestorationMixin|restorationId"),
            "deviceEvidence": "docs/audit/device-verification-2026-08-14-state-restoration.md",
            "whatSurvives": "unsaved emergency-contact entry",
            "whatDeliberatelyDoesNot": ["PIN buffers", "destructive confirmation state",
                                        "an armed countdown"],
            "scrollRestoration": _scroll_restoration(root),
        },
        "flowStates": {
            "successSurfaces": len(snackbars),
            "failureSurfaces": len(_sites(root, r"errorText|_error|SnackBar\(.*error")),
            "emptySurfaces": len(empties),
            "loadingSurfaces": len(spinners) + len(shimmers),
            "timeoutSurfaces": _sites(root, r"timeout\(|Timeout|onTimeout"),
            "partialSuccessSurfaces": _per_target_outcome_surface(root),
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
    # NOTE: this replacement used to be "_noConfirmDialog", which contains the
    # substring "ConfirmDialog" -- the very alternative rule 1 accepts. The
    # mutation therefore removed the guard and the verifier stayed green, so
    # this negative control was demonstrating a DIFFERENT rule than the one it
    # named. Found by extending the control for MP-01-027, 2026-08-15.
    src = src.replace("showDialog", "_skippedPrompt")
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
    # MP-01-027: launder the outcome vocabulary. Renaming handoffAccepted to
    # "delivered" is the exact overclaim this row exists to prevent, and
    # deleting the renderer reproduces "modelled but invisible".
    model = scratch / MODEL_FILE
    if model.exists():
        model.write_text(
            model.read_text(encoding="utf-8").replace(
                "  handoffAccepted,", "  delivered,", 1
            ),
            encoding="utf-8",
        )
    # MP-26-008: give the link model a destination that performs a safety
    # action, and let a second place consume the parked destination.
    destinations = scratch / DEEP_LINK_MODEL
    if destinations.exists():
        destinations.write_text(
            destinations.read_text(encoding="utf-8").replace(
                "AppDestination.home => 'home',", "AppDestination.home => 'panic-dial',", 1
            ),
            encoding="utf-8",
        )
    # MP-23-015: strip the subscription notice from the reset dialog, which is
    # the erase path a user is most likely to take.
    # MP-10-023: take the timeline back to the naive mechanism.
    timeline = scratch / TIMELINE
    if timeline.exists():
        timeline.write_text(
            timeline.read_text(encoding="utf-8").replace(
                "registerForRestoration(_restorer.anchor", "// removed("
            ),
            encoding="utf-8",
        )
    scroll_service = scratch / SCROLL_SERVICE
    if scroll_service.exists():
        scroll_service.write_text(
            scroll_service.read_text(encoding="utf-8")
            .replace("topItemIndex", "_droppedIndex")
            .replace("ensureVisualUpdate", "_noFrame"),
            encoding="utf-8",
        )
    reset = scratch / "lib/core/utils/app_reset_helper.dart"
    if reset.exists():
        reset.write_text(
            reset.read_text(encoding="utf-8").replace(
                "const SubscriptionDeletionNotice(compact: true),", ""
            ),
            encoding="utf-8",
        )
    second_consumer = scratch / "lib/screens/_early_consumer.dart"
    second_consumer.write_text(
        "import '../core/navigation/pending_destination_service.dart';\n"
        "void runEarly() { PendingDestinationService.instance.consume(); }\n",
        encoding="utf-8",
    )
    renderer = scratch / "lib/core/widgets/dispatch_outcome_list.dart"
    if renderer.exists():
        renderer.unlink()
    # Deleting the widget alone is not enough: the screen still names it, so the
    # measurement would still find a rendering site. The CALL has to go too --
    # which is precisely the "modelled but never shown" defect.
    screen = scratch / "lib/screens/emergency_call_screen.dart"
    if screen.exists():
        screen.write_text(
            screen.read_text(encoding="utf-8").replace(
                "...DispatchOutcomeList.build(widget.dispatchLedger),", ""
            ),
            encoding="utf-8",
        )
    return ("unconfirmed data erase + a screen with no exit path + an outcome "
            "renamed to 'delivered' + the per-target renderer deleted + a "
            "deep-link destination renamed to 'panic-dial' + a second consumer "
            "of the parked destination + the subscription notice removed from "
            "the reset dialog + the timeline's scroll anchor unregistered and "
            "the two-phase restore broken")


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
            "mutation": "remove the confirmation from 'erase all app data'; add a "
                        "screen with no exit path; rename the handoffAccepted "
                        "outcome to 'delivered'; delete the per-target renderer; "
                        "rename a deep-link destination to 'panic-dial'; add a "
                        "second consumer of the parked destination",
            "expected": "destructiveActionUnconfirmed, screenWithNoExitPath, "
                        "unprovableDispatchOutcome, outcomesNeverRendered, "
                        "deepLinkDestinationPerformsSafetyAction and "
                        "multipleDestinationConsumers fire",
        }},
    )
    print(f"FLOWS_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
