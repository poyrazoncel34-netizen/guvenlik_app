# Device Round-2 Investigation (v1.0.2 — Samsung, real device)

> READ-ONLY research. No app code/config changed. This file is the only write.
> Method: ≥2 rival hypotheses per symptom with confidence %, each claim backed by
> (a) current code `file:line` **and** (b) the FAZ-2 commit diff; Android-platform
> claims backed by primary sources only (developer.android.com / api.flutter.dev).

## Confidence legend
H = hypothesis. Confidence is my probability it is the dominant cause. Updated as
evidence arrives; change notes inline.

---

## SHARED ROOT CAUSES (found by cross-symptom analysis)

- **SRC-1 — Android 15 edge-to-edge enforcement (targetSdk 35) + explicit opt-in.**
  `android/app/build.gradle.kts:86 targetSdk = 35`; `lib/main.dart:194
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`. Primary source
  (developer.android.com/about/versions/15/behavior-changes-15): *"Apps are
  edge-to-edge by default on devices running Android 15 if the app is targeting
  Android 15 (API level 35)… portions of your app may be obscured and you must
  handle insets."* → Any full-screen Scaffold without a bottom `SafeArea`/inset
  draws content behind the gesture nav bar. **Drives D1(a).** FAZ-2 `514cf63`
  fixed *modal sheets* but not full-screen scaffolds like the paywall.

- **SRC-2 — Exact-alarm denial (Android 13+) + no inexact fallback in the
  fake-call path.** Drives **D7**, and **D6 is largely a misread of D7** (consent
  actually applies; the fake call still fails for D7 reasons).

- **SRC-3 — Consent gate reads the in-memory singleton cache, same object the
  toggle writes.** This *refutes* the "write-store ≠ read-store" regression
  hypothesis for D6 (see D6).

- **SRC-4 — One-shot connectivity read + change-only stream.** `ConnectivityService`
  sets `_isOnline` once at startup and only updates on a *change* event; a wrong
  initial offline read sticks. Drives **D5** residue even though the none-based
  fix landed.

---

## D5 — Offline strip shows on Wi-Fi (Settings + Home)

**FAZ-2 fix status:** LANDED but INSUFFICIENT.
`git show e641c09` changed `_hasConnection` → `isOnlineFromResults` (none-based:
`if (results.isEmpty) return false; return results.any((r) => r != none)`), and
removed the app-wide `OfflineBanner` from `main.dart`. Current code matches:
`lib/core/services/connectivity_service.dart:44-59`. Only one banner remains:
`ConnectivityBanner` (`lib/widgets/connectivity_banner.dart`, mounted at
`lib/screens/main_navigation.dart:139`).

**Contradiction:** With the none-based fix, `[wifi]` → online → banner hidden.
Yet the device shows the orange "Çevrimdışı Mod" strip on Wi-Fi. The code says
"hidden on Wi-Fi"; the device says "shown." Which is more reliable? The code is
deterministic, so the device proves the *input* (`checkConnectivity()` result)
isn't `[wifi]`, or the banner is stuck.

- **H5a — Stuck initial-offline read (no self-correction). conf 60%.**
  `connectivity_service.dart:23-42`: `initialize()` runs ONE
  `checkConnectivity()` → sets `_isOnline`; then `onConnectivityChanged` only
  emits when `online != _isOnline` (a *change*). `connectivity_banner.dart:37-52`
  seeds `_isOffline = !isOnline` once and only updates on `onStatusChange`. So if
  the cold-start `checkConnectivity()` returns a non-online value (e.g. `[none]`
  or `[]`) while Wi-Fi is actually up, `_isOnline=false`; because the real link
  never *changes*, no correction event fires → banner stuck offline. `initialize()`
  IS awaited before `runApp` (`main.dart:126` inside `Future.wait`), so this is a
  cold-start value/timing issue in the plugin, not a missing call.
- **H5b — Empty-list mapped to offline. conf 30%.** My own `e641c09` decided
  `results.isEmpty → offline`. If `connectivity_plus 6.1.5` (pubspec.lock) ever
  emits `[]` transiently on this device, the banner flips offline. Fail-closed is
  the wrong default for an *informational* banner on an offline-first app.
- **H5c — A second banner source. conf 5% (REFUTED).** grep of
  `offline_banner_text`/"Çevrimdışı Mod" shows only `connectivity_banner.dart`;
  `OfflineBanner` deleted in `e641c09`.

**Root cause (most likely):** SRC-4 — wrong/early cold-start `checkConnectivity()`
value with no re-validation. **Verdict: NOT fully fixed by FAZ-2.**
**Suggested fix (do not apply):** re-run `checkConnectivity()` on
`AppLifecycleState.resumed` and push the result; treat empty/unknown as ONLINE
(fail-open for the banner); optionally seed the banner from a fresh check each
mount. **Rule/Play risk:** none.

---

## D6 — Feature (e.g. fake call) still fails AFTER granting consent (claimed regression)

**FAZ-2 diffs:** `9b66d11` (isolated SharedPreferences consent store +
migration) and `7ac0728` (surface storage errors).

**Primary hypothesis to test (prompt): write-store ≠ read-store.**
- Toggle writes: `consent_management_screen` → `_cm.grantConsent(type)` where
  `_cm = serviceLocator<ConsentManager>()`. `grantConsent` sets
  `_consentCache[type]=true` AND persists.
- Gate reads: `ConsentGateService.requireConsent` → `_isGranted` →
  `serviceLocator<ConsentManager>().isGranted(type)` → reads `_consentCache[type]`
  (`lib/core/services/consent_gate_service.dart:22-33,66-74`).
- `ConsentManager` is a single registered singleton, `initialize()`d at startup
  (`lib/core/di/service_locator.dart:50-53`).
→ **The gate reads the SAME in-memory cache the toggle writes (same instance).**
The SharedPreferences store (`9b66d11`) is only the persistence backing, read once
at init; runtime gating never reads the store directly. **Write≠read regression:
REFUTED. conf that this is NOT the bug: 85%.**
Consent type strings are consistent: `ConsentRecord.typeFakeCall == 'fake_call'`
(`lib/models/consent_record.dart:14`); `fake_call_screen.dart:147` grants the same
literal `'fake_call'`. No string mismatch.

- **H6a — D6 is a misread of D7. conf 70%.** The user's example is the fake call.
  Consent DOES apply (cache), the gate passes, but the call still fails for D7
  reasons (exact alarm / no auto-launch). The user attributes it to consent.
- **H6b — Genuine consent regression. conf 15%.** Would require two
  ConsentManager instances or store-not-loaded; refuted above (singleton, init at
  startup; G6 persistence test passed in FAZ-2).
- **H6c — Discoverability trap (separate, real, but not "after granting"). conf
  10%.** `fake_call_screen.dart:55-71` runs `requireConsent` BEFORE
  `_checkFirstUseWarning` (which grants `'fake_call'`), so the first-use dialog
  can never grant on a cold first use; fake-call consent can only be granted via
  onboarding opt-in or the buried consent-management screen. Not the reported
  symptom (user said "after granting"), but worth noting.

**Root cause:** D6 ≈ D7 for the fake-call case; consent runtime path is sound.
**Verdict: NOT a regression.** **Suggested device check:** toggle
location/contacts consent and confirm those features enable *in the same session*
(validates the cache path for all types). **Rule/Play risk:** none (KVKK path
intact).

---

## D7 — Fake call "in 1 minute" still doesn't fire / doesn't appear

**FAZ-2 fix status:** LANDED but INSUFFICIENT (two compounding platform gaps).
`git show da1550d`: `inexactAllowWhileIdle → exactAllowWhileIdle` and added
`confirmExactAlarmPermissionOrDegraded(context)` before scheduling. Current code:
`lib/core/services/notification_service.dart` `scheduleFakeCall` uses
`AndroidScheduleMode.exactAllowWhileIdle`, wrapped in `try { … return true } catch
(_) { return false }`; **no inexact fallback, no `fullScreenIntent`.**
`home_page._scheduleDelayedFakeCall` calls the guard.

- **H7a — Exact-alarm permission denied → SecurityException → schedule fails.
  conf 70%.** PRIMARY SOURCE
  (developer.android.com/about/versions/14/changes/schedule-exact-alarms):
  *"SCHEDULE_EXACT_ALARM … no longer being pre-granted to most newly installed
  apps targeting Android 13 and higher (will be set to denied by default)."* and
  *"The SCHEDULE_EXACT_ALARM permission is required to initiate exact alarms via …
  setExactAndAllowWhileIdle() … or a SecurityException will be thrown."* The
  guard's "continue degraded" path returns true but still schedules with
  `exactAllowWhileIdle` (no permission) → SecurityException → `catch (_) → false`
  → no call. Unlike check-in/safe-walk, the fake-call path has **no native inexact
  fallback** (`setAndAllowWhileIdle`). On the Samsung (Android 13/14/15) this is
  the dominant failure.
- **H7b — Fires, but only as a notification (no auto-launch). conf 20%.** No
  `fullScreenIntent`; tapping the heads-up notification opens `FakeCallScreen`
  (`notification_service` `_handleNotificationResponse`). Auto-launching a call
  screen needs `USE_FULL_SCREEN_INTENT`, which PRIMARY SOURCE
  (developer.android.com/about/versions/14/behavior-changes-14): *"For apps
  targeting Android 14 … apps that are allowed to use this permission are limited
  to those that provide calling and alarms only. The Google Play Store revokes
  default USE_FULL_SCREEN_INTENT permissions for any apps that don't fit this
  profile."* So even if added, it is denied by default and the user expectation
  ("a call appears") is not met.
- **H7c — Samsung battery optimization defers it. conf 10%.** Secondary even when
  exact is granted; OEM kill is device-only to prove.
- **H7d — Consent gate blocks it (D6 link). conf <5%.** `home_page:590`
  `requireConsent(typeFakeCall)` gates the options sheet; if granted, passes. Not
  the cause once consent is given.

**USE_FULL_SCREEN_INTENT (research only, do NOT add):** would require (1) Play
policy justification (calling/alarm category), (2) runtime check
`NotificationManager.canUseFullScreenIntent()` + prompt via
`ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`, (3) graceful degrade to heads-up when
not granted. High Play-review risk for a "fake call" feature.

**Root cause:** exact-alarm denied-by-default + no inexact fallback (primary);
secondarily notification-only UX. **Verdict: NOT fully fixed.**
**Suggested fix (do not apply):** give the fake-call path the SAME degraded path
as check-in (fall back to an inexact alarm when exact is unavailable) OR actually
drive the user to grant exact-alarm access and confirm before promising a call;
set expectation that it is a notification, not an auto-launched screen.
**Rule/Play risk:** adding FSI is Play-policy-sensitive — research only.

---

## D4 — Invalid / 19-digit number still saved ("Manuel kaydet")

**FAZ-2 fix status:** inline validator LANDED. `git show c6d3010`: phone
`TextField` → `TextFormField` with `autovalidateMode.onUserInteraction`,
`FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))`, and a `validator` backed by
new top-level `manualContactPhoneError()`.

**Contradiction:** the code REJECTS a manual >15-digit number, yet the device adds
it.
- `manualContactPhoneError` and `_addManualContact` both call
  `normalizePhoneNumber` + `EmergencyNumberValidator.isCallableEmergencyTarget`
  (`contacts_page.dart:954-959`). `EmergencyNumberValidator` accepts only 7–15
  digits (`emergency_number_validator.dart:6-13`). `normalizePhoneNumber` does NOT
  truncate (`contact_service.dart:11-17`: strips non-`[\d+]`, no length cut). So
  19 digits → `isCallableEmergencyTarget == false`.
- BOTH manual save paths route through `_addManualContact`: the "Manuel kaydet"
  `OutlinedButton` (`contacts_page.dart:907-914`) and `onFieldSubmitted`
  (`:896-902`) pop `_AddContactSheetResult.manual`, handled at `:928-929`. So a
  true manual 19-digit entry is rejected with the "invalid" snackbar.

- **H4a — Validation gap is in OTHER add paths, not "Manuel kaydet". conf 55%.**
  `ContactsProvider.addContact` (`contacts_provider.dart:91-105`) validates only
  empty / duplicate / limit — **NOT length.** The device-picker path
  `_pickContactFromDevice` (`contacts_page.dart` ~1035) only checks
  `phone.isEmpty`, not the 7–15 range. So a long number from the **picker** is
  added unchecked. The user may have used the picker, or the validation is simply
  not centralized.
- **H4b — Misattribution. conf 30%.** The "invalid" SnackBar is transient; the
  contact shown in the list may be an earlier valid add. Needs exact repro.
- **H4c — Build under test lacked c6d3010. conf 15%.** v1.0.2 = merge `1f4062e`
  includes c6d3010 and the pre-existing submit check, so unlikely — unless a
  non-tag/local build was tested.

**Which side is more reliable?** The code is deterministic and exhaustive (only 2
`addContact` callers; both manual routes validate). I lean that the *manual* path
already rejects; the real, fixable gap is the **missing length check in
`ContactsProvider.addContact` (single chokepoint) and the picker path.**
**Suggested fix (do not apply):** enforce `isCallableEmergencyTarget` inside
`ContactsProvider.addContact` so every path is covered; re-verify on device with
exact steps (which button, list state before). **Rule/Play risk:** none.

---

## D3 — "Yeni Kişi Ekle": keyboard covers the phone field

**FAZ-2 fix status:** `514cf63` did NOT touch this sheet. `git show 514cf63 --stat`
= `pin_settings_helper.dart` (showPinChangeSheet) + `contacts_page.dart`
(`_showEmergencyPicker`). The "Yeni Kişi Ekle" sheet is `_showAddContactSheetFlow`,
which already used the reference pattern: `isScrollControlled: true` +
`SingleChildScrollView(padding: viewInsets.bottom …)` (`contacts_page.dart:759-766`).
So FAZ-1's "this is the correct reference" was right — it is a SEPARATE code path
from the sheets fixed in 514cf63.

- **H3a — Auto-scroll-to-focused-field insufficient. conf 50%.** The phone
  `TextFormField` (`:877`) sits mid-content (handle, 70px icon, title, subtitle,
  divider, "Rehberden Seç" button, name field, THEN phone field, THEN "Manuel
  kaydet" button). The `viewInsets.bottom` padding adds scroll room, and Flutter's
  `EditableText` calls `Scrollable.ensureVisible` on focus — but with tall content
  and a trailing button, the field may land at/just behind the keyboard top. The
  pattern handles *clipping* (you can scroll) but does not guarantee the focused
  field is lifted fully above the IME.
- **H3b — Works; user didn't scroll. conf 35%.** Content IS scrollable; the field
  may be reachable by dragging. Device check needed: can you scroll the field into
  view?
- **H3c — Same as the 514cf63 sheets (missing isScrollControlled). conf 5%
  (REFUTED).** It already has it.

**Root cause (likely):** missing explicit ensure-focused-field-visible for a tall
sheet (not a missing-isScrollControlled bug). **Verdict: separate code path; FAZ-2
did not and was not meant to touch it.** **Suggested fix (do not apply):** reduce
sheet height (collapse hero/icon) and/or trigger `Scrollable.ensureVisible` on the
phone field's focus. **Rule/Play risk:** none.

---

## D2 — Screenshot comes out BLACK

**FAZ-2 fix status:** `ebb7dac` correctly REMOVED the app-wide `FLAG_SECURE` from
`MainActivity`. grep over `android/` + `lib/` for `FLAG_SECURE`/secure-window/
window-manager plugins = **empty** → no FLAG_SECURE anywhere (no regression, no
plugin re-adds it).

- **H2a — AppPrivacyShield masks on `inactive`. conf 80%.**
  `lib/core/widgets/app_privacy_shield.dart:24-28` sets the black mask when
  `state == AppLifecycleState.inactive || hidden || paused || detached`. PRIMARY
  SOURCE (api.flutter.dev AppLifecycleState): `inactive` = *"At least one view of
  the application is visible, but none have input focus,"* examples include *"a
  system dialog, … split screen, … interrupted by a phone call, picture-in-
  picture."* i.e. it fires **while the app is still visible**, for transient
  focus-loss — which on Samsung includes the screenshot-capture/overlay flow. The
  mask becomes opaque at capture → black screenshot. `paused` = *"not currently
  visible"* (true background).
- **H2b — Residual FLAG_SECURE. conf 5% (REFUTED).** grep empty.
- **H2c — Samsung-specific capture overlay. conf 15%.** OEM screenshot toolbar
  triggers the focus loss → `inactive`. Same fix applies.

**Root cause:** masking on `inactive` (and `detached`) is too broad. **Verdict:
FLAG_SECURE removal was correct; the SEPARATE privacy-shield mask is the cause.**
**Suggested fix (do not apply):** mask only on `paused`/`hidden` (true background)
— this still blanks the recents/app-switcher thumbnail (it routes through
paused/hidden) while leaving screenshots and transient dialogs untouched.
**Rule/Play risk:** none; minor privacy nuance — recents thumbnail is still
protected via paused/hidden.

---

## D1 — Paywall: bottom links under nav bar (a) + "Plan bilgileri alınamıyor" (b)

**(a) Layout under the gesture nav bar — REAL bug. conf 90%.**
`lib/screens/subscription/paywall_screen.dart:103-147`: `Scaffold(body: ListView(
padding: EdgeInsets.all(20), children: [ … _buildLegalLinks(), _buildRestoreButton(),
footer Text ]))` — **no bottom `SafeArea`/inset.** With SRC-1 (edge-to-edge,
targetSdk 35, `setEnabledSystemUIMode(edgeToEdge)`), the trailing footer/links draw
behind the gesture nav bar. NOT touched by FAZ-2 (514cf63 only fixed sheets).
- Rival H: it's a fixed-height overflow — REFUTED, it's a ListView (scrolls);
  the issue is the last item sitting under the nav inset, classic edge-to-edge.
**Suggested fix (do not apply):** add bottom inset (e.g. `SafeArea` or
`EdgeInsets.only(bottom: viewPadding.bottom + 20)` on the ListView). Same class of
fix likely needed on other full-screen scaffolds — audit recommended.

**(b) "Plan bilgileri şu an alınamıyor" — EXPECTED, not a bug. conf 90%.**
`paywall_screen.dart:114-115` shows `_buildPlansUnavailableCard` when
`!plansReady || monthly==null || annual==null` (RevenueCat `offerings==null`). Key:
`subscription_plans_unavailable_title` = "Plan bilgileri şu an alınamıyor"
(tr-TR.json:821). Per HANDOVER §12, RevenueCat entitlement/products are operator
work **not yet configured**, so offerings are legitimately empty → this card +
retry button is the designed graceful state. **No code fix; mark expected** (will
resolve once Play/RevenueCat products are live).

---

## Manual-entry removal decision — data (a19bf32 native ACTION_PICK picker)

`git show a19bf32`: native `MethodChannel("…/contacts_picker")` →
`Intent.ACTION_PICK` on `ContactsContract.CommonDataKinds.Phone.CONTENT_URI`, then
`contentResolver.query` the returned data URI; `READ_CONTACTS` manifest entry kept
stripped (`tools:node="remove"`). PRIMARY SOURCE
(developer.android.com/guide/components/intents-common, Pick a contact): *"The
response grants your app temporary permissions to read that contact data even if
your app doesn't include the READ_CONTACTS permission."* — with the caveat *"In
many cases, your app needs the READ_CONTACTS permission to view specific
information about a particular contact."*
→ The picked-URI read is permission-free by contract, so the picker SHOULD work on
Android 14/15 without READ_CONTACTS (**conf it works: 70%**). Residual OEM risk on
Samsung means: **do not remove manual entry until device-confirmed on the target
device.** Decision is the user's. **Rule:** must NOT add READ_CONTACTS.

---

## D8 / D9 — not specified
The prompt enumerates D1–D7 plus the picker data request; no D8/D9 symptom text was
provided. Flagging so they are not silently dropped.

---

## SELF-CRITIQUE (round 1)
- **D5 weakest link:** I cannot prove what `connectivity_plus 6.1.5` returns at
  cold start on this exact Samsung without the device; H5a is inference from the
  code's stuck-state design, not a captured value. The fix direction (resume
  re-check + fail-open empty) is robust regardless of the exact value, so the
  recommendation holds even if the precise trigger differs.
- **D4 contradiction unresolved:** code rejects manual >15; device adds. I may be
  wrong that the user used the manual button — the picker/provider gap (H4a) is the
  only code path that actually adds an over-length number, so the fix (validate in
  `addContact`) closes it regardless. Still needs exact device repro.
- **D2/D7/D1:** strongest — each has a deterministic code locus + a matching
  primary source; low residual doubt.
- **Assumption to watch:** I assume v1.0.2 (tag `1f4062e`) is what ran on the
  device. If a stale/local build was sideloaded, D4/D5 "didn't hold" could be a
  build-provenance artifact, not a code gap. Worth confirming the installed
  versionCode (should be 10002).
- **Did I miss anything?** Possible shared layout audit beyond the paywall (other
  full-screen scaffolds under edge-to-edge) — recommended but not enumerated here.

## STATUS: investigation complete; awaiting approval for a FAZ-3 fix pass.
