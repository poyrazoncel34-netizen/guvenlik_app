# FINAL INDEPENDENT REVIEW — KoruBeni

> Adversarial, independent verification of the builder's claim
> `REPOSITORY CONVERGENCE PASSED`. Nothing below is copied from `PROGRESS.md`;
> every number was recomputed with an independent parser or reproduced by
> running the command against the current tree. No production code was modified.
> Probe tests were written under `test/zz_reviewer_probe/` and deleted afterwards.

## Repository identity

| Fact | Value |
|---|---|
| **REVIEWED HEAD** | `64079010249afc483c269db78ca774135d873901` (`6407901`) |
| Branch | `feat/tutundurma-ucretsiz-prova` |
| **WORKTREE** | clean (`git status --porcelain` empty before and after this review) |
| **REVIEW DATE** | 2026-08-15 |
| Toolchain | Flutter 3.38.9 stable · Dart 3.10.8 · engine `5eb06b7ad5bb` |

HEAD **is** the claimed `6407901`. No uncommitted or untracked files existed at
the start; the tree was restored to that state at the end.

---

## Canonical accounting

Recomputed with a parser written for this review (`re`-based, no import of
`verify_audit_accounting.py`), then cross-checked against the builder's verifier.

| Metric | Independent | Builder claim | Verdict |
|---|---|---|---|
| **CHECKLIST** | **1738** (1714 checkbox + 24 section-77 launch-matrix) | 1738 | reproduced |
| **AUDIT** | **1738** unique `MP-` rows | 1738 | reproduced |
| **MISSING** | **0** | 0 | reproduced |
| **DUPLICATED** | **0** | 0 | reproduced |
| **UNACCOUNTED** | **0** | 0 | reproduced |
| Sections | 80, contiguous `1..80` in both files | 80 | reproduced |
| Section 77 | 24 tab-separated matrix rows → `MP-77-001..024`, in order, text-identical | 24 | reproduced |

Additional checks the builder's verifier does not perform, all clean:

- **Requirement text parity**: 1714/1714 checkbox requirements match their audit
  row's text character-for-character (after whitespace normalisation). The only
  25 "mismatches" my parser reported were rows of the P0/P1 register table, which
  reuses the `| \`MP-xx-yyy\` |` shape — not canonical rows.
- **Section placement**: every `MP-NN-xxx` row sits under audit heading `## NN.`.
  Zero misplacements.
- **ID derivation**: the set of audit IDs equals `{checkbox-derived} ∪ {MP-77-001..024}`
  exactly — 0 extra, 0 missing.

`python3 scripts/verify_audit_accounting.py` →
`AUDIT_ACCOUNTING_PASS checklist=1738 audit=1738 missing=0 duplicated=0 unaccounted=0 sections=80 launchMatrix=24` (rc=0).

**Phase 1 verdict: the canonical accounting claim survives in full.**

---

## Recomputed audit state

Independently tallied from the 1738 canonical rows:

| Status | Independent | Builder | |
|---|---|---|---|
| PASS | **792** | 792 | reproduced |
| FAIL | **9** | 9 | reproduced |
| PARTIAL | **67** | 67 | reproduced |
| BLOCKED | **38** | 38 | reproduced |
| N/A | **779** | 779 | reproduced |
| UNVERIFIED | **53** | 53 | reproduced |
| **Sum** | **1738** | 1738 | reproduced |

| Severity | Independent | Builder |
|---|---|---|
| P0 TOTAL | **0** | 0 |
| P0 IN-REPO | **0** | 0 |
| P1 TOTAL | **29** | 29 |
| P1 IN-REPO | **0** *(as recorded)* | 0 |
| P2 | **119** | 119 |
| P3 | **19** | 19 |

Scope counts, from `RESOLUTION_QUEUE.md` (167 queued):

| Scope | Recorded | Independent verdict |
|---|---|---|
| IN_REPO_RESOLVABLE | 0 | **FALSIFIED — see FIR-01, FIR-02, FIR-03** |
| RUNTIME_VERIFIABLE_NOW | 0 | not falsified |
| EXTERNAL_BLOCKER | 112 | **partly false — FIR-03** |
| PRODUCT_DECISION_REQUIRED | 55 | **partly false — FIR-03** |

The arithmetic is exact. The **classification** is not.

---

## Evidence-system review

| Item | Value |
|---|---|
| **VERIFIERS DISCOVERED** | **12** — 11 Python under `scripts/audit_evidence/` (`a11y_platform`, `assets`, `color`, `copy`, `flows`, `interaction`, `layout`, `motion`, `storage`, `tokens`, `typography`) + 1 Dart-test verifier (`test/screens/layout_size_matrix_test.dart` → `text_scale.json`). `common.py` is shared plumbing, not a verifier. |
| **NEGATIVE CONTROLS ACTUALLY RUN** | **12/12** — all 11 Python controls executed with real exit codes captured (no pipeline masking); the 12th is embedded in the Dart artifact and re-verified. |
| **VALID NEGATIVE CONTROLS** | **12** — every one moved the violation count and broke a property the verifier genuinely guards. |
| **INVALID / VACUOUS** | **0 outright**, but see FIR-05: the controls are *per-verifier*, not *per-property*. |
| **STALE / HARD-CODED EVIDENCE** | **FIR-04** — all 11 Python artifacts name a stale, `dirty:true` revision; `text_scale.json` names none. **Substance: 0 drift.** |

### Negative controls, as executed

| Verifier | Mutation | Violations | Breaks a real property? |
|---|---|---|---|
| a11y_platform | critical surface reduced to colour alone + device positive control zeroed | 0 → 2 | yes |
| assets | absent referenced asset + shipped demo image | 1 → 3 | yes (baseline 1 ≠ 0, noted) |
| color | unreadable secondary text + red "success" + card merged into ground | 5 → 9 | yes |
| copy | blame language + raw exception name + unnamed confirmation | 0 → 3 | yes |
| flows | 8 simultaneous defects incl. outcome renamed "delivered", renderer deleted, deep-link destination renamed, second park consumer | 0 → 10 | yes |
| interaction | PIN field offering autofill, unlabelled field, suppression made silent, destination park bypassed | 0 → 5 | yes |
| layout | two badly uneven horizontal gutters | 0 → 2 | yes (one rule only) |
| motion | undisposed unjustified infinite spin | 0 → 2 | yes |
| storage | 8 defects incl. DROP TABLE, hard-coded key, sanitiser→clone, FK enforcement removed | 0 → 13 | yes |
| tokens | stripped every `Radii` consumer (7 files) | 0 → 1 | yes |
| typography | second font family + 7px type + 1.05 line height | 0 → 5 | yes |
| text_scale (Dart) | inflexible `Row` with the shipped tr-TR copy at scale 2.0 | overflow by 2573 px | yes |

### Reproducibility test (the strongest check available)

I re-ran all 11 Python verifiers against a checked-out HEAD and diffed every
artifact against the committed copy, ignoring only `codeRevision`/`measuredOn`:

**0 of 12 artifacts changed in substance.** Every cited measurement — 139 icon
references, 43 consumer files, 90 text-scale cells, `cellsOverflowing = 0`, the
`colourIndependence` table, `tileRequestVolume`, `integrityPolicy` — reproduces
byte-identically at HEAD. The evidence artifacts were then restored with
`git checkout -- docs/audit/evidence/`.

That is the decisive result on the evidence system: the numbers are real and
they are current. The defects found are in **provenance metadata and
classification**, not in the measurements.

---

## Final-14 verification

Each was re-tested independently; I did not rely on the builder's tests being green.

### MP-01-027 — emergency dispatch outcomes · **SURVIVES, with FIR-01**

Wrote an independent 13-case matrix probe against `EmergencyDispatchPipeline`
directly. All passed:

| Scenario | Result |
|---|---|
| `[S,S]` | `everyTargetReached`, `isPartial=false` |
| `[F,S]` / `[S,F]` | both `mixed`; **ledgers differ** — the two are distinguishable |
| `[F,F]` | `noTargetReached`, `isPartial=false` (correctly *not* partial) |
| `[S,F,S]` 3 targets | reached=2, notReached=1, `mixed` |
| PlatformException / MissingPlugin / permission code / ACTIVITY_NOT_FOUND / StateError | classified as `platformRejected` / `noCompatibleHandler` / `permissionDenied` / `noCompatibleHandler` / `platformException` — five distinct outcomes |
| duplicated target | **both** entries kept, `duplicateTargets` flags it |
| suppressed-by-setting | `notReached` — never success |
| unconfirmed | neither success nor failure; forces `mixed` |
| cancelled dispatch | `nothingAttempted`, notReached=0 — not a failure |
| two concurrent dispatches | ledgers `A`/`B` do not interleave |
| reasonCode leak | only the platform code; a phone number in the exception **message** does not reach the ledger |
| vocabulary | contains no `delivered`/`ringing`/`answered`/`completed` |

Live wiring confirmed on both dispatch paths (`countdown_screen.dart:397`,
`check_in_service.dart:603` → `EmergencyCallScreen` →
`DispatchOutcomeList.build`). This is not test-only code.

**But see FIR-01**: on the panic path the total-failure branch discards the
ledger and tells the user "No action completed" even when targets reached.

### MP-31-010 — avatar EXIF / privacy · **SURVIVES**

I built my own fixture with PIL (not the repo's): JPEG carrying GPS
lat/lon/altitude/datestamp, Make, Model, Software, DateTime, ImageDescription,
Artist, Copyright, **Orientation = 6**, plus a hand-injected XMP APP1 packet; and
a PNG with `Comment`/`Author` text chunks. Ran the real sanitizer, wrote the
output to disk, then **re-parsed the stored derivative independently**:

| Check | Source | Stored derivative |
|---|---|---|
| Raw-byte scan for 14 metadata tokens | all present | **NONE** |
| EXIF dict | populated | **empty** |
| GPS IFD | 7 tags | **empty** |
| APP segments | `0xE0`,`0xE1` (Exif + XMP) | **`0xE0` only** (JFIF) |
| PNG text chunks | present | gone |
| Geometry | 200×100, orientation 6 | **100×200** — rotation applied to pixels |
| Corner sampling | — | gradient rotated 90° CW **correctly** |

Fail-closed confirmed: malformed APP1 → `null` (refuse to store, never the
original); 4 KB of garbage → `null`. `File.copy` appears nowhere on the image
path; the KVKK export names only the sanitised filename.

### MP-29-017 — database integrity · **SURVIVES**

Independent sqflite-ffi probe over a real file, three failure classes:

1. **Healthy** (200 rows) → healthy at both depths; `PRAGMA foreign_keys` reads ON.
2. **FK orphan** → raw `PRAGMA integrity_check` returns **`ok`** (the trap is real
   and reproducible), `quick` scan healthy by design, `full` scan reports
   **1 foreignKey finding, 0 structural, `scanFailed=false`**.
3. **Real byte damage** — index pages randomised mid-file, header left intact so
   the file still opens → `healthy=false`, `scanFailed=true`, `failureReason=11`
   (`SQLITE_CORRUPT`). Not "the file would not open".
4. Hostile input (closed handle) → **reports**, never throws.

All three classes are distinguishable. Lifecycle placement verified in source:
`onConfigure` per connection, `quick` after migration only (`upgradeSchema`),
`full` in user-triggered diagnostics. Not on the open path.

### MP-26-008 — deep links · **SURVIVES**

Independent hostile-input probe (11 rejection cases + normalisation attack):

- `https://`, foreign host, `file://`, `intent://` → `foreignUri`
- `korubeni://open/panic` → `unknownDestination`
- extra path segment → `pathTooDeep`; unknown query key → `unknownParameter`
- `event=../../x`, empty value, `<script>` → `malformedParameter`; >512 chars → `oversized`
- **duplicate parameter cannot smuggle the first value**: only the validated map
  is passed downstream, and the raw URI is never forwarded
- **dot-segment normalisation**: 14 hostile forms tested. Whatever Dart normalises
  them to is *always* an allowlisted `AppDestination`; the allowlist cannot be escaped
- 500-link hostile burst → **one** parked destination; rejection log bounded at 20;
  single-consume verified; a rejected link parks nothing; `clear()` disarms
- `build()`/`parse()` agree for all 7 destinations
- No destination can arm, dial, cancel or unlock (asserted over the whole enum)

Gate ordering verified in source: `SplashScreen` builds `MainNavigation` only
after consent → onboarding → PIN. The park's single consumer is
`main_navigation.dart`. *(See FIR-07 for a dead code path that weakens the
structural argument.)*

### MP-12-029 — forced / high-contrast colours · **SURVIVES**

I read the installed SDK's `window.dart` myself. Independently confirmed:
`highContrast`, `reduceMotion`, `onOffSwitchLabels` → *"Only supported on iOS"*;
`boldText` → *"iOS and Android API 31+"*; `invertColors`, `disableAnimations`,
`accessibleNavigation` → no limitation. The verifier's table is exactly right and
is parsed, not typed.

Critically, **no PASS rests on `adb screencap`**. The write-up records the
screenshot as the *wrong instrument* for inversion rather than claiming a result
from it. The enforced property is `colourIndependence` (source-derived, 0 surfaces
carrying meaning by colour alone) plus `forced_colors_test.dart`, which renders the
critical surfaces with every colour collapsed to one value. The 3361 status-bar
pixels are a genuine positive control (an Android View that did repaint).

Confirmed the app never reads `highContrast`; `ReducedMotionPolicy` reads
`MediaQuery.disableAnimations` — an Android-delivered flag, not the iOS-only one.

### MP-10-023 — scroll restoration · **SURVIVES**

17 cases green against a real `ListView.builder` with uneven extents. The design
distinction is correct and non-trivial: a pixel offset for settings (fixed
content), an **identity** anchor for the timeline (rows are prepended, so a
restored offset lands on a different event). Verified at the maximum volume tier
too — the anchor still resolves with 10,000 rows.

### MP-04-012 — icon size tokens · **SURVIVES**

`IconSizes`: 139 references across 43 consumer files, `zeroConsumerScales = []`,
reproduced byte-identically at HEAD. The finding is honest: the invented scale had
zero consumers because it omitted 18 dp and 22 dp, so it was rebuilt *from the
census* into nine purpose-named roles — every rung a size already drawn, so no
pixels moved (CLAUDE.md rule 4 respected). Visual size and hit target are kept
separate and asserted. The ratchet pin was **tightened** 73 → 23, not left high.
11 cases green.

### MP-11-014 / MP-23-010 / MP-26-006 — notification surfaces · **FIR-02**

The typed-outcome refactor is real: `showEmergencyAlert` returns
`suppressedByUserSetting` / `permissionDenied` / `handoffAccepted`. Per-category
taxonomy, live platform state (no local toggle copy), per-channel deep links and
`tapRoutesThroughDestinationPark` all verified.

**But the builder's claim that the old defect "is actually gone throughout all
call sites" is false** — 2 of 4 live call sites discard the outcome. See FIR-02.

### MP-23-015 — subscription survives deletion · **SURVIVES**

Real tr-TR and en-US catalogue inspected directly. No raw keys. TR: *"Aboneliğiniz
bu işlemle iptal olmaz … Buradaki verileri silmek ya da uygulamayı kaldırmak
aboneliği iptal etmez; ücretlendirme devam eder."* Covers **uninstall** explicitly,
names Google Play as the biller, links to Play Subscriptions, offers **no**
impossible cancel control. Shown on both local-erase paths (reset dialog +
deletion screen body + its confirmation dialog).

### MP-42-024 / MP-47-003 / MP-47-011 — quota, power user, volume · **SURVIVE, with FIR-08**

62 cases green across the three files. Tiers are product-bound and justified in
the test source. Laziness proven (10,000 rows → ~12 widgets built), scroll to
25/50/99/100 % raises no exception, last row reachable and correct, targeted
delete touches exactly one of ten thousand, integrity check clean at max tier.
Tile volume derived from the shipped map config, not chosen.

**FIR-08**: the growth assertion is far looser than the audit's wording.

---

## Critical-regression verification

| Area | Result |
|---|---|
| **Subscription / emergency** | `readiness_card_stale_verification_test.dart` green; readiness copy derives from `noticeFor()` rather than an unverifiable boolean. Full suite green. |
| **Duplicate trigger** | **CLEAN.** `_emergencyDispatched = true` is the statement immediately after the guard, **before any `await`** (`countdown_screen.dart:282-283`). Effective before the first async suspension. |
| **Silent entitlement rejection** | Gate refusals return `refusedByEntitlement` and the router deliberately does **not** add a second refusal — `SubscriptionGate` has already told the user. |
| **IME / keyboard** | `onboarding_contact_step_keyboard_test.dart` (6 cases) asserts geometry against the keyboard line, never calls `ensureVisible`, simulates the IME via `tester.view.viewInsets`, and guards harness preconditions. Mutation evidence recorded (3/3 red without the fix). |
| **PIN / layout** | `unlock_screen_density_overflow_test.dart` (248 lines) + `layout_size_matrix_test.dart` — 90 cells over 6 viewports × 3 scales to ceiling 2.0, **0 overflowing**, with a genuine in-file negative control that overflows by 2573 px. |
| **Re-auth lock** | **CLEAN.** `lockAfterSeconds = 120`; `onPaused()` uses `_pausedAt ??= DateTime.now()` so the **earliest** timestamp wins — repeated Android background states cannot shorten measured background time. `inactive`/`hidden`/`paused` all start the clock (errs safe). |
| **Restoration** | `state_restoration_policy_test.dart` (287 lines) green; real process death recorded on device in `docs/audit/device-verification-2026-08-14-state-restoration.md`. |
| **Reduce motion** | **CLEAN, verified exhaustively.** Every `.repeat(` in `lib/` is now inside `ReducedMotionPolicy`; the only other two occurrences are comments recording the old defect. A suppressed pulse parks at `0.5`, not `0.0` — the "stuck at the dimmest frame" trap is closed. |
| **Destructive confirmation** | **CLEAN.** `_confirmAndDeleteEntry` names the entry, requires an explicit confirm, and `_deleteEntry` runs only on `confirmed == true`. |

---

## Current-tree verification

Every command below was run against HEAD `6407901` with a clean worktree, exit
codes captured directly (no pipeline masking).

| Check | Command | Result |
|---|---|---|
| **ANALYZE** | `flutter analyze --no-fatal-infos` | **No issues found!** (2.7 s) · rc=0 |
| **TESTS** | `flutter test --no-pub` | **1601 passed / 0 failed** · rc=0 |
| **AUDIT ACCOUNTING** | `python3 scripts/verify_audit_accounting.py` | `AUDIT_ACCOUNTING_PASS 1738/1738/0/0/0` · rc=0 |
| **EVIDENCE INTEGRITY** | re-ran all 11 verifiers, diffed vs committed | **0 substantive differences** |
| **NEGATIVE CONTROLS** | 11 × `--negative-control` | **11/11 PASS**, all rc=0 |
| **SECRET SCAN** | `scan_release_secrets.py --require-clean` | `RELEASE_SECRET_SCAN_PASS` — 835 text + 46 binary, **0 findings** · rc=0 |
| **OSV** | `audit_dependencies_osv.sh --output <path>` | `OSV_EVIDENCE_PASS` — 197 pub + 203 maven queries, **0 findings** · rc=0 |
| **RELEASE CLASSIFICATION** | `verify_release_change_classification.py` | `PASS`, `classified_paths=0` on a clean tree. **Negative-controlled**: an unclassified file → `RELEASE_CHANGE_CLASSIFICATION_FAIL`. Non-vacuous, but a PASS here on a clean tree carries no release information. |
| **CRITICAL COVERAGE** | `dart scripts/verify_critical_coverage.dart` | `CRITICAL_COVERAGE_PASS` — all 5 files ≥ 90 % (99.18 / 95.04 / 94.87 / 90.81 / 93.08) · rc=0 |
| **BUILD (production)** | `scripts/build_production.sh` | **Fails closed, verified 3 ways** — see below |
| **EMULATOR** | not re-run | Device evidence in `docs/audit/device-verification-*.md` reviewed as documents, not re-executed. Emulator/OEM rows remain external. |
| **GIT STATUS / DIFF** | `git status --porcelain` | empty before and after |

### Production AAB / RevenueCat limit — verified fail-closed

I negative-controlled the production build gate directly:

| Input | Outcome |
|---|---|
| `REVENUECAT_ANDROID_API_KEY=placeholder_key` | **REFUSED** — "production public SDK key değil" |
| `REVENUECAT_ANDROID_API_KEY=NON_RELEASE_SMOKE_REVENUECAT_KEY` (the value `verify_release.sh` uses) | **REFUSED** |
| variable unset | **REFUSED** — "bulunamadı" |

Only a `goog_`-prefixed key is accepted. This is the correct behaviour: a
placeholder cannot produce an apparently-valid production artifact, and the
smoke/local candidate build is provably **not** a production release — the
production script rejects the exact key the smoke chain uses. The credential is
documented as external blocker **E1**. This is not a repository defect.

---

## Findings

### FIR-01 — A failed call is reported as "No action completed" while targets reached

- **Severity: P2** (emergency-surface correctness; not call-preventing)
- **Requirement: MP-01-027** (claimed PASS)
- **Builder claim challenged:** *"`[reached, notReached, reached]` is provably
  distinguishable in both the ledger **and the rendered screen**."*
- **Preconditions:** panic dispatch; automatic call request not submitted **and**
  `ACTION_DIAL` unavailable, i.e. `EmergencyCallResult.failed`.
- **Evidence / reproduction:** `countdown_screen.dart` passes
  `shouldRunBestEffort: (result) => result != null`, and a *failed* result is
  non-null — so the four bookkeeping targets **do** run. My probe reproduced the
  exact ledger the app builds in this state:
  `reachedCount = 4`, `notReachedCount = 2`, `isPartial = true`,
  `summary = mixed`. The screen then takes
  `if (callResult.isFailed) { … _showBlockingFailure(...); return; }` — it
  returns **before** `EmergencyCallScreen` is constructed, so `dispatchLedger`
  is never handed over. Asserted against source: the failure branch contains
  `return;` and the substring `ledger` **does not appear in it at all**.
- **Observed:** the user is shown `emergency_total_failure_title` —
  TR *"Hiçbir işlem tamamlanmadı"* / EN *"No action completed"* — plus a phone
  number. `_showBlockingFailure` renders title, body, number and an optional
  message; **no per-target information**.
- **Expected:** an absolute negative claim must not be made while the ledger says
  four targets were handed off. This is the same defect class MP-01-027 exists to
  remove, inverted: successful handoffs collapse into "nothing happened".
- **Why it was missed:** `emergency_dispatch_pipeline_test.dart` tests the ledger,
  and `emergency_per_target_outcome_test.dart` tests the renderer. Neither test
  the branch where the renderer is **never reached**. `flows.py`'s
  `partialSuccessSurfaces` counts files and outcome names, so it cannot see a
  discarded value.
- **Corroboration:** the Check-In escalation path (`check_in_service.dart:599`)
  navigates to `EmergencyCallScreen` with the ledger **unconditionally** — the two
  paths that `DispatchLedgerRecorder` exists to keep identical have diverged.
- **IN_REPO_RESOLVABLE: YES.**
- **Direction:** either render `DispatchOutcomeList` inside the blocking-failure
  dialog, or make the copy conditional on `ledger.reachedCount == 0`. Do not
  weaken the ledger.

### FIR-02 — The typed notification outcome is discarded at 2 of 4 live call sites

- **Severity: P2**
- **Requirements: MP-11-014, MP-23-010, MP-26-006** (all claimed PASS)
- **Builder claim challenged:** *"`showEmergencyAlert` returned void and made
  'suppressed' indistinguishable from 'posted' … Verify that this defect is
  actually gone **throughout all call sites**."* It is not.
- **Evidence / reproduction:** four live call sites exist.

  | Site | Outcome consumed? |
  |---|---|
  | `emergency_bookkeeping.dart:54` (panic) | **yes** — recorded in the ledger |
  | `check_in_service.dart:586` (escalation) | **yes** — via `runRecorded` |
  | `check_in_service.dart:497` `_showGraceNotification` | **no** — awaited, result dropped, wrapped in bare `catch (_) { // Notification not critical }` |
  | `safe_walk_screen.dart:222` `_firePreExpiryWarning` | **no** — not awaited, not `unawaited()`, result never captured |

  Asserted in a probe: the 120 characters preceding the Safe Walk call contain no
  `await`, no `unawaited(`, no `=`; `_showGraceNotification`'s body contains
  `showEmergencyAlert`, contains `catch (_)`, and never mentions
  `DispatchTargetOutcome`.
- **Observed:** if notifications are off or `POST_NOTIFICATIONS` is revoked, the
  **Check-In grace warning** (the 60-second "confirm you are safe or we call your
  contact" notice) and the **Safe Walk pre-expiry warning** are silently
  suppressed. Both are safety surfaces; both are exactly the "suppressed reads as
  posted" shape. The Safe Walk call is additionally an unmarked fire-and-forget
  `Future`, so a throw becomes an unhandled async error.
- **Expected:** the outcome is consumed, or the site is explicitly documented as
  one where suppression is acceptable.
- **Why it was missed:** the verifier property is a **substring check** —
  `"postReportsSuppression": "suppressedByUserSetting" in service`. It proves a
  string exists in one file. It structurally cannot observe a dropped return
  value. This is the "a static grep proving a string exists does not prove user
  behaviour" failure mode.
- **Mitigation that exists:** the category screen shows a standing warning for a
  muted safety channel, so the user *can* learn — just not at the moment it matters.
- **IN_REPO_RESOLVABLE: YES.**
- **Direction:** consume the outcome at both sites (Check-In can surface it the
  way the escalation path already does), and add a call-site rule to
  `interaction.py` — "every `showEmergencyAlert` call assigns or records its
  result" — instead of a substring test.

### FIR-03 — Six FAIL rows assert the absence of documents the repository contains, and are scoped as external / product-decision

- **Severity: P2** (material audit-integrity defect; directly falsifies
  `IN_REPO_RESOLVABLE = 0`)
- **Requirements: MP-53-012, MP-65-004, MP-65-005, MP-65-006, MP-65-007,
  MP-79-012, MP-79-013**
- **Builder claim challenged:** *"all remaining unresolved requirements belong
  only to genuine external blockers or genuine product decisions"*, and
  `IN_REPO_RESOLVABLE = 0`.
- **Evidence / reproduction:**

  `MP-65-004/005/006/007` all carry one pasted sentence:
  > *"DOC: no ticketing system, ownership model, **severity scale or
  > response-time commitment** exists in the repository."*

  `docs/release/incident_runbook.md` §1 **is** a severity scale — S1–S4 with a
  *"Hedef ilk yanit"* (target first response) column per level, and the line
  *"cagrilma yolunu geciktiren veya engelleyen her sey S1'dir"*. §6 **is** a
  stated response expectation — a channel table with *"3 is gunu"*. §6 is even
  tagged `(MP-77-021)`, and MP-77-021 cites that exact section as PASS.
  So `MP-65-006` ("Severity levels") and `MP-65-007` ("Response expectations")
  are graded **FAIL** on evidence the same repository refutes.

  `MP-53-012` evidence: *"No **restore runbook**, failover runbook … or DR drill
  exists."* Its remediation asks for *"one short DR document covering the three
  real scenarios — lost signing key, compromised Play account, bad release
  already rolled out"*. `docs/release/dr_and_key_custody.md` §3, §4, §5 are
  **exactly those three runbooks**, and MP-77-014 / MP-77-020 cite the file as
  PASS evidence.

  `MP-79-012/013` remediation: *"Make that substitution explicit in the postmortem
  template."* `incident_runbook.md` §7 item 3 does precisely that, in italics:
  *"Bu sorunun bu üründe kalıcı cevabı vardır: monitoring yoktur … buraya bir kez
  yazılmıştır."*

- **Observed:** three documents disagree with the tree and with each other —
  `PRODUCTION_AUDIT.md` (6 FAIL rows), `RESOLUTION_QUEUE.md` (6 rows scoped
  `EXTERNAL_BLOCKER` / `PRODUCT_DECISION_REQUIRED`), and
  `PRODUCT_DECISIONS_REQUIRED.md` **D-5** (*"no severity ladder and no stated
  response expectation"*; Option B = *"define severity levels … state response
  targets"*, marked *"Blocked? Yes"*). D-5 predates the runbook by one day
  (13 Aug vs 14 Aug) and was never revisited.
- **Expected:** a row whose stated gap the repository has since closed is
  re-graded, or its evidence is corrected to name what genuinely remains
  (for MP-53-012: only the *rehearsal*; for the 65-cluster: only *naming an
  owner* and the KVKK-log location).
- **Why it was missed:** these six rows are hand-written prose, outside the
  verifier system entirely. The accounting verifier checks that every requirement
  has a row — never that a row's evidence is still true. And the 65-cluster is
  precisely the "one section-level sentence pasted verbatim across rows" defect
  that `common.py` says the evidence system was built to eliminate; four rows
  still carry it, and it is now false.
- **IN_REPO_RESOLVABLE: YES** — re-grading these rows and correcting three
  documents is repository work, requiring no external system.
- **Direction:** re-verify every FAIL/BLOCKED row whose evidence names a missing
  document against the current tree; add a check that any repo path cited as
  *absent* really is absent.

### FIR-04 — Every evidence artifact names a stale, dirty revision; one names none

- **Severity: P3** (provenance metadata; substance verified intact)
- **Requirements:** all 238 rows carrying *"MEASURED, not asserted"*
- **Builder claim challenged:** *"the artifact carries the code revision it was
  measured against"* (repeated in ~238 remediation cells), and `common.py`'s own
  contract: *"Evidence that cannot name the tree it proves is not evidence."*
- **Evidence:** at HEAD `6407901`, all 11 committed Python artifacts carry
  `codeRevision = {head: "c6d197d35…", dirty: true}` — four commits behind HEAD,
  and `dirty:true` means the measured tree corresponds to **no commit at all** and
  cannot be reconstructed. `text_scale.json` has **no `codeRevision` and no
  `measuredOn`**, violating contract items 2–4 outright.
- **Materiality — measured, not assumed:** I re-ran all 11 verifiers at HEAD and
  diffed. **Zero substantive differences.** The claims are true of HEAD; only the
  stamp is wrong. Hence P3, not P2.
- **Why it matters anyway:** this is the same class as `INDEPENDENT_REVIEW_ROUND_2`
  finding R2-08, which `PRODUCTION_AUDIT.md`'s own provenance section says was
  fixed — reintroduced one layer down, in the artifacts the fix pointed readers to.
- **IN_REPO_RESOLVABLE: YES.**
- **Direction:** regenerate the artifacts on a clean tree at the final commit;
  give `text_scale.json` the same `codeRevision` block; consider having verifiers
  refuse to emit when `dirty` is true.

### FIR-05 — `PRODUCTION_AUDIT.md`'s provenance stamp and baseline table are stale

- **Severity: P3**
- **Builder claim challenged:** the document's own header table —
  *"VERIFIED CODE REVISION — the tree every `TEST`/`CMD`/`RUN` result below was
  produced against: `273864f`"*.
- **Evidence:** HEAD is `6407901`. `git log --oneline 273864f..HEAD` = **43
  commits**; `git diff --stat 273864f..HEAD -- lib android test` = **129 files,
  14 337 insertions, 658 deletions**, including the safety-critical files whose
  rows were rewritten (`countdown_screen.dart`, `notification_service.dart`,
  `image_sanitizer_service.dart`, the whole `lib/core/navigation/` package).
  The "Baseline commands run" table is stale in the same way: it records
  `flutter test --no-pub` → **1139 passed** (I measure **1601**) and the secret
  scan over **733** text files (I measure **835**).
- **Expected:** the stamp names the graded tree, or the table is regenerated.
  This is verbatim the R2-08 defect the section above it exists to explain.
- **IN_REPO_RESOLVABLE: YES.** Documentation-only.

### FIR-06 — Negative controls are per-verifier, not per-property; the audit's Gap sentence overstates them

- **Severity: P3**
- **Requirements:** the 238 *"MEASURED"* rows, most visibly the 19 `layout.py` rows
- **Evidence:** `common.run_negative_control` compares the **total** violation
  count (`len(mutated) <= len(baseline)`) for the whole verifier. `layout.py`
  supports **19 distinct cited measurement properties** but has **one** control —
  *"two `EdgeInsets.only` gutters differing >4 dp → 2 violations"*, which breaks
  the gutter-symmetry rule only. Yet e.g. `MP-01-004` cites
  `measurements.attentionOrder.competingGlowSites = []` and then states in its
  Gap column: *"None. The cited property is the measurement, and the negative
  control shows the verifier can report the opposite."* The control shows a
  **different rule** can report the opposite. Same shape for `motion.py`
  (17 properties / 1 control), `typography.py` (11 / 1), `copy.py` (13 / 1),
  `color.py` (15 / 1), `assets.py` (2 / 1).
- **Not vacuous, but overstated:** many such properties are descriptive census
  values with no violation rule at all, so no control can cover them. The defect
  is the boilerplate Gap sentence asserting otherwise.
- **Also noted:** `assets.py`'s control has a **non-zero baseline** (1 → 3). The
  harness's own comments say a red baseline hides whether the mutation did
  anything; it is tolerated here only because the delta is unambiguous.
- **IN_REPO_RESOLVABLE: YES.**
- **Direction:** make the control assert the *specific rule* fired, and reword the
  Gap sentence for rows whose property no rule guards.

### FIR-07 — `AuthGate` is dead code that builds `MainNavigation` with no gates

- **Severity: P3** (unreachable today; structurally contradicts the MP-26-008 argument)
- **Requirement: MP-26-008**
- **Evidence:** `lib/screens/auth_gate.dart` — `build()` returns
  `const MainNavigation()` unconditionally. `grep -rn "AuthGate" lib/ test/`
  returns **only its own declaration**: zero references anywhere.
- **Why it matters:** MP-26-008's security argument is *"gate ordering is a
  property of construction order, not of a conditional"*. That argument holds only
  while every `MainNavigation()` construction sits behind the gates. There are
  five construction sites; four are correctly gated by `SplashScreen`/onboarding,
  and this one is a ready-made, self-describing bypass one import away from use.
  No verifier or test guards the construction sites.
- **IN_REPO_RESOLVABLE: YES.**
- **Direction:** delete the file, and add a rule to `flows.py` bounding
  `MainNavigation()` construction sites the way `parkConsumers` is already bounded.

### FIR-08 — The volume growth assertion is much weaker than the audit describes

- **Severity: P3**
- **Requirement: MP-47-011**
- **Evidence:** the audit says *"growth no worse than proportional, asserted as a
  ratio rather than an absolute millisecond bound"*. The actual assertion
  (`high_volume_timeline_test.dart:86`) is
  `expect(timings[10000]! / timings[100]!, lessThan(1000))` — for a **100×** data
  increase. Proportional growth is a ratio of ~100; the bound permits **10×
  worse than proportional** before going red. It would catch a quadratic blowup
  (ratio ≈ 10 000) but not, say, `n^1.5`.
- **Assessment:** the loose bound is defensible engineering (an absolute
  millisecond bound would flake in CI); the *description* is the defect.
- **IN_REPO_RESOLVABLE: YES.** Reword the evidence, or tighten toward the measured
  reality (3522 / 2461 / 7914 µs → actual ratio ≈ 2.2).

---

## External launch blockers

Independently verified as **9 categories**, not a bare count of 112. Each names a
specific unavailable external resource — none cites difficulty, cost or effort.

| ID | Category | Unavailable resource | Rows |
|---|---|---|---|
| **E1** | Play billing lifecycle | RevenueCat sandbox key + Play internal-test account (licensed tester) | the whole §54 cluster + MP-73-010, MP-74-007, MP-77-001 |
| **E2** | Physical Android hardware | Aggressive-OEM device for Doze, battery managers, real telephony | MP-41-017, MP-41-021, MP-59-027, MP-59-030, MP-77-013 |
| **E3** | Google Play policy review | Google's case-by-case decision on `CALL_PHONE`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `specialUse` FGS | MP-59-029, MP-62-020, MP-77-023 |
| **E4** | Account security / key custody | Play Console + GitHub MFA and App Signing enrolment state | MP-53-003, MP-63-006, MP-77-009 |
| **E5** | Release keystore | Full `verify_release.sh` signed chain | release-artifact rows |
| **E6** | Post-launch operational data | Nothing exists to measure before a rollout | MP-77-024 (canary), monitoring rows |
| **E7** | Real-user usability testing | 5 unassisted participants | §46 usability rows |
| **E8** | TalkBack on hardware | Physical screen-reader pass | MP-46-030, MP-77-005 |
| **E9** | Operational tooling absent by design | — | see caveat |

**All nine are genuine** — each names a system, device, account or human decision
that cannot exist inside the repository. **E1 is corroborated by direct test**:
the production build script refuses placeholder, smoke and missing keys.

**Caveat:** MP-53-012 is currently filed under this heading and should not be —
see FIR-03. Its in-repo half is complete; only the *rehearsal* is external.

## Product decisions

Independently verified as **9 groups**, not a bare 55.

| ID | Decision | Genuinely blocked on an owner? |
|---|---|---|
| **D-1** | Is the light theme supported, or deleted? | **Yes** — scope decision, and CLAUDE.md rule 4 reserves visual changes to the owner |
| **D-2** | Route typography through `TextTheme`? | **Yes** — 329 inline `fontSize` sites; a refactor with visual risk |
| **D-3** | Is portrait-phone-only still the scope? | **Yes** — product scope |
| **D-4** | Android 16 / API 37 large-screen compatibility | **Yes** — scope + future platform |
| **D-5** | What is the support channel, actually? | **PARTLY FALSE — see FIR-03.** Option B (severity levels + response targets) is already written in `incident_runbook.md` §1/§6 |
| **D-6** | Accept having no telemetry? | **Partly** — the standing decision is real, but MP-79-012/013's named remediation is already done (FIR-03) |
| **D-7** | Runtime feature flags: none exist | **Yes** — deliberate architecture choice |
| **D-8** | Residual local-tamper risk on entitlement | **Yes** — genuine risk-acceptance decision |
| **D-9** | Product-scope N/As needing re-confirmation | **Yes** — owner confirmation |

**7 of 9 are genuine.** D-5 and D-6 carry stale text that hides completed
repository work.

---

## Final assessment

**REPOSITORY CONVERGENCE — not confirmed.**

The engineering underneath this claim is unusually strong, and I want to be
precise about that because it makes the finding narrower, not softer:

- Canonical accounting is **exact** — 1738/1738, zero missing, zero duplicated,
  zero unaccounted, reproduced by an independent parser including text and
  section-placement parity, which the builder's own verifier does not check.
- Every status and severity count reproduces to the unit.
- **All 12 negative controls are real** and break properties the verifiers
  genuinely guard.
- **All 12 evidence artifacts reproduce byte-identically at HEAD** — the hardest
  test I could apply to a measurement system, and it passed with zero drift.
- Analyze clean, **1601/1601 tests green**, secret scan clean, OSV clean,
  critical coverage ≥ 90 % on all five safety files.
- The production build **fails closed** on placeholder, smoke and missing
  credentials — verified by direct negative control, not by reading the script.
- Of the final 14, **eleven survive** independent attack outright, several
  emphatically: I could not break the EXIF sanitiser with my own metadata-laden
  fixtures, could not escape the deep-link allowlist through normalisation or
  duplicate parameters, could not make the DB integrity policy confuse structural
  damage with referential damage, and could not make the dispatch ledger collapse
  two different outcomes into one.

But the claim under review is **not** "the repository is in good shape". It is
the absolute statement `IN_REPO_RESOLVABLE = 0` — that **zero** repository work
remains. That statement is false, and three independent findings prove it:

1. **FIR-01** — the panic path's total-failure branch tells the user *"No action
   completed"* while its own ledger records four targets reached, and discards
   the ledger built to prevent exactly that. On the requirement (MP-01-027) whose
   entire purpose is that outcomes must not collapse.
2. **FIR-02** — the "suppressed vs posted" defect the builder reports as
   eliminated survives at 2 of 4 live call sites, both of them safety
   notifications, and the verifier property vouching for the fix is a substring
   test that cannot see a dropped return value.
3. **FIR-03** — six FAIL rows assert the absence of documents the repository
   contains, and are filed as external blockers or product decisions while the
   repository work they name is already committed. `MP-65-006` ("Severity
   levels") is graded FAIL against a repository containing a severity ladder;
   `MP-65-007` ("Response expectations") against one containing stated response
   targets; `MP-53-012` against three DR runbooks that its own remediation asks
   for. That is both a false classification and a false FAIL.

Five further P3 findings (FIR-04 through FIR-08) concern provenance staleness,
overstated negative-control coverage, a dead gate-less navigation constructor,
and an evidence description stronger than its assertion.

None of these is catastrophic. **No new P0 was found, and no P1.** But this is a
convergence certification, and the rule is explicit: one legitimate remaining
in-repo defect disproves the claim. There are eight, three of them P2, and one
of them (FIR-01) sits in the emergency dispatch path.

**LAUNCH READINESS** is a separate matter and is not affected by this verdict:
the nine external blocker categories and seven of the nine product-decision
groups are genuine, and would still stand between this repository and a
production rollout even if every finding above were closed today. A PASS here
would never have meant launch-ready.

The remediation is small and well-bounded — one branch in `countdown_screen.dart`,
two call sites, and a documentation re-verification pass over the FAIL/BLOCKED
rows. I would expect this to converge on a second attempt.

---

# `FINAL INDEPENDENT REVIEW FAILED — REMEDIATION REQUIRED`
