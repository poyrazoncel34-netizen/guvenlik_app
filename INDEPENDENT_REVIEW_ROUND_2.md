# INDEPENDENT REVIEW — ROUND 2 (KoruBeni, com.poyrazoncel.korubeni)

Adversarial production-readiness re-evaluation, conducted **2026-08-13** against
git HEAD `2455dd0` (branch `feat/tutundurma-ucretsiz-prova`), **clean working tree**.

Reviewer position: fresh-context independent evaluator. I did not implement the remediation
under review and I assumed nothing from `INDEPENDENT_REVIEW.md`, `PROGRESS.md`,
`REMEDIATION_PLAN.md` or the audit's own status column. The goal was to falsify the claim
that this tree is ready for the next production-readiness stage.

## Repository state actually observed

```
$ git rev-parse HEAD
2455dd037db9200da285cd930934c1a16c531ddb
$ git status --porcelain
(empty)
```

HEAD matches the value asserted in the brief. Working tree was clean at the start of the
review and clean at the end.

## What I actually did

| Activity | Detail |
|---|---|
| Read in full | `docs/MASTER_PRODUCTION_CHECKLIST.md` (2031 lines), `PRODUCTION_AUDIT.md` (3059 lines / 845 KB), `REMEDIATION_PLAN.md`, `PROGRESS.md`, `INDEPENDENT_REVIEW.md` |
| Machine accounting | Parsed every checklist checkbox and every audit row; compared **requirement text, in order, section by section** — not just counts |
| Ran the suite | `flutter test --no-pub --reporter expanded` → **1094 passed / 0 failed** |
| Static analysis | `flutter analyze --no-fatal-infos` → **No issues found!** |
| Security gates | `scan_release_secrets.py` → **RELEASE_SECRET_SCAN_PASS** (727 text + 46 binary, 0 findings); `verify_release_change_classification.py` → **RELEASE_CHANGE_CLASSIFICATION_PASS** |
| Entitlement probes | Wrote a throwaway probe exercising 18 IR-04 states + the production readiness-card wiring; **deleted afterwards**, tree verified clean |
| Negative controls | Independently disabled **three** production fixes (IR-01 scroll reveal, IR-01 reserved padding, IR-09 reserved slot) and re-ran their own regression tests |
| Code probes | Traced every entitlement consumer and all three panic entry points (button, quick-access surface, volume trigger) through to the Kotlin `EmergencySessionCoordinator` |

**Disclosure of tree modification.** To produce negative controls I temporarily edited
`lib/screens/onboarding/onboarding_contact_step.dart` and `lib/screens/pin_setup_screen.dart`,
and temporarily created `test/zz_r2_probe_test.dart`. Every change was reverted with
`git checkout --` / `rm` and `git status --porcelain` was confirmed empty afterwards. No
production file was modified to obtain a passing result.

---

# CHECKLIST ACCOUNTING — INDEPENDENTLY VERIFIED

I did not trust the reconciliation note. I re-derived it.

```
CHECKLIST REQUIREMENTS: 1738   (1714 `- [ ]` checkboxes + 24 section-77 launch-matrix rows)
AUDIT REQUIREMENTS:     1738
MISSING:                0
DUPLICATED:             0
UNACCOUNTED:            0
```

Method and corroborating checks:

| Check | Result |
|---|---|
| `- [ ]` checkboxes in the canonical checklist | **1714** |
| Section 77 tab-separated matrix rows (excluding the `Alan` header) | **24** — Product…Canary, enumerated and matched one-for-one |
| Audit requirement rows (body only, excluding the P0/P1 register) | **1738** |
| Unique `MP-<section>-<item>` IDs | **1738** — zero duplicates |
| ID section prefix vs containing `##` heading | **0 mismatches** |
| ID numbering contiguous from `001` in every section | **yes, all 80** |
| **Requirement text equality, in order, per section** (NFC-normalised, case/punctuation-insensitive) | **0 mismatches across all 1738** |
| Per-section count checklist vs audit | **0 deltas across all 80 sections** |
| Section-index table (80 rows × 6 statuses) vs actual row statuses | **0 mismatches** |
| Result-summary totals vs actual rows | **exact match** — PASS 495 / FAIL 21 / PARTIAL 147 / BLOCKED 29 / N/A 778 / UNVERIFIED 268 |
| Severity totals vs actual rows | **exact match** — P1 29 / P2 235 / P3 201 |
| Verification codes parse to the declared vocabulary | **1738/1738** resolve to `SRC|RUN|TEST|DOC|NONE|CMD` — IR-10 genuinely closed |

Note on an earlier-looking discrepancy: a naive `grep` of `MP-\d+-\d+` yields 1773 hits with
29 apparent duplicates. Those 29 are the **P0/P1 register** at the top of the document, which
legitimately re-lists P1 rows. Restricted to the per-section requirement body the count is
exactly 1738 with zero duplication.

**The accounting claim is correct.** This is the strongest part of the document set and I could
not break it.

---

# FINDINGS

## R2-01 — The home screen tells a non-subscriber that emergency features are working, when panic/SOS will refuse to arm

- **Requirement IDs:** `MP-19-013` (Offline), `MP-19-022` (User-friendly messaging),
  `MP-18-006` (network-caused empty not shown as if it were not), `MP-01-028` (offline state),
  `MP-77-003` (UX — no critical usability blocker); policy owners `MP-22-001`, `MP-54-029`
- **Current status in audit:** `MP-19-013` **PASS**, `MP-19-022` **PASS**, `MP-18-006` **PASS**,
  `MP-77-003` **PASS**
- **Recommended status:** `MP-19-013` → **FAIL**, `MP-19-022` → **FAIL**, `MP-77-003` → **PARTIAL**
- **Severity:** **P0** by this project's own rule — `.claude/rules/common/code-review.md`:
  *"anything that could prevent or delay an emergency call is CRITICAL by definition"*. A user
  who is told on the home screen that emergency features are working will not press the
  paywall, will not subscribe, and will discover the truth at the moment they press SOS.

### Exact claim challenged

`PROGRESS.md` lines 56–58:

> "The advance-warning UX is now surfaced on the home readiness card with deliberately calm
> copy that states emergency features keep working. **P0 count is now 0.**"

### Evidence

The production wiring is `lib/screens/home_page.dart:225-228`:

```dart
ReadinessCard(
  subscriptionVerificationStale: context
      .watch<SubscriptionProvider>()
      .access
      .isTemporarilyUnverifiable,
```

`isTemporarilyUnverifiable` (`subscription_access_state.dart:62-63`) is
`verifiedEntitlementDecision == unknown`, which is **true for `uninitialized`, `loading` and
`unavailable`** — i.e. true by default, before anything has been resolved.

`SubscriptionProvider._access` starts as `SubscriptionAccessState.uninitialized()`
(`subscription_provider.dart:23-24`). The only startup path that could resolve it is
`splash_screen.dart:199` → `initializeFromPriorProHint()`, which returns immediately unless a
prior verified-Pro hint exists:

```dart
Future<void> initializeFromPriorProHint() async {
  if (kIsWeb || !await _rcService.hasPriorProInitializationHint()) return;
```

Every other `initialize()` call site is inside `PaywallScreen`. **A user who has never
subscribed therefore never leaves `uninitialized` while on the home screen**, so the notice is
not transient — it is permanent.

Probe output (fresh `SubscriptionProvider`, mocked empty SharedPreferences, real `tr-TR.json`
catalogue, exact production wiring):

```
PROBE|freshProvider|status=uninitialized|isPro=false|unverifiable=true
PROBE|RENDERED| … ~~ Abonelik doğrulaması bekliyor ~~ Cihaz çevrimdışı olduğu için
  aboneliğin doğrulanamıyor. Acil durum özellikleri çalışmaya devam ediyor;
  bağlantı kurulduğunda doğrulama kendiliğinden yenilenir.
PROBE|OFFLINE_CLAIM|true
PROBE|EMERGENCY_WORKS_CLAIM|true
```

The rendered copy (`assets/translations/tr-TR.json`) makes **two statements that are false for
this user**:

1. *"Cihaz çevrimdışı olduğu için"* — "because the device is offline". The device is online;
   the provider was simply never initialised.
2. *"Acil durum özellikleri çalışmaya devam ediyor"* — "emergency features keep working".
   For this user they do not. `PremiumFeature.panic` is `FeatureAccessLevel.pro`
   (`feature_access_matrix.dart:97-102`), and the probe confirms
   `canUsePaidSafetyFeature=false` in the default state, so `SubscriptionGate.ensureAccess`
   returns false and the SOS control refuses to arm.

### Reproduction

```bash
grep -n "subscriptionVerificationStale" lib/screens/home_page.dart
grep -n "isTemporarilyUnverifiable" lib/core/services/subscription_access_state.dart
grep -n "hasPriorProInitializationHint" lib/presentation/providers/subscription_provider.dart
```

Then pump `ReadinessCard` with `subscriptionVerificationStale:` bound to a fresh
`SubscriptionProvider().access.isTemporarilyUnverifiable` under the real `tr-TR` catalogue, or
install a debug build (no RevenueCat key → `ensureInitialized()` returns false) and open home
as a first-run user.

### Observed result

A never-subscribed user, online, sees a permanent home-screen notice attributing the state to
being offline and asserting that emergency features continue to work.

### Expected result

The notice must appear only when there is a genuine prior entitlement whose verification has
gone stale — i.e. gated on `lastVerifiedPro == true` — and its "emergency features keep
working" sentence must be shown only when `canUsePaidSafetyFeature` is actually true.

### Recommended remediation

1. Gate the notice on a real anchor, not on the absence of initialisation:
   `access.isTemporarilyUnverifiable && access.canUsePaidSafetyFeature`.
2. Drive the *timing* of the notice from the API that was built for it —
   `isOfflineGraceExpiring(threshold: 48h)` — rather than from `isTemporarilyUnverifiable`
   (see **R2-05**; that API is currently dead code).
3. Add a widget test that fails when the notice renders for a state with
   `lastVerifiedPro != true`.

---

## R2-02 — Duplicate-trigger guard on the quick-access panic entries is set *after* a ~2.2 s await, so two countdowns can stack

- **Requirement IDs:** `MP-01-022` (double-trigger must not duplicate), `MP-70-001`
  (press every button very fast), `MP-70-002` (double click), `MP-70-003` (submit 20×)
- **Current status in audit:** `MP-01-022` **PASS**, `MP-70-001` **PASS**, `MP-70-002` **PASS**,
  `MP-70-003` **PASS**
- **Recommended status:** all four → **PARTIAL** (the panic-button half holds; the
  quick-access half does not)
- **Severity:** **P1** — emergency path, user-visible wrong state during a live armed session

### Exact claim challenged

`MP-01-022` PASS evidence:

> "SRC `lib/widgets/panic_button.dart` guards re-entry with
> `if (_pointerDown || _isArmed || _countdownOpening) return;` plus a `_pressEpoch` generation
> counter…"

That is true **for `PanicButton`** — `_pointerDown = true` is set synchronously inside
`_onPressStart` (`panic_button.dart:112-114`) before any await, so that guard is sound. The
evidence does not mention the *other* panic entry point, and that one is not sound.

### Evidence

`lib/core/widgets/emergency_trigger_host.dart:226-248`:

```dart
Future<void> _openCountdown() async {
  if (_countdownOpen) {            // ← guard READ
    return;
  }
  final subscription = context.read<SubscriptionProvider>();
  final access = await _resolveAccessBounded(subscription);   // ← up to 400 ms + 1800 ms
  if (!mounted || !access.canUsePaidSafetyFeature) return;
  var navigator = rootNavigatorKey.currentState;
  if (navigator == null) {
    await WidgetsBinding.instance.endOfFrame;                 // ← another await
    …
  }
  _countdownOpen = true;           // ← guard WRITE, after ~2.2 s of awaits
```

`_resolveAccessBounded` is explicitly budgeted at
`offlineAnchorLoadTimeout` (400 ms) + `entitlementResolveTimeout` (1800 ms)
(`subscription_gate.dart:49-55`). Any second trigger inside that window reads
`_countdownOpen == false` and proceeds.

`_openCountdown` is reachable from three places, two of which can fire repeatedly:
`_consumeQuickPanicRequest()` on `initState` and on resume
(`emergency_trigger_host.dart:50, 71`), and
`VolumeTriggerService.startListening(onPanicTriggered: _openCountdown)` (line 114-116).
`VolumeTriggerService` applies **no Dart-side debounce** — every `volume_panic` event calls
`_onPanicTriggered?.call()` directly (`volume_trigger_service.dart:88-91`).

Downstream consequence, traced to the native authority: the second screen's
`_scheduleNativeBackupAlarm()` reaches `EmergencySessionCoordinator.arm()`, which under
`synchronized(PROCESS_LOCK)` returns
`ArmResult.Rejected("activeSessionExists")`
(`EmergencySessionCoordinator.kt:94-100`). `PanicArmPolicy.dispositionFor` maps that to
`blocked` and `blockedMessageKey` falls through to `safety_session_not_ready`, so
`countdown_screen.dart:243-247` shows `emergency_total_failure_title` — a blocking failure
dialog — **on top of the first, genuinely armed countdown**.

The dispatch itself survives: cancellation is token-scoped (`_sessionToken` is `null` for a
rejected arm, `countdown_screen.dart:221`) and the foreground service is reference-counted per
owner (`foreground_service_ownership.dart`), so the second screen cannot cancel or unhook the
first. The defect is the false failure UI over a live session, and the loss of access to the
real countdown's PIN-cancel while that dialog is up.

### Why the existing test cannot catch this

`test/screens/panic_route_guard_test.dart:36-48` is a source-string test:

```dart
final body = source.substring(openIdx);
expect(body, contains('try {'));
expect(body, contains('} finally {'));
expect(body, contains('_countdownOpen = false;'));
```

It asserts only that the guard is **reset in a finally**. It says nothing about whether the
guard is **set before the awaits**, which is the actual defect, and it would stay green through
any reordering.

### Reproduction

```bash
sed -n '226,250p' lib/core/widgets/emergency_trigger_host.dart
sed -n '85,95p' lib/core/services/volume_trigger_service.dart
```

Runtime: enable the volume trigger as an entitled user, trigger the volume pattern twice within
~2 s (the natural behaviour when the first press appears to do nothing), observe two
`CountdownScreen` routes and the `emergency_total_failure_title` dialog over the armed one.

### Observed result / Expected result

Observed: two concurrent countdown routes; a blocking "emergency total failure" dialog over a
live armed session. Expected: the second trigger is a no-op, exactly as `PanicButton` already
achieves.

### Recommended remediation

Set `_countdownOpen = true` synchronously at the top of `_openCountdown`, immediately after the
guard read, and clear it in the existing `finally` (extending the `try` to cover the awaits).
Replace the source-string assertion with a behavioural test that invokes the trigger twice
inside the resolve window and asserts exactly one route push.

---

## R2-03 — The quick-access panic entries reject silently; only the panic button explains itself

- **Requirement IDs:** `MP-13-003`, `MP-19-022`, `MP-01-030` (permission/denied state),
  `MP-77-003`
- **Severity:** **P1** — this is the "silent emergency failure" class named in the brief

### Exact claim challenged

`INDEPENDENT_REVIEW.md` "What held up": *"Entitlement rejection is visible, not silent —
Confirmed on both tap and 3.5 s hold."* That verification covered `PanicButton` only.

### Evidence

`SubscriptionGate.ensureAccess` deliberately never fails silently
(`subscription_gate.dart:98-104`):

```dart
// … a safety control must never read as "broken button" — an unexplained no-op is
// indistinguishable from a crash to someone who is about to need it.
showEntitlementUnverified(context);
```

`EmergencyTriggerHost._openCountdown` bypasses `ensureAccess` entirely and rejects with a bare
return (`emergency_trigger_host.dart:233`):

```dart
if (!mounted || !access.canUsePaidSafetyFeature) return;
```

and again at line 243-245 when the root navigator is still null after one frame. A user who
taps the home-screen widget or the Quick Settings tile in that state sees the app open and
**nothing else happen** — the precise failure mode the comment above forbids.

### Reproduction

```bash
grep -n "canUsePaidSafetyFeature\|return;" lib/core/widgets/emergency_trigger_host.dart | sed -n '1,12p'
grep -n "showEntitlementUnverified" lib/core/services/subscription_gate.dart
```

### Expected result

All three panic entry points converge on one rejection surface. Route the quick-access path
through `SubscriptionGate.showEntitlementUnverified` (or a notification, since the app may not
be foregrounded), so a rejected quick-access press is never indistinguishable from a crash.

---

## R2-04 — `SubscriptionProvider.isPro` now means "emergency-authorised", but four non-emergency screens still read it as "is a subscriber"

- **Requirement IDs:** `MP-55-*` (subscription UX), `MP-54-029`, `MP-13-012`
- **Severity:** **P2**

### Evidence

The IR-04 change redefined the getter (`subscription_provider.dart:35`):

```dart
bool get isPro => _access.canUsePaidSafetyFeature;
```

`canUsePaidSafetyFeature` is now the **unbounded emergency** authorisation. But `isPro` is
consumed by four non-emergency surfaces: `home_page.dart:158`, `settings_page.dart:101`,
`paywall_screen.dart:46,70`, `subscription_management_screen.dart:41,95`.

Probe, subscriber offline for 8 days:

```
PROBE|03 active+offline8d|emergency=true|nonEmerg=false|decision=authorized|paywall=false
```

So `isPro == true` — the paywall reports the user as subscribed and settings shows Pro state —
while `SubscriptionGate.ensureAccess(PremiumFeature.advancedAutomation)` evaluates
`canUseNonEmergencyPaidFeature == false` and denies. UI and gate disagree, in the direction of
"UI says available, gate refuses".

### Recommended remediation

Split the getter: keep `isPro` for the non-emergency/commercial surfaces bound to
`canUseNonEmergencyPaidFeature`, and expose the emergency authorisation under an explicit name
(`canUseEmergencyFeature`). The two policies are now genuinely different and one boolean can no
longer represent both.

---

## R2-05 — The advance-warning API built for IR-04 is dead code; the shipped notice is not driven by remaining grace

- **Requirement IDs:** `MP-22-001`, `MP-54-029`
- **Severity:** **P2** (P0-adjacent because it is the remediation `PROGRESS.md` reports as done)

### Exact claim challenged

`PROGRESS.md` line 56-58: *"The advance-warning UX is now surfaced on the home readiness
card"*, closing IR-04 recommendation #2 ("Surface remaining grace once it drops below ~48 h").

### Evidence

```bash
$ grep -rn "isOfflineGraceExpiring\|remainingOfflineGrace\|hasLostAccessToOfflineGraceExpiry" lib/ test/
lib/core/services/subscription_access_state.dart:135   Duration? remainingOfflineGrace(...)
lib/core/services/subscription_access_state.dart:150   bool isOfflineGraceExpiring(...)
lib/core/services/subscription_access_state.dart:166   bool hasLostAccessToOfflineGraceExpiry(...)
test/core/services/offline_grace_expiry_test.dart:…    (assertions only)
```

**No production file consumes any of the three.** The three references outside the defining
file are its own internal calls and one test. The shipped notice is bound to
`isTemporarilyUnverifiable` instead (see R2-01), which carries no notion of "remaining" and
fires in states where no grace window exists at all:

```
PROBE|6dAnchor  |remaining=24:00:00|expiring48h=true |unverifiable=true
PROBE|neverPro  |remaining=null    |expiring48h=false|unverifiable=true
```

The second row is the one that reaches production. `remainingOfflineGrace` is `null` — there is
no window — yet the notice renders.

### Recommended remediation

Wire the notice to `isOfflineGraceExpiring` as designed, or delete the unused API and correct
`PROGRESS.md` to say the warning is an unconditional unverifiable-state notice rather than an
advance warning. Do not leave both.

---

## R2-06 — A load-bearing comment in the provider now states the opposite of the implemented policy

- **Requirement ID:** `MP-22-001`
- **Severity:** **P3** (documentation), but it sits on the entitlement decision path

`subscription_provider.dart:290-293`:

```dart
case EntitlementDecision.unknown:
  // Preserve lastVerifiedPro only as an already-armed in-process lease.
  // `canUsePaidSafetyFeature` remains false, so no new arm is authorized.
  _setAccess(_access.markUnavailable());
```

After the IR-04 change this is false in both sentences: `markUnavailable()` preserves the
anchor, and `canUsePaidSafetyFeature` is now **true** indefinitely for a previously confirmed
subscriber (probe rows 03/04/17). The next person reading this branch will conclude the
emergency path fails closed here. It does not. Update the comment to state the current policy.

---

## R2-07 — `PROGRESS.md` contradicts itself on the two claims this review was asked to check

- **Requirement ID:** remediation-reporting integrity (this is the IR-07 class, reported RESOLVED)
- **Severity:** **P2**

`PROGRESS.md` asserts both sides of four separate questions:

| # | Claim A | Claim B |
|---|---|---|
| 1 | line 58: *"**P0 count is now 0.**"*; line 165: *"**P0 = 2** (`MP-22-001`, `MP-54-029`)… The earlier 'no P0, structurally' claim was **withdrawn**"* | line 176-178: *"**Unresolved P0: None.** … This is structural: with no server, no accounts, no telemetry and no AI…"* — the withdrawn paragraph, restored verbatim |
| 2 | line 64-66: *"IR-03 — coverage completed. … **All four** promised screens now carry guideline matchers"* | line 32: *"3 screens. **CountdownScreen and contrast still uncovered**"*; line 76: *"**3 of 4** promised screens covered"* |
| 3 | line 60-63: *"**IR-09 — fixed and device-verified.**"* | line 82: *"IR-09 … **OPEN (LOW)** — Not addressed this pass."* |
| 4 | line 43-48: reconciled to **1738** | lines 139-152: *"Every one of the **1,714** checkboxes…"*, with a status table (PASS 485 / PARTIAL 140 / BLOCKED 28 / N/A 773 / UNVERIFIED 267 / TOTAL 1,714) that matches **no** current audit figure, under a header that says *"do not hand-edit them here"* |

Additional stale statements in the same file: line 182 *"Unresolved P1 (**27**)"* (the audit
carries 29); line 234 suite counts (*1009/1 failed*, *1025 passed*) against a measured
**1094 / 0**; line 341 *"Next action: Apply Batch 0 … confirm 1010/1010 green"* for a batch the
same file marks ✅ Done.

On the merits I verified that **claim A is correct in rows 2 and 3** — see R2-VERIFIED below —
so the file understates its own completed work while simultaneously overstating R2-01/R2-05.
Either way a reader cannot use it.

### Recommended remediation

Delete the stale "Unresolved P0", "Audit counts" and "Next action" sections outright and
regenerate every count from `PRODUCTION_AUDIT.md`, as the file's own header instructs.

---

## R2-08 — The audit's provenance stamp predates ten of the production files it grades

- **Requirement ID:** audit integrity
- **Severity:** **P2**

`PRODUCTION_AUDIT.md` line 5:

> "Generated 2026-08-12 against git HEAD `fe83771`"

HEAD is `2455dd0`. `git diff --stat fe83771..HEAD` shows **9,972 insertions across 42 files**,
including the exact safety-critical files whose rows the audit grades:

```
lib/core/services/subscription_access_state.dart   | 106 +-
lib/core/services/subscription_gate.dart           |   7 +-
lib/core/widgets/readiness_card.dart               |  67 +
lib/screens/home_page.dart                         |   7 +
lib/screens/onboarding/onboarding_contact_step.dart| 106 +-
lib/screens/pin_setup_screen.dart                  |  79 +-
lib/widgets/panic_button.dart                      |  17 +-
lib/core/services/crash_log_service.dart           |  29 +
lib/core/services/local_database_service.dart      |  75 +-
```

Some rows *were* regenerated after that (the section-77 rows and the IR-04 rows carry
2026-08-13 dates), so the document is a mix of two trees with a single stamp naming the older
one. A reader cannot tell which rows describe which tree — which is the property the stamp
exists to provide.

Compounding this, the **"Baseline commands run"** table (lines 24-34) still reports
`flutter test --no-pub` as *"1009 passed / 1 failed"* with a note explaining the
`release_change_classification_test.dart` failure. That failure no longer occurs; I measured
**1094 passed / 0 failed**.

### Recommended remediation

Re-stamp the header to `2455dd0`, regenerate the baseline-commands table against this tree, and
add the HEAD SHA to each row's evidence date (or regenerate wholesale) so provenance is
per-row.

---

## R2-09 — `MP-08-023` PASS is backed by evidence for a different requirement

- **Requirement ID:** `MP-08-023` ("Loading button")
- **Current status:** **PASS** · **Recommended status:** **UNVERIFIED**
- **Severity:** **P3** — but it is exactly the IR-06 class the remediation reports as resolved

Requirement: *"Loading button."* — i.e. a button that shows progress and is disabled while its
async action runs. Recorded evidence:

> "IR-09 fixed: the PIN validation banner now occupies a reserved slot that scales with text
> size, so the keypad cannot move when it appears. TEST
> `test/screens/pin_setup_layout_stability_test.dart` (6 cases…)"

That is layout stability of a validation banner. It does not address loading-button behaviour.

To be fair to the remediation: I re-measured the IR-06 metric and it improved materially.
Of 495 PASS rows there are **416 distinct evidence strings**; **134 rows (27.1 %)** share
evidence, with a maximum reuse of **4** — down from 44.4 % and 28× at round 1. I inspected every
reuse group of ≥3 and all but this one are legitimate (e.g. one schema sentence backing
`MP-29-001/002/004/005` — primary keys, unique, not-null). `MP-08-023` is the outlier, not the
pattern.

---

## R2-10 — Two recorded gate commands cannot execute as written

- **Requirement IDs:** `MP-75-006` (security gate green), `MP-77-009`
- **Severity:** **P3** (evidence reproducibility)

`PRODUCTION_AUDIT.md` records:

| Command | Recorded result |
|---|---|
| `scripts/scan_release_secrets.py --require-clean` | RELEASE_SECRET_SCAN_PASS |

Run verbatim:

```
scan_release_secrets.py: error: the following arguments are required: --output
```

The same applies to `verify_release_change_classification.py`, which requires `--config`.
Supplying the missing arguments, both gates **do pass on this tree**:

```
RELEASE_SECRET_SCAN_PASS      mode=tracked-candidate text=727 binary=46 findings=0
RELEASE_CHANGE_CLASSIFICATION_PASS
```

So the verdicts are sound; the recorded invocations are not reproducible. Record the exact
command line, including `--output`. (Note also that the audit's *"706 text files"* is now 727 —
a further symptom of R2-08.)

---

## R2-11 — A future-dated anchor is rejected by two getters and accepted by the one that authorises SOS

- **Requirement IDs:** `MP-22-001`, `MP-54-029`
- **Severity:** **P2**

`canArmWithinOfflineGrace` (line 122-123) and `remainingOfflineGrace` (line 140-142) both
explicitly distrust a future anchor — *"A future anchor means a rolled-back clock or a tampered
store"*, *"report it as fully expired rather than as an unbounded grant"*. But
`entitlementDecision` (line 93-97) checks only that the timestamp is **non-null**:

```dart
final confirmedBefore = lastVerifiedPro == true && lastVerifiedProAt != null;
```

Probe:

```
PROBE|16 futureAnchor+10d|emergency=true|nonEmerg=false|decision=authorized
```

Round 1 recorded `FUTURE_ANCHOR canUsePaidSafetyFeature=false`; it is now `true`. This may well
be deliberate — under an unbounded emergency policy a wrong device clock must not remove SOS,
and I would not argue for reverting it. But it is undocumented, it contradicts the two
neighbouring comments, and it means the anti-forgery boundary requires only *two present keys*,
not two plausible ones. Decide and document which it is.

**On the anti-forgery boundary generally:** I could not forge entitlement with a single value.
Verified:

```
PROBE|12 boolOnly noTimestamp   |emergency=false     PROBE|15 timestampOnly noBool|emergency=false
PROBE|restore uncorroborated    |emergency=false     PROBE|restore corroborated   |emergency=true
PROBE|restore over confirmedFree|emergency=false
```

`withRestoredProAnchor` correctly refuses to patch an anchor over an already-resolved state
(`subscription_access_state.dart:238`), and `clearLastVerifiedProAt()` removes **both** keys and
is `await`ed on the denied branch (`subscription_provider.dart:289`) precisely so a process
death cannot resurrect the anchor. Writing both SharedPreferences keys on a rooted device does
grant unbounded emergency access, but that is acknowledged in-code and in `MP-22-001`'s gap
text, `allowBackup=false` blocks the non-root route, and the consequence is revenue, not safety.
**I do not raise this as P0.**

---

## R2-12 — The IR-01 regression test covers one of the fix's two mechanisms

- **Requirement ID:** `MP-72-030`
- **Severity:** **P3**

The fix has two parts: the `Scrollable.ensureVisible` reveal
(`onboarding_contact_step.dart:129-148`) and an inset-reserved bottom padding
(`onboarding_contact_step.dart:259`, `bottom: _imeInset`). My negative controls:

| Mechanism disabled | `onboarding_contact_step_keyboard_test.dart` |
|---|---|
| `_scheduleRevealSaveAction` (scroll reveal) | **3 of 6 FAIL** ✅ |
| `bottom: _imeInset` (reserved padding) | **6 of 6 pass** ⚠ uncovered |

Add a case that fails when the reserved padding is removed, or document it as belt-and-braces.

---

# WHAT I TRIED TO BREAK AND COULD NOT

Stated because a review that lists only defects misrepresents the tree.

| Claim | Independent result |
|---|---|
| Checklist accounting 1738/1738/0/0/0 | **Confirmed** — and by text equality per row, not by count alone |
| Audit summary, section index, severity totals | **Confirmed** — regenerate-from-rows is real; all three reconcile exactly |
| IR-05 (five contradictory summaries) | **Resolved** — one summary, matching the rows |
| IR-10 (malformed rows) | **Resolved** — 1738/1738 parse to valid method codes |
| **IR-02 — test can fail** | **Confirmed by my own negative control.** Disabling the production reveal fails 3/6. The test never calls `ensureVisible`, simulates the IME across four animation frames via `tester.view.viewInsets`, asserts geometry against the keyboard line, uses predicate finders (so `ElevatedButton.icon`'s private subclass is matched), and asserts harness preconditions (consent granted, phone field enabled) so a broken harness fails loudly. It also covers repeated focus cycles, dismissal, manual scrolling and a tall viewport. This is a genuinely good regression test. |
| **IR-03 — a11y coverage 4/4, 10 tests, 2 negative controls** | **Confirmed.** `accessibility_guidelines_test.dart` (7 tests, 2 of them negative controls) + `countdown_accessibility_test.dart` (3 tests) = **10 / 2 / 4 screens** (onboarding contact, panic button entitled + locked, consent gate, CountdownScreen). Both files load the **real** `assets/translations/tr-TR.json`, and `assertRealCopyRendered` fails the run if any `lower_snake_case` key leaks into the tree — which is precisely the vacuity IR-03 found. `assertScreenSettled` rejects a spinner-only tree. The negative controls prove the matchers reject an unlabelled icon button and a 12×12 target. `PROGRESS.md` lines 32/76 understate this. |
| **IR-09 — PIN banner no longer moves the keypad** | **Confirmed by my own negative control.** Making the slot conditional fails **3 of 6**. The test measures a real keypad key (`find.text('5').last`), asserts the banner is actually present and non-empty (so it is not comparing empty geometry), and covers repeated rejections, a short screen and 200 % text scale. The reserved height scales with `MediaQuery.textScalerOf`, and `maxLines: 2` + ellipsis bounds a long localised message. |
| IR-04 core policy | **Confirmed on 18 states.** Unbounded emergency access while unverifiable (3 d / 8 d / 90 d / 400 d all `emergency=true`); non-emergency bounded at 7 d; confirmed-inactive denies and routes to the paywall; UNKNOWN never becomes EXPIRED; bool-alone and timestamp-alone both refuse. |
| Native arm concurrency | **Excellent.** `EmergencySessionCoordinator.arm()` runs under a process lock with generation-monotonic revision, `activeSessionExists` rejection, corrupted-read → `Unknown`, and capability-read failure → `Unknown` rather than permission to arm. |
| Cancellation scoping | **Correct.** Token-scoped; a rejected arm carries `_sessionToken = null` so it cannot cancel another screen's session. Foreground-service ownership is reference-counted per owner. |
| Suite / analyzer | **Confirmed** — 1094 passed / 0 failed; analyzer clean |
| Secret scan / release classification | **Confirmed PASS on this committed tree** (with corrected arguments) |
| No biometrics (CLAUDE.md rule 2) | **Confirmed** — no `local_auth` anywhere |
| Emergency path network-free | **Confirmed** — no HTTP in the dispatch path |
| Evidence-reuse (IR-06) | **Materially fixed** — 44.4 % → 27.1 %, max reuse 28 → 4, and the surviving groups are legitimate |

---

# ANSWERS TO THE SPECIFIC QUESTIONS ASKED

**P1 classification (29 items).** The register is honest but the summary framing is not. The
brief's phrasing "29 P1 items, all externally blocked" is not what the document says: by status
they are **BLOCKED 4 / PARTIAL 9 / UNVERIFIED 16**, and the register's own
"Resolvable in-repo?" column already answers **"Partly"** for two — `MP-53-003` (Play App
Signing enrolment; the runbook is written, only the console fact is external) and `MP-77-009`
(MFA + enrolment confirmation). I inspected all 29 and agree with the *severity* on each: none
should be P0, none should be lower, and none is merely UNVERIFIED-when-it-should-be-BLOCKED in a
way that changes what must happen before launch. `MP-63-006` (MFA) is correctly UNVERIFIED
rather than BLOCKED — nothing in the repo blocks it; it is simply a fact the repo cannot see.
The 20 billing items genuinely require a RevenueCat sandbox key and a Play internal-test
account, and `MP-41-017` (incoming call during armed dispatch) genuinely requires both a live
entitlement and real telephony. **No P1 reclassification is warranted; the register's prose
should stop saying "all externally blocked".**

**Was `MP-22-001`/`MP-54-029`'s downgrade from P0 (round 1) to P2 justified?** Yes, on the
merits. Round 1's P0 rested on "network loss alone disables SOS", and the IR-04 change removed
that: a confirmed subscriber keeps SOS indefinitely offline. My probes confirm it. The
downgrade is sound. The **new** P0 in this round (R2-01) is a different mechanism —
misinformation about protection state — not a re-litigation of that one.

**Device/emulator.** Not run this round. No Android device or booted emulator was available in
this environment; `adb` is not on PATH. The device-only claims in the audit (`MP-72-030`
device verification, the Doze race, OEM battery behaviour) therefore remain **unre-verified by
me** — I neither confirm nor dispute them, and R2-01/R2-02 were both established without a
device.

---

# SUMMARY

```
CHECKLIST REQUIREMENTS: 1738
AUDIT REQUIREMENTS:     1738
MISSING:                0
DUPLICATED:             0
UNACCOUNTED:            0

P0 FOUND:               1   (R2-01)
P1 FOUND/RECLASSIFIED:  2 found (R2-02, R2-03); 0 of the existing 29 reclassified

BUILD:                  NOT RUN this round (no APK/AAB build attempted; keystore unavailable)
STATIC ANALYSIS:        PASS — flutter analyze --no-fatal-infos, "No issues found!" (1.8 s)
TESTS:                  PASS — flutter test --no-pub, 1094 passed / 0 failed
DEVICE/EMULATOR:        NOT RUN — no device/emulator available in this environment
ACCESSIBILITY:          PASS as tested — 10 tests / 2 negative controls / 4 screens, real
                        tr-TR catalogue, raw-key leakage fails the run. Contrast still
                        unasserted; no TalkBack pass; no on-device measurement.
SECURITY:               PASS — RELEASE_SECRET_SCAN_PASS (727 text + 46 binary, 0 findings).
                        OSV not re-run this round (network-dependent).
RELEASE GATE:           PARTIAL — RELEASE_CHANGE_CLASSIFICATION_PASS. verify_release.sh NOT
                        run (requires the release keystore, unavailable here).

PASS CLAIMS DOWNGRADED: 7
  MP-19-013  PASS → FAIL       (R2-01) app asserts "device is offline" when it is not
  MP-19-022  PASS → FAIL       (R2-01) message is friendly but factually wrong on both clauses
  MP-01-022  PASS → PARTIAL    (R2-02) quick-access entry has no effective duplicate guard
  MP-70-001  PASS → PARTIAL    (R2-02) rapid repeat triggering unguarded on that path
  MP-70-002  PASS → PARTIAL    (R2-02) same
  MP-77-003  PASS → PARTIAL    (R2-01) permanent false notice on the home screen
  MP-08-023  PASS → UNVERIFIED (R2-09) evidence addresses a different requirement
  (MP-18-006 PASS is adjacent to R2-01 and should be re-examined alongside it.)
```

---

# REMAINING PRE-LAUNCH BLOCKERS REQUIRING EXTERNAL SYSTEMS

Unchanged by this review and **not** resolved by any verdict below:

1. **RevenueCat sandbox key + Play internal-test account** — 20 P1 billing items
   (`MP-54-001…008`, `MP-54-018…024`, `MP-73-010`, `MP-74-007`). No purchase, restore, trial,
   upgrade, downgrade or cancel transition has ever been observed against this build.
2. **Physical Android hardware** — `MP-41-017` (incoming call during armed dispatch),
   `MP-41-021` (battery-saver timer drift), `MP-59-027`, `MP-59-030`. Emulator evidence exists;
   the project's own rules state the Doze race and OEM kill lists cannot be proven off hardware.
3. **Google Play policy review** — `MP-59-029`, `MP-62-020`, `MP-77-023`
   (CALL_PHONE + REQUEST_IGNORE_BATTERY_OPTIMIZATIONS + `specialUse` FGS declarations).
4. **Key custody / account security** — `MP-63-006` (MFA on the Google and GitHub accounts),
   `MP-53-003` (Play App Signing enrolment confirmation).
5. **Release keystore** — `scripts/verify_release.sh` (the full analyze → test → signed AAB →
   Android lint/unit → 16 KB chain) cannot run in this environment.
6. **Canary** — `MP-77-024` BLOCKED; no staged-rollout data can exist pre-launch.

---

# VERDICT

The accounting is genuinely sound and I could not break it: 1738 = 1738, zero missing, zero
duplicated, zero unaccounted, with every audit row's requirement text matching the canonical
checklist in order. Three of the four round-1 HIGH findings — IR-02, IR-03 and IR-09 — are
genuinely closed, and I proved it the way the brief demanded rather than accepting the claim:
I disabled each production fix myself and watched its own test go red. IR-04's core policy holds
across all eighteen states I threw at it, and the anti-forgery boundary resists every
single-value forgery I attempted. The native concurrency kernel is the strongest code in the
tree.

But the remediation shipped a home-screen notice that tells a user with no subscription, on a
device that is online, that the device is offline and that **emergency features keep working** —
while `PremiumFeature.panic` is Pro-gated and `canUsePaidSafetyFeature` is `false` for exactly
that user. On a personal-safety product whose catastrophic event is a call that never gets
placed, telling someone they are protected when they are not is that catastrophe with the
warning removed. It is reachable on first run, it is permanent rather than transient, and it was
introduced by the change that `PROGRESS.md` cites as the reason "P0 count is now 0". The API
built to drive that warning correctly — `isOfflineGraceExpiring` — is never called from
production code.

Alongside it, the guard that is supposed to stop two panic countdowns from stacking is written
after a 2.2-second await on the one panic entry point that can fire repeatedly, and its test
only checks that the guard resets in a `finally`.

## **REVIEW FAILED — REMEDIATION REQUIRED**

Close **R2-01** (P0) and **R2-02 / R2-03** (P1) and re-verify them independently — R2-01 with a
widget test that fails when the notice renders without a genuine prior entitlement, R2-02 with a
behavioural double-trigger test rather than a source-string match. Then reconcile **R2-07** and
**R2-08** so the audit set describes the tree it actually grades.

Nothing in this verdict displaces the six external blockers above. `REVIEW PASSED` would not
have released this application either.
