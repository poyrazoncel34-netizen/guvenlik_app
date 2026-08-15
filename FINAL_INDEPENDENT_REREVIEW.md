# FINAL INDEPENDENT RE-REVIEW — KoruBeni

Independent re-review of the convergence claim `IN_REPO_RESOLVABLE = 0`.
The reviewer did not implement any part of the reviewed tree and changed no
production code, test, verifier, audit row, evidence artifact or document.
Temporary probes were used and removed; the worktree is clean apart from this
file.

This document is NEW. `FINAL_INDEPENDENT_REVIEW.md`, `INDEPENDENT_REVIEW.md`
and `INDEPENDENT_REVIEW_ROUND_2.md` are untouched.

---

## 1. Repository identity — confirmed

| Fact | Claimed | Independently measured | Verdict |
|---|---|---|---|
| FINAL HEAD | `c5600ff` | `c5600ff15abd2c761b9359dcf5f84c66eab664e5` | MATCHES |
| VERIFIED IMPLEMENTATION REVISION | `ef40178` | `ef40178ce7d41241baad26350aa3a242a0ba2d11` | MATCHES |
| `ef40178` tree hash | `0aa600f9…` (in artifacts) | `git rev-parse ef40178^{tree}` = `0aa600f9a9748fa1e49cd11c10f78db324ba4b99` | MATCHES |
| `ef40178..c5600ff` touches no measured surface | claimed | `git diff ef40178..c5600ff -- lib android test scripts assets config` is EMPTY | CONFIRMED |
| `ef40178..c5600ff` content | docs + regenerated evidence only | 4 `.md` + 12 `docs/audit/evidence/*.json`; every JSON hunk is the `codeRevision` block alone | CONFIRMED |
| Worktree at review start | clean | `git status --porcelain` empty | CONFIRMED |

The three-fact provenance model (verified implementation revision / evidence
revision / documentation head) is sound and the self-reference problem is
modelled rather than wished away.

---

## 2. Accounting — recomputed independently, reproduces exactly

An independent parser was written before running any repository tooling. It
parses `docs/MASTER_PRODUCTION_CHECKLIST.md` from scratch, derives canonical
IDs, parses only 9-column canonical rows out of `PRODUCTION_AUDIT.md`, and
compares text, placement and ID derivation.

| Metric | Claimed | Independently recomputed |
|---|---|---|
| Sections | 80 | **80** |
| Checkbox requirements | 1714 | **1714** |
| Section-77 matrix requirements | 24 | **24** |
| TOTAL | 1738 | **1738** |
| Audit canonical rows | 1738 | **1738** |
| MISSING | 0 | **0** |
| DUPLICATED | 0 | **0** |
| UNACCOUNTED | 0 | **0** |
| Requirement text parity mismatches | — | **0** |
| Section placement mismatches | — | **0** |
| PASS | 799 | **799** |
| FAIL | 2 | **2** |
| PARTIAL | 69 | **69** |
| BLOCKED | 38 | **38** |
| N/A | 779 | **779** |
| UNVERIFIED | 51 | **51** |

Sum = 1738. Severity distribution: P1 = 29, P2 = 112, P3 = 19, none = 1578.
Unresolved = 2 + 69 + 38 + 51 = **160**, matching `RESOLUTION_QUEUE.md`
(EXTERNAL_BLOCKER 110 + PRODUCT_DECISION_REQUIRED 50).

Only after that: `python3 scripts/verify_audit_accounting.py` →
`AUDIT_ACCOUNTING_PASS checklist=1738 audit=1738 missing=0 duplicated=0
unaccounted=0 sections=80 launchMatrix=24`. No canonical mapping defect exists.

---

## 3. FIR-01 — emergency result JOIN — SURVIVES

Attacked as a JOIN, not as components. A probe drove the **real**
`EmergencyDispatchPipeline.execute` with the production wiring copied verbatim
from `countdown_screen.dart:368-370` (`recordCriticalOutcome:
DispatchLedgerRecorder.recordCallTargets`, `shouldRunBestEffort: (result) =>
result != null`), then `EmergencyResultPolicy.decide`, then
`EmergencyFailureDialog` rendered against the real `tr-TR` catalogue.

**14,640 policy evaluations** across 4 call results × every uniform and
one-target-differs assignment of {10 outcomes, null, 5 throwables} over the 4
panic bookkeeping targets × 4 failure reasons, plus `decide()` at each point.

**Zero violations** of the invariant "absolute claim ⟹ zero reached".

Rendered results (real Turkish catalogue, real dialog):

| scenario | reached | notReached | unknown | absolute headline shown |
|---|---|---|---|---|
| all bookkeeping reached (**the old `reached=4 / notReached=2` bug**) | 4 | 2 | 0 | **no** |
| notification suppressed by user setting | 3 | 3 | 0 | no |
| only haptic reached | 1 | 5 | 0 | no |
| one step throws | 3 | 3 | 0 | no |
| unknown + one reached | 1 | 2 | 3 | no |
| all definitively denied | 0 | 6 | 0 | yes (correct) |

- The old `reached = 4, notReached = 2` case reproduces exactly and produces
  `partialFailureTitleKey`, not the absolute copy.
- `EmergencyFailureCopy` has no public constructor; `emergency_result_policy.dart`
  is a single `library;` with no `part` files, so no other file can build it.
- `bodyKeyOverride` cannot smuggle an absolute claim: it is honoured only while
  `supportsTotalFailureClaim` still holds, and the TITLE is never overridable.
- `emergency_total_failure_title/body` appear in exactly one production file.
  A translation-catalogue sweep for absolute-failure phrasing (TR and EN) found
  no second key that could carry the claim.
- The pipeline awaits every best-effort step before returning, so the ledger the
  policy reads is complete; `catch on Exception`/`on Error` inside the loop means
  the only throw that can escape `execute` comes from the critical operation,
  before any bookkeeping — which is what makes `dispatchThrew` nulling the ledger
  sound.
- Panic and Check-In share `DispatchLedgerRecorder` and `DispatchOutcomeList`;
  Check-In's failed-call surface (`EmergencyCallScreen`) renders
  `emergency_flow_partial_title` plus the per-target ledger and never the
  absolute copy. No divergence that produces a false claim.

Residual, recorded as **RER-05** below: the invariant guards `reachedCount` only,
not `unknownCount`.

---

## 4. FIR-02 — notification outcomes — SURVIVES on the current tree

Independent enumeration (broad `grep` over all of `lib/`, any receiver form),
not the verifier's regex:

| site | consumed |
|---|---|
| `lib/core/services/emergency_bookkeeping.dart:54` | yes — `run: () =>` into the pipeline ledger |
| `lib/core/services/safety_alert_dispatch.dart:32` | yes — `final outcome = await` |
| `lib/core/services/check_in_service.dart:597` | yes — `() =>` into `runRecorded` |
| `lib/core/services/check_in_service.dart:512` (wrapper) | yes — returned, stored at `:490` and `:745` |
| `lib/screens/safe_walk_screen.dart:238` (wrapper) | yes — `final outcome = await`, drives a SnackBar |

Five live sites, five consumed. `SafetyAlertDispatch.postWarning` is the only
wrapper and both its callers consume. `handleNativeGraceStarted` (`:745`) stores
the outcome in `_lastGraceAlertOutcome`, which the Check-In screen reads. No
dropped Future, no bare `catch` swallowing an outcome, no void-returning wrapper.

**Mutation test** — four realistic dropped-result forms in a temporary probe:

| form | rule fires |
|---|---|
| bare call, result dropped | **yes** |
| `await …;` result dropped | **yes** |
| async closure swallows result | **yes** |
| `final svc = NotificationService.instance; await svc.showEmergencyAlert(…)` | **NO — not even enumerated** |

Recorded as **RER-04**. No such site exists today, so FIR-02 holds for this tree.

---

## 5. FIR-03 — stale absence claims — ONE MISS FOUND

`config/absence_claims.json` holds 44 claims; `verify_absence_claims.py` →
`ABSENCE_CLAIMS_PASS`, and its negative control fires `REFUTED_ABSENCE_CLAIM`.
The rows the builder names were re-checked independently and are correct:
`MP-53-012`, `MP-65-004/005/006/007`, `MP-79-012/013`, `MP-47-017`, `MP-69-010`,
`MP-78-001/002/003`, `MP-76-007` — each now cites the document that actually
exists, and D-5, D-6 and E9 carry honest, dated corrections that name what was
already written.

**Coverage gap.** The verifier scans the **evidence cell only** (`cells[4]`).
Gap and Remediation cells are never scanned. A broader independent scan over all
cells of all 160 unresolved rows surfaced 48 unregistered absence-shaped
statements. Hand-review cleared all but one:

- **`MP-32-046`** remediation: *"Document explicitly in the incident-response
  runbook that post-incident evidence depends on the user submitting their local
  log."* — `docs/release/incident_runbook.md` §6 (lines 98–100) already says
  exactly that. Recorded as **RER-03**. FIR-03's own sweep commit (`ef40178`)
  addressed **BLOCKED** remediation texts; this row is **PARTIAL**.

---

## 6. Provenance — SURVIVES

- 11 of 12 artifacts stamp `verifiedCodeRevision = ef40178…`, `dirty: false`,
  `treeHash = 0aa600f9…`, `measuredOn: 2026-08-15` **as committed at HEAD**.
  `text_scale.json` likewise. The tree hash is the real `git rev-parse
  ef40178^{tree}`, not user-controlled metadata.
- **Reproducibility: all 12 artifacts regenerate byte-identically** (modulo the
  `codeRevision` block) when re-run at `c5600ff`, whose measured surface is
  byte-identical to `ef40178`. 12/12 reproduce, 0 differ.
- **Dirty-tree refusal works.** With one real source file modified
  (`lib/core/services/dispatch_outcome.dart`), `color.py` exits 1 with
  `REFUSING_TO_EMIT color.json: the working tree is dirty outside
  docs/audit/evidence/…` and the Dart verifier prints
  `REFUSING_TO_EMIT text_scale.json: worktree dirty outside …`. Neither wrote.
- `text_scale.json` follows the same contract: `codeRevision`, `measuredOn`,
  `propertyClasses`, and an embedded negative control (an inflexible Row at
  scale 2.0 overflowing by 2573 px) proving the instrument can report failure.

One defect found in the surrounding machinery, recorded as **RER-02**: running
the test suite dirties the worktree, and the documented baseline command set
cannot then be run in sequence.

---

## 7. ENFORCED vs CENSUS — truthful

Recomputed independently from the artifacts:

| Metric | Claimed | Recomputed |
|---|---|---|
| ENFORCED properties | ~161 | **161** |
| CENSUS properties | ~1192 | **1192** |
| Rules emitted | 114 | **114** |
| Rules under negative control | 40 | **40** |
| Rules emitted without control | — | 74 (declared per artifact) |

Every audit row citing an artifact property was checked against that artifact's
`propertyClasses`:

- 193 rows cite a property.
- **166 state a classification and 166 match the artifact. 0 mismatches.**
- 21 cite a property without stating a classification (all CENSUS in the
  artifact); their evidence text does not claim a mutation proves them.
- 6 cite `text_scale.json` viewport keys, which are structured differently.

`grep` for the boilerplate the review warned about — *"negative control proves
the opposite"* — returns **0 occurrences**.

Non-zero baselines are honest: `color.py` carries **5 open violations at
baseline** (2 × `textContrastBelowAA` / `nonTextContrastBelow3`, 2 ×
`tintedContainerTextBelowAA`, each with the measured ratio and the exact site),
its control moves 5 → 9 and asserts per rule. Those open findings are carried as
`MP-06-014` PARTIAL with the measured ratios stated, not buried.
`assets.py` now declares enforced = 0 / census = 21 — the historical false
baseline is gone; its control still fires `demoAssetShipped` and
`referencedAssetMissing`.

---

## 8. Security gate architecture — SURVIVES

- `auth_gate.dart` is **gone** from the tracked tree (deleted in `ee7c153`). The
  only remaining copy is under `.claude/worktrees/`, which `.gitignore:48`
  excludes and which contains no tracked files.
- Every production construction of the tab shell: `onboarding_screen.dart:161`
  and `splash_screen.dart:228/232/235`. `SplashScreen` orders them
  consent → onboarding → PIN unlock → `MainNavigation`; the bare branch is
  reached only when consent and onboarding are done and no PIN is configured.
- Deep links and notification taps cannot navigate. Both only **park** a
  destination in `PendingDestinationService`; the park is single-consume
  (`consume()` nulls it) and is read **only** from inside `MainNavigation`
  (`:110/:130/:150`), i.e. behind the gates. `notification_service.dart:236`
  routes through the same park.
- `DestinationRouter` applies the entitlement gate through the same
  `SubscriptionGate.ensureAccess` every in-app tap uses, and its `switch` has no
  default branch, so a new destination fails to compile rather than silently
  routing.
- `flows.py`'s control fires `ungatedTabShellConstruction`,
  `tabShellBuiltBeforeItsGate`, `deepLinkDestinationPerformsSafetyAction`,
  `multipleDestinationConsumers` — the rules exist and were exercised.

---

## 9. Performance claim language (MP-47-011) — SURVIVES

The row states the limit exactly: *"The ASSERTION is a ratio ceiling of 1000x,
not an absolute millisecond bound… it is a catastrophe guard that catches a
quadratic blow-up (ratio ~10000) and would NOT catch n^1.5. Proportional growth
is not claimed and cannot be claimed from wall-clock timing on shared CI."*
`test/core/services/high_volume_timeline_test.dart:88` carries the same framing.
A repo-wide search for `O(n)` / `linear` / `proportional` returns only
`TextScaler.linear` and the honest disclaimer. No complexity claim is made.

---

## 10. All 160 unresolved rows — reclassification review

Every one of the 160 was reviewed, not sampled. 135 name a concrete external
resource or a genuine owner decision on their face; the remaining 25 were
hand-reviewed against the tree.

- **Reviewed: 160**
- **Genuinely EXTERNAL: 109** — Play Console / internal-test track / licensed
  tester, RevenueCat sandbox, physical OEM hardware, real TalkBack or user
  observation, GitHub repo settings, post-launch production data. The recurring
  *"measure X on hardware and record it in `docs/audit/`"* pattern
  (`MP-41-021`, `MP-59-027`, `MP-59-030`, `MP-77-013`, `MP-48-006/007/008`) is
  correctly external: the recording is downstream of a measurement that cannot
  be taken here.
- **Genuinely PRODUCT_DECISION: 50** — D-1…D-9 each name a real unresolved
  owner choice. `MP-06-014` (contrast fix requires changing the brand palette,
  which CLAUDE.md rule 4 forbids unilaterally), `MP-08-008` and `MP-80-001`
  (adopting golden tests, a category this repo has deliberately excluded),
  `MP-50-012`/`MP-75-016` (D-7 flags), `MP-32-046/047` and `MP-75-012/013/014`
  (D-6 telemetry acceptance) all survive the challenge.
- **Falsely classified: 1** — `MP-41-017`, recorded as **RER-01**.

---

## 11. Current-tree verification

All run on `c5600ff`, real exit codes captured without pipelines.

| Check | Result |
|---|---|
| `flutter analyze --no-fatal-infos` | **No issues found!** — exit 0 |
| `flutter test --no-pub` | **1643 passed / 0 failed** — exit 0 (re-run, not reused) |
| `verify_audit_accounting.py` | `AUDIT_ACCOUNTING_PASS` — exit 0 |
| `verify_absence_claims.py` | `ABSENCE_CLAIMS_PASS registered=44` — exit 0 |
| `scan_release_secrets.py --require-clean` (clean tree) | `RELEASE_SECRET_SCAN_PASS` text=846 binary=46 findings=0 — exit 0 |
| `scan_release_secrets.py --require-clean` (after `flutter test`) | `RELEASE_SECRET_SCAN_FAIL` — exit 1 → **RER-02** |
| `audit_dependencies_osv.sh` | `findingCount: 0`, 203 maven queries — exit 0 |
| `verify_critical_coverage.dart` | `CRITICAL_COVERAGE_PASS` — all 5 files ≥ 90% — exit 0 |
| `verify_release_change_classification.py` (clean tree) | `PASS classified_paths=0` — exit 0 |
| 11 × `audit_evidence/*.py --negative-control` | **11/11 PASS**, each asserting named rules |
| `verify_absence_claims.py --negative-control` | PASS — `REFUTED_ABSENCE_CLAIM` |
| Dart verifier negative control | embedded and live (2573 px overflow) |
| Artifact regeneration | **12/12 reproduce byte-identically** |
| Dirty-tree refusal (real source edit) | both Python and Dart verifiers **refuse** |
| TODO / FIXME / stub in `lib/` + `android/app/src/main/` | **0** |
| Production build gate | intact (see §12) |
| `git status` at end | clean apart from this file |

MASVS, gate-evidence and external-release-gate verifiers require a signed AAB and
were not run — no signed artifact exists in this environment. Stated as a
limitation, not substituted with invented evidence. No emulator/device run was
performed; no changed user-visible behaviour was introduced by this review.

---

## 12. Production build gate — reconfirmed, not weakened

`android/app/build.gradle.kts` `isProductionRevenueCatAndroidSdkKey()` requires a
non-empty, whitespace-free value starting `goog_`, and rejects `sk_`,
`placeholder`, `dummy` and `non_release_smoke`. A Play release artifact
additionally requires `ENV=production`; a smoke release requires exactly
`ENV=ci_smoke` and the fixed sentinel; any other release flavour throws
`Release artifact flavor could not be proven safe`. A missing, placeholder or
smoke credential therefore cannot produce an apparently valid production build.

No credential was inserted and no gate was modified or weakened. Real Play /
RevenueCat validation remains external.

---

## 13. Findings

### RER-01 — `MP-41-017` is classified EXTERNAL_BLOCKER but carries undone in-repo work

- **SEVERITY:** P2
- **REQUIREMENT IDS:** `MP-41-017`
- **CLAIM FALSIFIED:** `IN_REPO_RESOLVABLE = 0`; `EXTERNAL_BLOCKER = 110` where
  every one of the 110 is said to be non-repository work.
- **PRECONDITIONS:** none — static.
- **REPRODUCTION:**
  1. `RESOLUTION_QUEUE.md:73` → `MP-41-017 | P1 | BLOCKED | EXTERNAL_BLOCKER`,
     remediation: *"Add an explicit 'incoming call during armed countdown' case
     to `store/REAL_DEVICE_QA_MATRIX.md` and run it on hardware with a licensed
     test account."*
  2. `grep -niE "incoming|gelen ara|gelen cag|interrupt|kesinti" store/REAL_DEVICE_QA_MATRIX.md`
     → no matches.
  3. Section C ("Emergency call paths") contains C1–C4 only: CALL_PHONE granted,
     CALL_PHONE denied, native Telecom failure, no-SIM/airplane. None covers an
     in-progress incoming call.
- **OBSERVED:** The row's own remediation names a repository edit that has not
  been made, while the row is filed as work the repository cannot do.
- **EXPECTED:** Either the QA case is authored (in-repo, no external resource
  needed — every other case in the matrix was authored before any hardware
  existed), or the remediation is rewritten so the external half is all that
  remains.
- **WHY EXISTING TEST/VERIFIER MISSED IT:** `verify_audit_accounting.py` checks
  coverage, not remediation feasibility. `verify_absence_claims.py` scans the
  evidence cell only and matches absence phrasing, not imperative repository
  work. Nothing cross-checks a remediation's named path against the tree.
  Applying the review's own test — *"what exact unavailable external resource
  prevents this from being completed in the repository?"* — a licensed tester is
  needed to RUN the case, not to WRITE it. The seven sibling rows
  (`MP-41-021`, `MP-59-027`, `MP-59-030`, `MP-77-013`, `MP-48-006/007/008`) are
  correctly external because their recording is downstream of an external
  measurement; this one is upstream of it.
- **IN_REPO_RESOLVABLE:** **YES**
- **REMEDIATION DIRECTION:** Author the QA case in section C of
  `store/REAL_DEVICE_QA_MATRIX.md`, then reduce the remediation to the hardware
  run. Do not reclassify without doing one or the other.

### RER-02 — running the test suite dirties the worktree and breaks the documented baseline sequence

- **SEVERITY:** P2
- **REQUIREMENT IDS:** `MP-33-001`, and the *Baseline commands* table in
  `PRODUCTION_AUDIT.md`
- **CLAIM FALSIFIED:** that every baseline command in that table was produced
  against one clean tree and reproduces by re-running the command in its row.
- **PRECONDITIONS:** clean worktree at `c5600ff`.
- **REPRODUCTION:**
  ```
  git status --porcelain                                    # empty
  python3 scripts/scan_release_secrets.py --require-clean --output /tmp/a.json
  # -> exit 0, RELEASE_SECRET_SCAN_PASS
  flutter test test/screens/layout_size_matrix_test.dart --no-pub
  git status --porcelain
  # ->  M docs/audit/evidence/text_scale.json
  python3 scripts/scan_release_secrets.py --require-clean --output /tmp/b.json
  # -> exit 1, RELEASE_SECRET_SCAN_FAIL "candidate source is dirty"
  ```
- **OBSERVED:** `test/screens/layout_size_matrix_test.dart` re-emits
  `docs/audit/evidence/text_scale.json` on every run, stamped with the CURRENT
  HEAD. A single test file — and therefore the full CI command
  `flutter analyze --no-fatal-infos && flutter test --no-pub` — leaves the tree
  dirty, after which the secret scan fails. The audit table records both as
  passing at `ef40178`; they cannot both pass in sequence without an
  undocumented `git checkout`.
- **EXPECTED:** Two cleanliness predicates in one repository should agree.
  `scripts/audit_evidence/common.py` deliberately whitelists
  `docs/audit/evidence/` as the package's own output;
  `scan_release_secrets.py --require-clean` does not.
- **WHY EXISTING TEST/VERIFIER MISSED IT:** each command is documented and run in
  isolation, and the evidence verifiers exempt exactly the directory that trips
  the secret scan, so the conflict is invisible unless the two are run in order.
  `scripts/verify_release.sh` does not invoke the secret scan, so the release
  chain does not surface it either.
- **IN_REPO_RESOLVABLE:** **YES**
- **REMEDIATION DIRECTION:** Align the secret scan's cleanliness predicate with
  `common.py`'s (exempt `docs/audit/evidence/`), or gate the Dart emitter behind
  an explicit opt-in so an ordinary test run does not write evidence. Failing
  either, document the reset step in the baseline table.

### RER-03 — `MP-32-046` remediation asks for documentation the runbook already contains

- **SEVERITY:** P3
- **REQUIREMENT IDS:** `MP-32-046`
- **CLAIM FALSIFIED:** that FIR-03 removed the stale-remediation class.
- **PRECONDITIONS:** none — static.
- **REPRODUCTION:** `MP-32-046` remediation reads *"Document explicitly in the
  incident-response runbook that post-incident evidence depends on the user
  submitting their local log."* `docs/release/incident_runbook.md` §6, lines
  98–100, reads *"Teshis, telemetri olmadigi icin **kullanicinin kendi yerel
  gunlugunu disari aktarmasina** dayanir: Ayarlar -> Yasal -> Verilerimi Disari
  Aktar (JSON). Destek yanitinin ilk adimi her zaman bu aktarimi istemektir."*
- **OBSERVED:** A reader following the remediation would write a sentence the
  repository already carries — the exact defect FIR-03 exists to remove.
- **EXPECTED:** The remediation should cite §6 as satisfied and leave only the
  D-6 telemetry acceptance open.
- **WHY EXISTING TEST/VERIFIER MISSED IT:** two reasons, both structural.
  `verify_absence_claims.py` reads `cells[4]` — the evidence cell — and never the
  gap or remediation cell, so no remediation text can be caught by it. And the
  FIR-03 sweep commit (`ef40178`, *"bayat BLOCKED remediation metinleri"*)
  scoped itself to BLOCKED rows; `MP-32-046` is PARTIAL.
- **IN_REPO_RESOLVABLE:** **YES**
- **REMEDIATION DIRECTION:** Rewrite the remediation to cite `incident_runbook.md`
  §6, and extend the absence verifier's scan to the gap and remediation cells so
  the class is caught rather than swept by hand.

### RER-04 — the FIR-02 rule's enumeration is evadable, while its docstring claims completeness

- **SEVERITY:** P3
- **REQUIREMENT IDS:** `MP-11-014`, `MP-23-010`, `MP-26-006`
- **CLAIM FALSIFIED:** `_alert_call_sites()`'s stated contract, *"Every LIVE
  `showEmergencyAlert` invocation"*, mirrored by
  `test/core/services/safety_alert_outcome_test.dart:246`.
- **PRECONDITIONS:** a probe file under `lib/`.
- **REPRODUCTION:** four realistic dropped-result forms were added to a temporary
  `lib/rer_probe_dropped_alert.dart` and `_alert_call_sites()` was run directly.
  It enumerated and flagged the bare call, the bare `await`, and the async-closure
  form. It did **not enumerate at all**:
  ```dart
  final svc = NotificationService.instance;
  await svc.showEmergencyAlert(id: 3, title: 'a', body: 'b');
  ```
  because the anchor regex requires the literal `NotificationService.instance.`
  receiver. The probe was removed.
- **OBSERVED:** 3 of 4 realistic mutations caught; the hoisted-receiver form is
  invisible to both the Python rule and the Dart source-contract test.
- **EXPECTED:** either the enumeration covers receiver forms a refactor would
  produce, or the docstring and the audit rows drop the word "every".
- **WHY EXISTING TEST/VERIFIER MISSED IT:** the consumption analysis is
  statement-level and genuinely good; the weakness is one layer earlier, in the
  *anchor*, which is a substring match on a specific receiver spelling. The
  negative control mutates a known call site, so it exercises the consumption
  logic and never the enumeration.
- **IN_REPO_RESOLVABLE:** **YES** (latent — no such site exists today, so no
  outcome is currently dropped).
- **REMEDIATION DIRECTION:** Anchor on `\.showEmergencyAlert\(` regardless of
  receiver and resolve the receiver separately, or state the enumeration's
  limitation honestly in the docstring and the three audit rows.

### RER-05 — absolute "nothing completed" copy is permitted over a ledger of only-unknown targets

- **SEVERITY:** P3
- **REQUIREMENT IDS:** `MP-01-027`
- **CLAIM FALSIFIED:** `dispatch_outcome.dart:59-62` — `handoffUnconfirmed` is
  *"Neither success nor failure — and never rendered as either"* — and
  `:91-93` — `DispatchReachability.unknown` *"must never be rendered as either
  success or failure"*.
- **PRECONDITIONS:** a ledger with `reachedCount == 0` and `unknownCount > 0`.
- **REPRODUCTION:** real pipeline, call failed, all four bookkeeping targets
  returning `handoffUnconfirmed`; result rendered through
  `EmergencyFailureDialog` with the real `tr-TR` catalogue:
  `reached=0 notReached=2 unknown=4 absoluteShown=true` — the user is shown
  **"Hiçbir işlem tamamlanmadı"** over four targets that may well have succeeded.
- **OBSERVED:** `EmergencyResultPolicy.supportsTotalFailureClaim` tests
  `ledger.reachedCount == 0` only. `unknownCount` is not consulted, so unknowns
  are summarised as failure at the headline while the rows below correctly show
  "belirsiz" — a headline that contradicts its own list.
- **EXPECTED:** the guard should be `reachedCount == 0 && unknownCount == 0`, or
  the two doc comments should be narrowed to per-target rendering.
- **WHY EXISTING TEST/VERIFIER MISSED IT:** it was not missed — it was decided.
  `test/core/services/emergency_result_policy_test.dart:250` asserts
  `claimsNothingCompleted` is `true` for exactly this case, reasoning *"unknown
  is neither reached nor a licence to deny it happened"*. That reasoning is
  defensible for the ledger and wrong for an absolute headline, and it
  contradicts the vocabulary file's own stated rule.
- **IN_REPO_RESOLVABLE:** **YES** (latent — no production code in `lib/` emits
  `handoffUnconfirmed`; every producer path maps to a definite outcome, so this
  cannot reach a user today).
- **REMEDIATION DIRECTION:** Decide which of the two documents is authoritative
  and make the other agree. No user-facing behaviour changes either way at
  present.

---

## 14. Report

```
REVIEWED IMPLEMENTATION REVISION: ef40178 (verified; tree 0aa600f9…)
REVIEWED FINAL HEAD:              c5600ff (docs + regenerated evidence only)
WORKTREE:                         clean (this report is the only addition)

CHECKLIST:    1738
AUDIT:        1738
MISSING:      0
DUPLICATED:   0
UNACCOUNTED:  0

PASS:         799
FAIL:         2
PARTIAL:      69
BLOCKED:      38
N/A:          779
UNVERIFIED:   51

P0 IN-REPO:              0
P1 IN-REPO:              0
IN_REPO_RESOLVABLE:      5   (claimed 0 — RER-01..RER-05; RER-01 alone falsifies it)
RUNTIME_VERIFIABLE_NOW:  0
EXTERNAL_BLOCKER:        109 (recorded 110; MP-41-017 carries an in-repo half)
PRODUCT_DECISION_REQUIRED: 50

VERIFIERS:                    13 (11 Python evidence + 1 Dart + absence claims)
EVIDENCE ARTIFACTS:           12 — all reproduce byte-identically
NEGATIVE CONTROLS ACTUALLY RUN: 13
VALID CONTROLS:               13
INVALID/VACUOUS CONTROLS:     0
STALE PROVENANCE:             0

FIR-01 RECHECK: SURVIVES — 14,640 real-pipeline evaluations, 0 join violations;
                reached=4/notReached=2 reproduces and is NOT absolute.
                Latent gap on unknown-only ledgers (RER-05).
FIR-02 RECHECK: SURVIVES — 5 live sites, 5 consumed. Rule caught 3 of 4
                mutations; hoisted-receiver form evades enumeration (RER-04).
FIR-03 RECHECK: PARTIALLY SURVIVES — the 44 registered claims and the named rows
                are correct; one stale remediation remains (RER-03), and the
                verifier structurally cannot scan gap/remediation cells.
FIR-04 RECHECK: SURVIVES — real tree hashes, dirty-tree refusal proven for both
                Python and Dart, 12/12 artifacts reproduce. Ordering defect in
                the surrounding baseline (RER-02).
FIR-05 RECHECK: SURVIVES — stamps align with ef40178; 1643 tests and the 846/46
                secret-scan surface both re-measured and confirmed.
FIR-06 RECHECK: SURVIVES — 161/1192/114/40 reproduce exactly; 0 classification
                mismatches in 193 citing rows; 0 boilerplate occurrences;
                color.py's 5 open findings honestly carried.
FIR-07 RECHECK: SURVIVES — auth_gate.dart gone; 4 gated construction sites;
                deep links and notification taps park-only, single-consume,
                consumed behind the gates.
FIR-08 RECHECK: SURVIVES — MP-47-011 claims a catastrophe guard, explicitly
                disclaims proportionality; no O(n)/linear language anywhere.

ALL 160 UNRESOLVED ROWS RECLASSIFICATION REVIEW:
  reviewed count:                160
  genuine external count:        109
  genuine product-decision count: 50
  falsely classified count:        1   (MP-41-017)

CURRENT TREE:   clean at c5600ff
ANALYZE:        No issues found! (exit 0)
TESTS:          1643 passed / 0 failed (exit 0, re-run)
SECURITY:       RELEASE_SECRET_SCAN_PASS 846 text / 46 binary / 0 findings
                (clean tree only — fails after a test run, RER-02)
OSV:            findingCount 0, 203 maven + pub queries
COVERAGE:       CRITICAL_COVERAGE_PASS, all 5 critical files >= 90%
ACCESSIBILITY:  covered by the green suite; no TalkBack/device pass performed
RESTORATION:    covered by the green suite (scroll/identity anchors, MP-10-023)
EMERGENCY:      FIR-01 probe + suite green; join invariant holds
NOTIFICATIONS:  5/5 live outcomes consumed; enumeration gap RER-04
DEEP LINKS:     park-only, single-consume, gated; no bypass found
EVIDENCE:       12/12 reproduce; dirty-tree refusal proven
ACCOUNTING:     1738/1738, 0 missing / 0 duplicated / 0 unaccounted
```

---

## FINAL INDEPENDENT RE-REVIEW FAILED — REMEDIATION REQUIRED

The convergence claim `IN_REPO_RESOLVABLE = 0` does not survive. It is
falsified by **RER-01** alone: `MP-41-017` is filed as an external launch
blocker while its own remediation names a repository edit — authoring an
"incoming call during armed countdown" case in
`store/REAL_DEVICE_QA_MATRIX.md` — that has not been made and that needs no
external resource. **RER-02** is a second, independently reproducible
repository defect: the documented baseline command set cannot be executed in
sequence, because running the test suite dirties the tree and the secret scan
then refuses. **RER-03** shows the FIR-03 class is not fully closed and cannot
be caught by the new verifier, which reads only the evidence cell. RER-04 and
RER-05 are latent but legitimate.

This is a narrow failure, and the distinction matters. The heavy remediations
hold under direct attack: the emergency result JOIN survived 14,640
real-pipeline evaluations and every rendered scenario; the accounting
reproduces at 1738/1738 from an independently written parser; all 12 evidence
artifacts regenerate byte-identically and both verifier families genuinely
refuse to emit from a dirty tree; the ENFORCED/CENSUS model is truthful with
zero mismatches across 193 citing rows and zero boilerplate; the security gate
architecture admits no deep-link, notification-tap or restored-route bypass;
and 109 of 110 external blockers plus all 50 product decisions withstand the
challenge. No P0 or P1 in-repo defect exists, and no material false PASS or
false N/A was found.

But this certification permits no rounding. Five in-repo-resolvable defects
remain, two of them demonstrated by reproduction rather than inference, so the
absolute claim is false as written.

This review certifies REPOSITORY CONVERGENCE only. A PASS would not have meant
LAUNCH READY, and the external launch work that remains is not counted against
this verdict.
