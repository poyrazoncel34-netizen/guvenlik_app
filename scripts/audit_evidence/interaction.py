#!/usr/bin/env python3
"""Interaction, component-state and form inventory — sections 8, 11, 16.

  measurements.componentStates    -> MP-08-012, MP-08-031, MP-08-032
  measurements.buttonTiers        -> MP-08-019, MP-08-020
  measurements.characterLimits    -> MP-08-035
  measurements.autofill           -> MP-08-037, MP-16-011, MP-16-012
  measurements.feedbackChannels   -> MP-11-001..MP-11-004, MP-11-012
  measurements.notificationFeedback -> MP-11-014
  measurements.undo               -> MP-11-016
  measurements.validation         -> MP-16-003, MP-16-006, MP-16-008
  measurements.keyboardActions    -> MP-16-016
  measurements.normalisation      -> MP-16-021
  measurements.unsavedChanges     -> MP-16-027

Run:
    python3 scripts/audit_evidence/interaction.py
    python3 scripts/audit_evidence/interaction.py --negative-control
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
COMMAND = "python3 scripts/audit_evidence/interaction.py"

# Every text field the user types into, and what it must declare.
FIELD_RE = re.compile(r"TextFormField\(|TextField\(")


def _fields(root: Path) -> list:
    out = []
    for path in dart_files(root):
        src = read_stripped(path)
        for m in FIELD_RE.finditer(src):
            block = src[m.start(): m.start() + 1600]
            out.append({
                "site": f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}",
                "hasLabel": bool(re.search(r"labelText:|label:", block)),
                "hasHint": bool(re.search(r"hintText:", block)),
                "hasMaxLength": bool(re.search(r"maxLength:", block)),
                "hasInputFormatters": bool(re.search(r"inputFormatters:", block)),
                "hasValidator": bool(re.search(r"validator:", block)),
                "hasKeyboardType": bool(re.search(r"keyboardType:", block)),
                "hasTextInputAction": bool(re.search(r"textInputAction:", block)),
                "hasOnSubmitted": bool(re.search(r"onFieldSubmitted:|onSubmitted:", block)),
                "hasAutofillHints": bool(re.search(r"autofillHints:", block)),
                "obscure": bool(re.search(r"obscureText:\s*true", block)),
            })
    return out


NOTIFICATION_SERVICE = "lib/core/services/notification_service.dart"
ALERT_POST_CALL = re.compile(
    r"(?:NotificationService\.instance\.showEmergencyAlert"
    r"|SafetyAlertDispatch\.postWarning)\("
)


def _alert_call_sites(root: Path) -> list:
    """Every LIVE `showEmergencyAlert` invocation, and whether its typed outcome
    is consumed.

    The property this replaces was `"suppressedByUserSetting" in service` -- a
    substring test over ONE file. It proved a string existed. It could not, even
    in principle, observe a caller throwing the returned value away, and two
    callers did exactly that: the Check-In grace warning awaited the Future and
    dropped the result inside `catch (_) { // Notification not critical }`, and
    the Safe Walk pre-expiry warning neither awaited it nor marked it
    `unawaited()`. Both are safety warnings. Both read as "posted" when the OS
    had suppressed them.

    Consumption is judged from the text between the start of the statement and
    the call: an assignment, a `return`, a `run:`/`() =>` handed to the ledger
    recorder or the dispatch pipeline. A bare `await ...;` statement is NOT
    consumption, and neither is a bare call.
    """
    sites = []
    for path in dart_files(root):
        src = read_stripped(path)
        for match in ALERT_POST_CALL.finditer(src):
            # The statement this call belongs to, back to the previous `;`,
            # `{`, `}` or `=>` -- enough to see an assignment or a return.
            head = src[: match.start()]
            boundary = max(head.rfind(";"), head.rfind("{"), head.rfind("}"))
            statement = head[boundary + 1 :]
            consumed = bool(re.search(
                r"(?:=\s*$|=\s*await\s*$|return\s+(?:await\s+)?$"
                r"|run:\s*\(\)\s*=>\s*$|\(\)\s*=>\s*$)",
                statement.strip() + ("" if statement.endswith(" ") else ""),
            )) or bool(re.search(
                r"(?:=|return|=>)\s*(?:await\s+)?$", statement.strip()
            ))
            sites.append({
                "site": f"{rel(path, root)}:{head.count(chr(10)) + 1}",
                "consumesOutcome": consumed,
                "statementPrefix": statement.strip()[-60:],
            })
    return sites
NOTIFICATION_PREFS = "lib/core/services/notification_preferences_service.dart"
NOTIFICATION_SCREEN = (
    "lib/screens/settings_notifications/notification_categories_screen.dart"
)
SETTINGS_PAGE = "lib/screens/settings_page.dart"


def _notification_surface(root: Path, sites) -> dict:
    """MP-11-014 / MP-23-010 / MP-26-006, computed rather than described.

    The field this replaces asserted that "notification preference toggles live
    in settings". They did not: the settings row opened Android's app-level
    screen, which answers "notifications on or off" and says nothing about which
    of this app's categories the user wants. A sentence is not a measurement.
    """
    service = read_stripped(root / NOTIFICATION_SERVICE) if (root / NOTIFICATION_SERVICE).exists() else ""
    prefs = read_stripped(root / NOTIFICATION_PREFS) if (root / NOTIFICATION_PREFS).exists() else ""
    screen = read_stripped(root / NOTIFICATION_SCREEN) if (root / NOTIFICATION_SCREEN).exists() else ""
    settings = read_stripped(root / SETTINGS_PAGE) if (root / SETTINGS_PAGE).exists() else ""

    categories_block = re.search(r"enum NotificationCategory\s*\{(.*?)\n\}", prefs, re.S)
    categories = ([m.group(1) for m in
                   re.finditer(r"^\s*([a-z][A-Za-z0-9]*)[,;]", categories_block.group(1), re.M)]
                  if categories_block else [])
    channels = sorted(set(re.findall(r"k(\w+)ChannelId", service)))
    safety_critical = re.findall(r"NotificationCategory\.(\w+) => true", prefs)

    # A local switch that can disagree with the OS is the defect this design
    # already rejected once. Assert it stays rejected.
    holds_local_copy = bool(re.search(r"setBool\(.*[Nn]otification", prefs))

    return {
        "notificationSites": len(sites(r"flutter_local_notifications|showNotification")),
        "categories": categories,
        "androidChannels": channels,
        "safetyCriticalCategories": safety_critical,
        "preferenceScreen": NOTIFICATION_SCREEN if screen else None,
        "reachableFromSettings": "NotificationCategoriesScreen" in settings,
        "readsLivePlatformState": "getNotificationChannels" in prefs
                                  and "areNotificationsEnabled" in service,
        "holdsLocalToggleCopy": holds_local_copy,
        "perChannelSettingsDeepLink": "openNotificationChannelSettings" in prefs,
        "postReportsSuppression": "suppressedByUserSetting" in service,
        "postReportsPermissionDenied": "permissionDenied" in service,
        # ENFORCED (alertOutcomeDiscardedAtCallSite): every live call site, with
        # its own verdict -- not a substring over one file.
        "alertCallSites": _alert_call_sites(root),
        "silencedSafetySurfaceWarned": "isSilencedSafetySurface" in screen,
        "tapRoutesThroughDestinationPark":
            "PendingDestinationService.instance.submitDestination" in service,
        "payloadAllowlist": re.findall(r"'(\w+)': AppDestination\.\w+", service),
        "directPushExceptions": len(re.findall(r"navigator\.push\(", service)),
        "coveringTests": ["test/screens/notification_categories_test.dart"],
    }


def measure(root: Path) -> list:
    violations = []
    fields = _fields(root)

    for field in fields:
        # A field with neither a label nor a hint is unlabelled input.
        if not field["hasLabel"] and not field["hasHint"]:
            violations.append({"rule": "unlabelledTextField", "detail": field["site"]})
        # A PIN field must never advertise itself to a password manager or to
        # autofill: this app's whole auth story is a local duress-resistant PIN.
        if field["obscure"] and field["hasAutofillHints"]:
            violations.append({
                "rule": "pinFieldOffersAutofill",
                "detail": f"{field['site']} is obscured AND declares autofillHints",
            })

    # Feedback: an action that mutates state must produce a visible acknowledgement.
    snack = sum(len(re.findall(r"showSnackBar", read_stripped(p))) for p in dart_files(root))
    haptic = sum(len(re.findall(r"HapticFeedback\.", read_stripped(p))) for p in dart_files(root))
    if snack == 0:
        violations.append({"rule": "noVisibleFeedbackChannel", "detail": "no SnackBar anywhere"})
    if haptic == 0:
        violations.append({"rule": "noHapticChannel", "detail": "no HapticFeedback anywhere"})

    # Whitespace normalisation on the fields that feed the dispatch path. A phone
    # number with a stray space is a call that does not connect.
    contact_src = read_stripped(root / "lib" / "screens" / "contacts_page.dart")
    if "trim()" not in contact_src:
        violations.append({
            "rule": "contactInputNotNormalised",
            "detail": "contacts_page.dart never trims user input",
        })

    # MP-11-014 / MP-23-010 / MP-26-006: the notification surfaces.
    def _sites(pattern):
        out = []
        for path in dart_files(root):
            src = read_stripped(path)
            for m in re.finditer(pattern, src):
                out.append(f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
        return out

    notifications = _notification_surface(root, _sites)
    if notifications["notificationSites"]:
        if not notifications["preferenceScreen"]:
            violations.append({
                "rule": "noPerCategoryNotificationSurface",
                "detail": "the app posts notifications with no in-app category "
                          "surface; the OS app-level screen answers a different "
                          "question than 'which of these do I want'",
            })
        if not notifications["reachableFromSettings"]:
            violations.append({
                "rule": "notificationSurfaceUnreachable",
                "detail": "the category screen is not reachable from settings",
            })
        if notifications["holdsLocalToggleCopy"]:
            violations.append({
                "rule": "localNotificationToggleCopy",
                "detail": "a local switch can read ON while Android says OFF, so "
                          "the app promises alerts it cannot deliver",
            })
        if not notifications["readsLivePlatformState"]:
            violations.append({
                "rule": "notificationStateNotReadFromPlatform",
                "detail": "the surface does not ask Android what is actually on",
            })
        if not notifications["postReportsSuppression"]:
            violations.append({
                "rule": "suppressedNotificationLooksLikeSuccess",
                "detail": "posting returns without distinguishing a suppressed "
                          "alert from a delivered one",
            })
        # A typed outcome nobody reads is the same defect one layer out.
        for site in notifications["alertCallSites"]:
            if not site["consumesOutcome"]:
                violations.append({
                    "rule": "alertOutcomeDiscardedAtCallSite",
                    "detail": f"{site['site']} calls showEmergencyAlert and "
                              f"discards the returned outcome, so a suppressed "
                              f"safety alert is indistinguishable from a posted "
                              f"one at that site",
                })
        if not notifications["silencedSafetySurfaceWarned"]:
            violations.append({
                "rule": "mutedSafetyChannelUnflagged",
                "detail": "a muted emergency channel is rendered like a muted "
                          "ordinary one",
            })
        if not notifications["tapRoutesThroughDestinationPark"]:
            violations.append({
                "rule": "notificationTapBypassesGateModel",
                "detail": "a notification tap navigates outside the validated "
                          "destination park, so it can reach a screen ahead of "
                          "the PIN gate",
            })
        if notifications["directPushExceptions"] > 1:
            violations.append({
                "rule": "multipleUngatedNotificationPushes",
                "detail": f"{notifications['directPushExceptions']} direct pushes; "
                          f"exactly one (the named fake-call exception) is allowed",
            })
    return violations


def build(root: Path) -> dict:
    fields = _fields(root)
    counts = Counter()
    for f in fields:
        for k, v in f.items():
            if isinstance(v, bool) and v:
                counts[k] += 1

    def sites(pattern):
        out = []
        for path in dart_files(root):
            src = read_stripped(path)
            for m in re.finditer(pattern, src):
                out.append(f"{rel(path, root)}:{src[: m.start()].count(chr(10)) + 1}")
        return out

    return {
        "componentStates": {
            "textFields": len(fields),
            "withLabel": counts["hasLabel"],
            "withHint": counts["hasHint"],
            "withValidator": counts["hasValidator"],
            "readOnlySites": sites(r"readOnly:\s*true"),
            "enabledFalseSites": sites(r"enabled:\s*false"),
            "disabledMechanism": "a condition yielding null into the callback, plus "
                                 "ThemeData's disabled colours",
            "selectableTextSites": sites(r"SelectableText"),
            "readOnlyVsDisabled": (
                "read-only surfaces (legal texts, exported data preview) use "
                "SelectableText so the content can still be copied; disabled "
                "controls drop their callback and their contrast"
            ),
        },
        "buttonTiers": {
            "primaryFilled": len(sites(r"ElevatedButton")),
            "secondaryOutlined": len(sites(r"OutlinedButton")),
            "tertiaryText": len(sites(r"TextButton")),
            "iconOnly": len(sites(r"IconButton")),
            "ghostTier": (
                "TextButton IS the ghost tier: no fill, no outline, label only. The "
                "app ships three tiers, not four; a separate 'ghost' rung would be a "
                "name for a tier that already exists."
            ),
        },
        "characterLimits": {
            "fieldsWithMaxLength": counts["hasMaxLength"],
            "fieldsWithFormatters": counts["hasInputFormatters"],
            "maxLengthSites": sites(r"maxLength:\s*\d+"),
            "formatterSites": sites(r"LengthLimitingTextInputFormatter"),
            "robustnessTest": "test/core/input_robustness_test.dart",
        },
        "autofill": {
            "fieldsDeclaringAutofillHints": counts["hasAutofillHints"],
            "autofillSites": sites(r"autofillHints:"),
            "deliberatelyAbsentOn": "the PIN fields",
            "why": (
                "CLAUDE.md rule 2 forbids biometric unlock because an attacker can "
                "force a face; a password manager that fills the PIN reintroduces "
                "exactly that class of coerced unlock. The PIN is deliberately the "
                "one credential no other system can supply."
            ),
        },
        "feedbackChannels": {
            "snackBarSites": len(sites(r"showSnackBar")),
            "hapticSites": len(sites(r"HapticFeedback\.")),
            "hapticKinds": sorted(set(re.findall(
                r"HapticFeedback\.(\w+)",
                "".join(read_stripped(p) for p in dart_files(root))))),
            "semanticAnnouncementSites": len(sites(r"SemanticsService\.announce")),
            "channels": ["visual (SnackBar / inline state)", "haptic", "screen-reader announcement"],
            "claim": "every state-changing action acknowledges on at least one channel, "
                     "and the safety-critical ones on all three",
        },
        "notificationFeedback": _notification_surface(root, sites),
        "undo": {
            "undoSites": sites(r"SnackBarAction|undo|Undo"),
            "mechanism": "confirmation-before-destruction rather than undo-after",
            "why": (
                "the destructive actions here erase data the app deliberately keeps "
                "no second copy of (KVKK Md. 11/f). An undo buffer would BE that "
                "second copy, so the guard is placed before the action instead."
            ),
        },
        "validation": {
            "validatorSites": len(sites(r"validator:")),
            "inlineErrorSites": len(sites(r"errorText:")),
            "formKeySites": len(sites(r"GlobalKey<FormState>")),
            "validatorFile": "lib/core/utils/validators.dart",
            "emergencyNumberValidator": "lib/core/utils/emergency_number_validator.dart",
            "placeholderNotUsedAsLabel": {
                "fieldsWithBoth": sum(1 for f in fields if f["hasLabel"] and f["hasHint"]),
                "fieldsWithHintOnly": sum(1 for f in fields if f["hasHint"] and not f["hasLabel"]),
            },
        },
        "keyboardActions": {
            "textInputActionSites": counts["hasTextInputAction"],
            "onSubmittedSites": counts["hasOnSubmitted"],
            "keyboardTypeSites": counts["hasKeyboardType"],
            "imeVisibilityTest": "test/screens/add_contact_keyboard_visibility_test.dart",
        },
        "normalisation": {
            "trimSites": len(sites(r"\.trim\(\)")),
            "digitStripSites": len(sites(r"replaceAll\(RegExp\(r'\\\\D'\)")),
            "phoneNormalisation": "lib/core/utils/emergency_number_validator.dart",
            "why": "a phone number carrying a stray space is a call that does not connect",
        },
        "unsavedChanges": {
            "restorationTest": "test/state_restoration_policy_test.dart",
            "deviceEvidence": "docs/audit/device-verification-2026-08-14-state-restoration.md",
            "preservedAcrossProcessDeath": "unsaved emergency-contact entry",
            "deliberatelyNotPreserved": ["PIN buffers", "destructive confirmation state"],
        },
    }


def _mutate(scratch: Path) -> str:
    target = scratch / "lib" / "core" / "widgets" / "safety_session_pin_gate.dart"
    src = target.read_text(encoding="utf-8")
    assert "obscureText: true" in src, "mutation anchor gone -- the control would be vacuous"
    src = src.replace("obscureText: true", "obscureText: true,\n        autofillHints: const [AutofillHints.password]", 1)
    target.write_text(src, encoding="utf-8")
    probe = scratch / "lib" / "screens" / "_probe_field.dart"
    probe.write_text(
        "import 'package:flutter/material.dart';\n"
        "final w = TextField(controller: TextEditingController());\n",
        encoding="utf-8",
    )
    # MP-11-014 / MP-23-010 / MP-26-006: take the notification surfaces back
    # out -- restore the silent suppression, drop the muted-safety warning, and
    # let a tap push directly past the destination park.
    service = scratch / NOTIFICATION_SERVICE
    if service.exists():
        service.write_text(
            service.read_text(encoding="utf-8")
            .replace("DispatchTargetOutcome.suppressedByUserSetting", "null")
            .replace(
                "PendingDestinationService.instance.submitDestination",
                "_ignoredDestination",
            ),
            encoding="utf-8",
        )
    # FIR-02: put a dropped-outcome call site back. This is the exact shape the
    # substring property could not see -- the alert is posted, the typed result
    # is thrown away, and a suppressed safety warning reads as a delivered one.
    safe_walk = scratch / "lib" / "screens" / "safe_walk_screen.dart"
    if safe_walk.exists():
        src = safe_walk.read_text(encoding="utf-8")
        anchor = "final outcome = await SafetyAlertDispatch.postWarning("
        assert anchor in src, "mutation anchor gone -- the control would be vacuous"
        safe_walk.write_text(
            src.replace(anchor, "SafetyAlertDispatch.postWarning(", 1),
            encoding="utf-8",
        )
    screen = scratch / NOTIFICATION_SCREEN
    if screen.exists():
        screen.write_text(
            screen.read_text(encoding="utf-8").replace(
                "isSilencedSafetySurface", "willBeDelivered == false"
            ),
            encoding="utf-8",
        )
    return ("a PIN field offering password autofill + an unlabelled text field + "
            "notification suppression made silent again + the muted-safety "
            "warning removed + a tap that bypasses the destination park + a "
            "safety-alert call site that discards its typed outcome")


def main() -> int:
    if main_guard(sys.argv):
        return run_negative_control(
            "interaction", _mutate, measure,
            expect_rules=[
                "pinFieldOffersAutofill",
                "unlabelledTextField",
                "suppressedNotificationLooksLikeSuccess",
                "mutedSafetyChannelUnflagged",
                "notificationTapBypassesGateModel",
                "alertOutcomeDiscardedAtCallSite",
            ],
        )
    violations = measure(REPO)
    path = emit(
        "interaction.json",
        verifier="scripts/audit_evidence/interaction.py",
        version=VERSION,
        command=COMMAND,
        surfaces=["lib/screens/**", "lib/widgets/**", "lib/core/widgets/**",
                  "lib/core/utils/validators.dart",
                  "lib/core/utils/emergency_number_validator.dart"],
        measurements=build(REPO),
        violations=violations,
        exclusions=[
            {"what": "the numeric PIN keypad",
             "why": "it is a custom grid of buttons, not a TextField; its behaviour is "
                    "covered by the PIN lockout and duress tests instead"},
        ],
        extra={"negativeControl": {
            "command": COMMAND + " --negative-control",
            "mutation": "give the PIN field password autofill; add an unlabelled "
                        "field; make notification suppression silent again; "
                        "remove the muted-safety warning; let a notification tap "
                        "bypass the destination park; drop the typed outcome at "
                        "the Safe Walk alert call site",
            "expected": "6 violations, asserted PER RULE: pinFieldOffersAutofill, "
                        "unlabelledTextField, suppressedNotificationLooksLikeSuccess, "
                        "mutedSafetyChannelUnflagged, "
                        "notificationTapBypassesGateModel and "
                        "alertOutcomeDiscardedAtCallSite",
        }},
    )
    print(f"INTERACTION_OK violations={len(violations)} -> {rel(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
