# Real-Device QA Worksheet & Evidence Matrix

Status: NEEDS_REAL_DEVICE_TEST. Runtime/device execution is not evidenced from this repo. Emulator output, adb-only output, static review, Play Console assumptions, and RevenueCat assumptions are not production evidence.

Every scenario remains not-run until an operator records physical-device evidence in the Evidence log (§5). Redact phone numbers, precise coordinates, account emails, order IDs, screenshots with PII, and any sensitive logs before sharing evidence.

> ⚠️ **Run device QA on the SIGNED RELEASE AAB** (internal-testing track): debug builds skip
> R8/obfuscation, so keep-rule regressions (receiver names, MethodChannel) only show in release.
> Never place a real emergency call; use the second test phone as the emergency contact.

This worksheet is the execution and evidence companion of
[MANUAL_SMOKE_TEST_SCRIPT.md](MANUAL_SMOKE_TEST_SCRIPT.md) (same expectations, condensed) and
covers all eight device-only proof items of `docs/HANDOVER.md` §11 — see the mapping in §4.

## 1. Device pool (minimum)

| Column | Device class | Target Android | Why this device |
| --- | --- | --- | --- |
| PIX | Stock Android / Google Pixel | Android 15 | Reference (un-skinned) behavior |
| SAM | Samsung (One UI) | Android 14 | OEM battery management, lock-screen notification skinning |
| XIA | Xiaomi (MIUI/HyperOS) | Android 13 | Most aggressive app-kill / autostart policies |

Together the pool must cover Android 13, 14, and 15 (at least one device per major version).
If the available device runs a different version, record the actual model/OS/build in the
Evidence log; the column mapping stays the same.

Cell legend: `☐P ☐F` = mark P (passed) or F (failed) after the run; `—` = not applicable on
that device; "1 device" in Notes = running it on a single device is enough.

## 2. Recommended run order (per device)

Run phases in this order on EACH device. **Destructive steps — permission revoke, force-stop,
data wipe — always come LAST (Phase 8):** they invalidate install state, and anything executed
after them on the same install is not clean evidence.

1. **Phase 0 — fresh install & guards:** A1 → A2 → **A3 (empty-target guard, BEFORE any contact is configured)**.
2. **Phase 1 — contacts & target validation:** B1 → B2 → B3 → B4 → B5.
3. **Phase 2 — emergency call paths (prompt-level permission states):** C1 → C2 → C3 → C4.
4. **Phase 3 — sessions & timers:** D1 → D6.
5. **Phase 4 — notifications & locale:** E1 → E6.
6. **Phase 5 — Doze / OEM reliability:** F1 → F4.
7. **Phase 6 — maps & extras:** H1 → H4, I1 → I4. (A4 legal URLs anytime; K video on the best-looking device.)
8. **Phase 7 — billing (license-tester device only):** J1 → J7.
9. **Phase 8 — DESTRUCTIVE, in this order:** G1 (reboot, active) → G2 (reboot, expired) →
   G3 (exact-alarm revoke mid-session) → G4 (force-stop + formatted number + BAL) →
   G5 (CALL_PHONE revoke + force-stop tour) → G6 (force-stop dedup race) →
   G7 ("Delete my data" wipe) → G8 (reinstall + billing restore).

## 3. Scenario catalog + per-device matrix

### A — Fresh install, guards, legal

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | NEEDS_REAL_DEVICE_TEST | App launch (signed build) | Install signed internal-testing AAB; open app | Reaches consent/onboarding/unlock or home without crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| A2 | NEEDS_REAL_DEVICE_TEST | Consent/onboarding | Complete required legal consent and onboarding | Consent recorded locally; main navigation entered | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| A3 | NEEDS_REAL_DEVICE_TEST | Empty emergency target fail-safe | With NO emergency contact configured, try to arm Panic, Check-In, and Safe Walk; in a controlled setup force an empty persisted target and run a test flow | Arming is blocked with visible "add a contact" guidance; a forced empty-target dispatch fails VISIBLY (blocking full-screen fail-safe); never falls back to `112`; no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/7; run BEFORE adding contacts |
| A4 | NEEDS_OPERATOR_ACTION | Legal URLs open | Open Privacy, Terms, Data deletion, and Aydınlatma links from the app | Each live URL opens the expected page; save URL+date screenshot per link | ☐P ☐F | — | — | 1 device |
| A5 | NEEDS_REAL_DEVICE_TEST | Consent re-prompt after legal version bump | In a controlled build with a bumped legal version, update and open | Required consent is re-prompted and recorded locally | ☐P ☐F | — | — | 1 device; before production if legal version changes |

### B — Contacts & target validation

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| B1 | NEEDS_REAL_DEVICE_TEST | Contacts picker select | Pick a test contact via the system picker (ACTION_PICK) | Only the selected contact is stored locally; no READ_CONTACTS prompt appears | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| B2 | NEEDS_REAL_DEVICE_TEST | Contacts picker cancel | Open picker, cancel | App returns without error; nothing stored | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| B3 | NEEDS_REAL_DEVICE_TEST | Manual contact entry | Enter name and phone manually | Contact saves locally; selectable as emergency contact | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| B4 | NEEDS_REAL_DEVICE_TEST | Short-code target rejection | Try to enter/select `112` (or another official short code) as the emergency number | Rejected as a callable target (only 7–15 digit user numbers are callable); short codes can NEVER become auto-call targets; legal copy still tells the USER to dial 112 themselves | ☐P ☐F | ☐P ☐F | ☐P ☐F | Replaces the stale "112 is accepted" row; see HANDOVER §2.1 |
| B5 | NEEDS_REAL_DEVICE_TEST | Formatted-number save via picker (audit F5, part 1) | Via ACTION_PICK save the second test phone whose contact number is stored formatted as `(0555) 010-20-30`; set it as primary | Contact saves; number is normalized/dialable from the app (the Dart-dead proof is G4) | ☐P ☐F | ☐P ☐F | ☐P ☐F | |

### C — Emergency call paths (test-safe number = second test phone)

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C1 | NEEDS_REAL_DEVICE_TEST | Emergency CALL_PHONE granted direct path | Grant CALL_PHONE; start SOS/countdown from an explicit user action | Direct call is attempted only after the explicit user flow and permission grant; no background/autonomous call | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| C2 | NEEDS_REAL_DEVICE_TEST | CALL_PHONE denied ACTION_DIAL fallback | Deny CALL_PHONE at the runtime prompt; start countdown | Dialer opens pre-filled; copy says the user must press the call button manually | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| C3 | NEEDS_REAL_DEVICE_TEST | Native direct call failure fallback | Where safely forceable, make the native direct-call dispatch fail | Fallback opens ACTION_DIAL **for the user's target number** or surfaces a visible failure; never `112` | ☐P ☐F | ☐P ☐F | ☐P ☐F | Fixes stale "ACTION_DIAL for 112" wording; HANDOVER §2.1 |
| C4 | NEEDS_REAL_DEVICE_TEST | No SIM / airplane mode | Enable airplane mode or remove SIM; start SOS with the test-safe number | Visible dialer/manual/failure state; app never silently fails; no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | |

### D — Sessions & timers (Pro active)

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | NEEDS_REAL_DEVICE_TEST | Safe Walk start/check-in/expiry/cancel | Start, check in, cancel; separately run the expiry path | Session is user-visible, cancellable, clears state, escalates only through the expected flow on expiry | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| D2 | NEEDS_REAL_DEVICE_TEST | Check-In start/grace/expiry/cancel | Start timer, enter grace, expire; repeat with cancel/reset | Grace and expiry are visible; "I'm safe" in grace is a single PIN-less tap; state clears correctly | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| D3 | NEEDS_REAL_DEVICE_TEST | Countdown cancel & PIN gate | Start panic countdown; cancel with PIN (and once with no PIN set) | PIN required when set (wrong PIN hits exponential lockout); one-tap cancel when no PIN is defined | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| D4 | NEEDS_REAL_DEVICE_TEST | Single-dispatch dedup (Dart alive) | Start countdown, keep app foreground, let it fire | Exactly ONE call; the +12s native backup is cancelled; no duplicate call within the backup window | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/3 (in-app half; force-stop race is G6) |
| D5 | NEEDS_REAL_DEVICE_TEST | Exact alarm allowed | With exact-alarm access granted start Safe Walk, Check-In, countdown backup | No degraded warning; timer scheduling succeeds | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| D6 | NEEDS_REAL_DEVICE_TEST | Exact alarm denied/default-denied | Fresh install with exact alarm denied (Android 14 default-deny); start safety timers | Degraded copy shown; inexact fallback used where possible; no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | Mid-session revoke is G3 |

### E — Notifications & locale

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E1 | NEEDS_REAL_DEVICE_TEST | Notification allowed | Allow notifications; start Safe Walk or Check-In; background the app and lock the screen | Persistent safety-session notification is visible (incl. lock screen) and names the active session | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| E2 | NEEDS_REAL_DEVICE_TEST | Notification denied | Deny notification permission; start a session | App explains reduced timer reliability/visibility; no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| E3 | NEEDS_REAL_DEVICE_TEST | FGS notification content (A14/15) | Start a session, background the app | Foreground-service notification clearly names the active safety session | ☐P ☐F | ☐P ☐F | — | |
| E4 | NEEDS_REAL_DEVICE_TEST | FGS stop/cancel | Cancel / check in / end session | Timer stops; persistent notification clears | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| E5 | NEEDS_REAL_DEVICE_TEST | Grace heads-up visible | Let the main timer expire with the app backgrounded | HIGH-importance heads-up grace warning appears (no full-screen intent is declared — heads-up is the expected form), with DnD bypass and vibration | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| E6 | NEEDS_REAL_DEVICE_TEST | Turkish notification on English system locale (audit F8) | Set the device SYSTEM LANGUAGE to English; start Check-In; lock the screen; let the main timer expire | The lock-screen emergency/grace notification text appears in TURKISH; actions still work | ☐P ☐F | ☐P ☐F | ☐P ☐F | |

### F — Doze / OEM reliability

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| F1 | NEEDS_REAL_DEVICE_TEST | Battery optimization not exempted | Without the exemption, start a safety timer and background the app | App explains the optional reliability improvement and the degraded behavior; works degraded | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| F2 | NEEDS_REAL_DEVICE_TEST | Doze/app-kill: countdown native backup fires | Start countdown; background + screen off (Doze; `adb shell cmd deviceidle force-idle` may TRIGGER the state, but evidence is the observed call, not adb output) | The native backup call is actually placed to the test-safe number | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/1 |
| F3 | NEEDS_REAL_DEVICE_TEST | Doze/app-kill: check-in & safe-walk native escalation fires | Same as F2 for Check-In and Safe Walk expiry | Native escalation calls ONLY the primary contact; visible afterwards | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/1 |
| F4 | NEEDS_REAL_DEVICE_TEST | OEM-kill survival | On Samsung/Xiaomi default aggressive battery settings, run a 10+ min session in background | Alarm/FGS survives and fires on time, OR the degraded warning was honestly shown beforehand | — | ☐P ☐F | ☐P ☐F | HANDOVER §11/4 |

### G — DESTRUCTIVE (always LAST on each device, in this order)

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| G1 | NEEDS_REAL_DEVICE_TEST | Boot restore (active timer) | Start an active timer; reboot; unlock; reopen app | Active/expired state restored or surfaced honestly. Direct Boot limit (FRESH_AUDIT F4): nothing fires before the FIRST unlock — expected, record it | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/2 |
| G2 | NEEDS_REAL_DEVICE_TEST | Boot restore (expired session) | Let main+grace expire across a reboot; unlock | After first unlock the native call to the PRIMARY contact is placed (not just a notification) | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/2 |
| G3 | NEEDS_REAL_DEVICE_TEST | Exact alarm revoked mid-session | Revoke exact-alarm access while timers are active | Degraded warning; inexact fallback; timers continue (possibly delayed); no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/5 |
| G4 | NEEDS_REAL_DEVICE_TEST | Dart-dead native call with formatted number + BAL visibility (audit F5) | Primary = B5 contact saved as `(0555) 010-20-30`; start Check-In (shortest); FORCE-STOP the app; let main+grace expire | Native backup dials the CORRECT normalized number (verify the ringing number on the second phone). The receiver-launched call/dialer screen is VISIBLE on the device (Background-Activity-Launch check): `startActivity` returning without exception does NOT prove the UI was shown — confirm by eye | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| G5 | NEEDS_REAL_DEVICE_TEST | Dispatch-failure fail-safe tour (audit F1) | With a session active: revoke CALL_PHONE in settings → force-stop the app → let main+grace expire. Run across Android 13/14/15 devices | "Call manually" notification appears with the CORRECT number; content visible on the lock screen. Tap **7304** (countdown failure): dialer opens with the number PRE-FILLED, WITHOUT passing the app/PIN gate. Tap **7303** (check-in): app opens; observe the restore/retry flow; with the app PIN lock enabled, record whether the automatic retry is blocked at the PIN gate | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/8 |
| G6 | NEEDS_REAL_DEVICE_TEST | Dedup race under force-stop | Force-stop right around expiry; let native fire; reopen the app (Dart resume) | Exactly ONE call in total; on resume Dart skips its own call (ALARM_FIRED = native dispatch succeeded); failure is never silently swallowed | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/3 (device-race half) |
| G7 | NEEDS_REAL_DEVICE_TEST | "Delete my data" native wipe | Run full data deletion from the app; then probe behaviorally | Native `korubeni_emergency` prefs are empty: no stale primary number anywhere; arming demands re-adding a contact; no expiry path can ever call the OLD number | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/6 |
| G8 | REVENUECAT | Reinstall + billing restore | Reinstall/clear data; tap restore | Active tester purchase restores Pro, or the no-purchase state is explicit | ☐P ☐F | — | — | 1 device (license tester); PLAY_CONSOLE also required |

### H — Maps & location

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| H1 | NEEDS_REAL_DEVICE_TEST | Location allowed | Allow location; open map | Real location appears only after permission; attribution visible | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| H2 | NEEDS_REAL_DEVICE_TEST | Location denied | Deny location; open map | Clear fallback; no fake coordinates | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| H3 | NEEDS_REAL_DEVICE_TEST | Offline map/network failure | Disable network or block the tile provider; open map | Offline fallback is clear, localized, no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| H4 | NEEDS_REAL_DEVICE_TEST | OSM attribution visible | Open every map surface online | `OpenStreetMap contributors` attribution is visible | ☐P ☐F | ☐P ☐F | ☐P ☐F | |

### I — Extras

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| I1 | NEEDS_REAL_DEVICE_TEST | Fake call immediate | Start an immediate fake call | Fake call UI appears; no real call placed | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| I2 | NEEDS_REAL_DEVICE_TEST | Fake call scheduled | Schedule a fake call | Scheduled fake-call notification/UI appears; no real call placed | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| I3 | NEEDS_REAL_DEVICE_TEST | Siren max volume and restore | Record the starting alarm volume; start/stop siren | Siren uses alarm volume; original volume restored | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| I4 | NEEDS_REAL_DEVICE_TEST | Volume-button panic foreground-only | Press the trigger sequence in foreground and background | Triggers in foreground only; background never triggers a hidden SOS | ☐P ☐F | ☐P ☐F | ☐P ☐F | |

### J — Billing (license-tester device; 1 device is enough)

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| J1 | REVENUECAT | Billing license tester purchase | Purchase monthly and annual products | Entitlement activates after purchase | ☐P ☐F | — | — | PLAY_CONSOLE also required |
| J2 | REVENUECAT | Billing cancel/manage | Open manage subscription / customer center | Manage/cancel path opens Google Play/RevenueCat safely | ☐P ☐F | — | — | |
| J3 | REVENUECAT | Billing expired/lapsed | Let the sandbox subscription expire/lapse; refresh app | Pro access removed; paywall/no-entitlement copy appears | ☐P ☐F | — | — | |
| J4 | REVENUECAT | Billing renewal/lapse cycle | Observe a sandbox renewal and lapse cycle | Entitlement follows sandbox state | ☐P ☐F | — | — | |
| J5 | REVENUECAT | Billing account hold/paused | Trigger the available sandbox state | Non-active entitlement handled without crash | ☐P ☐F | — | — | If available in sandbox |
| J6 | REVENUECAT | No-offering fallback | With a controlled no-offering dashboard/build state, open the paywall | Fallback/retry UI appears; no crash | ☐P ☐F | — | — | |
| J7 | REVENUECAT | Billing network failure | Open paywall/purchase/restore while offline | Sanitized error appears; no secret/error dump | ☐P ☐F | — | — | Restore itself is G8 |

### K — Play declaration video

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| K1 | PLAY_CONSOLE | FGS demo video capture | Record per the canonical shot list: [docs/play-submission.md §1 → "Demo video — shot list"](../docs/play-submission.md) | Video shows user-started, visible, time-bound, cancellable behavior; no PII | ☐P ☐F | — | — | 1 device; redacted video for Play Console only |

## 4. HANDOVER §11 coverage map

| §11 item (device-only proof) | Worksheet rows |
| --- | --- |
| 1. Native backup call actually fires under Doze/app-kill (countdown + check-in/safe-walk) | F2, F3 |
| 2. Boot-restore expired-session native call | G1, G2 |
| 3. Dedup race (Dart resume ↔ native fire) | D4, G6 |
| 4. OEM-kill (Xiaomi/Samsung) FGS + alarm survival | F4 |
| 5. Exact-alarm denial → degraded inexact + user warning | D6, G3 |
| 6. "Delete my data" → native `korubeni_emergency` really emptied | G7 |
| 7. Empty-target fail-safe visible/blocking on device | A3 |
| 8. Dispatch-failure fail-safe tour (F1): manual-call notification, 7304/7303 tap paths, lock screen, BAL visibility | G5 (+ G4 for the BAL eye-check) |

Post-audit additions requested after FRESH_AUDIT: F5 formatted-number normalization (B5 + G4),
F8 Turkish notification under English system locale (E6), 7304/7303 notification tap paths (G5),
receiver-launched call screen visibility / BAL (G4, G5).

## 5. Evidence log (append-only)

Append one row per executed scenario per device. Keep evidence filenames here; do not store
screenshots containing real phone numbers, real precise locations, account emails, or purchase
IDs in the repo.

| Gate | Device | Android version | Build version | Track | Preconditions | Scenario | Steps | Expected | Actual | Pass/Fail | Evidence file | Tester | Date | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | | | | | | |
