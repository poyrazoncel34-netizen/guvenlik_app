# FINAL REMEDIATION REGISTER — FIR-01 … FIR-08

> Response to `FINAL_INDEPENDENT_REVIEW.md` (2026-08-15), which returned
> **FINAL INDEPENDENT REVIEW FAILED — REMEDIATION REQUIRED** against HEAD
> `6407901`. That report is immutable and was not edited; this file records what
> was done about it.
>
> Every finding below ends as **RESOLVED** or **NOT REPRODUCED — WITH EVIDENCE**.
> Nothing is deferred.

| Fact | Value |
|---|---|
| Reviewed HEAD | `6407901` (worktree clean, confirmed before any change) |
| **VERIFIED IMPLEMENTATION REVISION** | `98a287d` |
| **FINAL DOCUMENTATION HEAD** | the commit carrying this file; it adds only regenerated evidence artifacts and `.md` text |
| Remediation date | 2026-08-15 |

---

## FIR-01 — A failed call reported "No action completed" while targets reached

- **STATUS:** RESOLVED
- **AFFECTED REQUIREMENTS:** `MP-01-027`
- **ROOT CAUSE.** `countdown_screen.dart` decided the user-facing claim from
  `callResult.isFailed` alone. The bookkeeping targets still ran
  (`shouldRunBestEffort: (result) => result != null`, and a *failed* result is
  non-null), so the ledger recorded four reached targets while the screen showed
  `emergency_total_failure_title` and returned before `EmergencyCallScreen` — the
  only surface that renders the ledger — could be built. Two places computed one
  claim; that is how they came to disagree.
- **INVARIANT.** User-facing emergency outcome copy must agree with the
  `DispatchOutcomeLedger`. An absolute "nothing completed" claim is permitted only
  when no target was reached.
- **IMPLEMENTATION CHANGE.** New `lib/core/services/emergency_result_policy.dart`
  derives the surface and the copy from `EmergencyCallResult` **and** the ledger.
  `EmergencyFailureCopy` has no public constructor, so no caller can pair absolute
  copy with a ledger that contradicts it — including through the `bodyKeyOverride`
  the arm-rejection path needs. New `lib/core/widgets/emergency_failure_dialog.dart`
  is the old dialog, moved unchanged in appearance, now rendering
  `DispatchOutcomeList` beside the copy. All four failure sites in the panic path
  go through the policy.
  **A second instance of the same defect was found and fixed while doing this:**
  the navigation-failure branch also printed the absolute claim, over a ledger in
  which the call had been handed off (`resultScreenUnavailable`).
- **TEST/VERIFIER.** `test/core/services/emergency_result_policy_test.dart`
  (15 cases) builds every ledger by RUNNING the real `EmergencyDispatchPipeline`
  with the real recorder, then asks the real production decision function —
  scenarios A–G including the reviewer's exact `reached 4 / notReached 2` shape.
  `test/screens/emergency_failure_surface_test.dart` (6 cases) pumps the real
  dialog with the real tr-TR catalogue and asserts the absolute sentence is NOT
  rendered when the ledger reached targets, and IS when it did not.
  `test/screens/countdown_emergency_fail_test.dart` (8 cases) guards the wiring:
  the branch must hand the ledger to the decision, and no call site may type the
  absolute key.
- **NEGATIVE CONTROL.** Two mutations, both run:
  1. policy always claims total failure → policy test 6 red, surface test 1 red;
  2. the original defect restored (the branch calls `decide` without the ledger)
     → wiring test 1 red. Restored: 29/29 green.
- **OBJECTIVE EVIDENCE.** `flutter test --no-pub` 1643 passed / 0 failed;
  `countdown_screen.dart` 1228 → 1081 lines (ratchet pin tightened, not raised).
- **FINAL CLASSIFICATION:** RESOLVED.

---

## FIR-02 — Typed notification outcome discarded at 2 of 4 live call sites

- **STATUS:** RESOLVED
- **AFFECTED REQUIREMENTS:** `MP-11-014`, `MP-23-010`, `MP-26-006`
- **ROOT CAUSE.** `showEmergencyAlert` returns a typed outcome; the Check-In grace
  warning awaited it inside `catch (_) { // Notification not critical }` and the
  Safe Walk pre-expiry warning neither awaited it nor marked it `unawaited()`. The
  verifier property vouching for the fix was `"suppressedByUserSetting" in service`
  — a substring test over one file, structurally unable to observe a dropped
  return value.
- **INVARIANT.** No live safety-alert call site may discard its outcome. Suppression
  is either surfaced or explicitly recorded; never silent.
- **IMPLEMENTATION CHANGE.** New `lib/core/services/safety_alert_dispatch.dart`
  posts the alert, classifies failures onto the dispatch vocabulary, records a
  not-reached outcome once under the allowlisted `safetyAlertNotDelivered` code,
  and never throws. Check-In keeps the outcome (`graceAlertOutcome`) at **both**
  grace entry points — the Dart expiry path and the native `handleNativeGraceStarted`
  callback, a **third dropped site the review did not list**, found while fixing
  the other two. `check_in_screen.dart` and `safe_walk_screen.dart` tell the user
  when the warning did not reach them, in the SnackBar idiom both files already use.
  The Safe Walk call is now explicitly `unawaited(...)` over a method that handles
  its own failures. `check_in_service.dart` crossed 800 lines, so the logic was
  EXTRACTED rather than the file being added to the oversize ledger.
- **TEST/VERIFIER.** `test/core/services/safety_alert_outcome_test.dart` (9 cases)
  arms a real session, drives it into the grace window through the production
  entry point, and asserts the recorded outcome differs between notifications-off
  and notifications-on. Plus a census: every `showEmergencyAlert` **and**
  `SafetyAlertDispatch.postWarning` invocation in `lib/` must be consumed.
  `interaction.py` gained `alertOutcomeDiscardedAtCallSite`, which enumerates the
  same call sites; the substring property is kept but is no longer the guard.
- **NEGATIVE CONTROL.** Check-In returned to `_bestEffort` → 4 red; Safe Walk
  outcome dropped → 2 red; `interaction.py --negative-control` trips
  `alertOutcomeDiscardedAtCallSite` by name.
- **OBJECTIVE EVIDENCE.** 5 live call sites, `consumesOutcome: true` on all five,
  in `docs/audit/evidence/interaction.json` →
  `measurements.notificationFeedback.alertCallSites`.
- **FINAL CLASSIFICATION:** RESOLVED.

---

## FIR-03 — FAIL rows asserting the absence of documents the repository contains

- **STATUS:** RESOLVED
- **AFFECTED REQUIREMENTS:** `MP-53-012`, `MP-65-004`, `MP-65-005`, `MP-65-006`,
  `MP-65-007`, `MP-79-012`, `MP-79-013` — **seven, not six.** The review's heading
  says "six FAIL rows" and then lists seven IDs; the canonical audit carried all
  seven as FAIL, so **seven is correct** and the heading is the error.
  Plus `MP-47-017`, `MP-69-010`, `MP-47-018`, `MP-69-011`, found here.
- **ROOT CAUSE.** Hand-written evidence prose outlives the tree it describes, and
  nothing checked it. The accounting gate proves every requirement has a row; it
  never asked whether a row's evidence is still true.
- **RE-VERIFICATION AGAINST THE TREE.**

  | Row | Was | Now | Why |
  |---|---|---|---|
  | `MP-65-005` Ticket ownership | FAIL | **PASS** | `incident_runbook.md` §2 names the owner and says why no rotation is written |
  | `MP-65-006` Severity levels | FAIL | **PASS** | §1 is an S1–S4 ladder; §6 is already cited as PASS by `MP-77-021` |
  | `MP-65-007` Response expectations | FAIL | **PASS** | §1 target first response per severity; §6 three business days per channel |
  | `MP-79-012` / `MP-79-013` | FAIL | **PASS** | §7 item 3 IS the substitution the rows' own remediation asked for |
  | `MP-53-012` Status page | FAIL | **PARTIAL** | `dr_and_key_custody.md` §3–§5 are the three runbooks the remediation asked for; only a status page (deliberately absent — no server) and the rehearsal (external) remain |
  | `MP-65-004` Support ticket | FAIL | **PARTIAL** | channel, owner, severity and response expectation written; no ticket SYSTEM, which is an owner decision |
  | `MP-47-017` / `MP-69-010` Keyboard | UNVERIFIED | **PASS** | the hardware-keyboard pass they said never happened is recorded in `device-verification-2026-08-14-a11y-perf.md`, and `MP-12-004..007` already cite it as PASS |
  | `MP-47-018` / `MP-69-011` Screen reader | UNVERIFIED | UNVERIFIED | status correct, sentence was not: it denied the keyboard pass too |

- **IMPLEMENTATION CHANGE.** Rows re-graded with evidence naming the documents and
  sections. Summary tables regenerated from the rows
  (`regenerate_audit_summaries.py`), queue regenerated
  (`generate_resolution_queue.py`), and the three documents carrying the same stale
  text corrected: `PRODUCT_DECISIONS_REQUIRED.md` **D-5** (Option B was already
  written) and **D-6** (`MP-79-012/013` removed), and
  `EXTERNAL_LAUNCH_BLOCKERS.md` **E9** (asked for a cadence and owner that exist).
- **TEST/VERIFIER.** New `scripts/verify_absence_claims.py` +
  `config/absence_claims.json`: **44** registered absence claims, each naming what
  would refute it. Deliberately registry-driven, not a natural-language parser — a
  parser pretending to judge English would launder the same unchecked claim behind
  a green check. Gated by `test/audit_absence_claims_gate_test.dart`.
- **NEGATIVE CONTROL.** Two: the harness's own control (a claim refuted by a file
  that certainly exists → `REFUTED_ABSENCE_CLAIM`), and the historical one — the
  ORIGINAL `MP-65-006` evidence restored, which the check rejects by name.
- **OBJECTIVE EVIDENCE.** FAIL 9 → 2; the two survivors (`MP-46-028` visual
  regression, `MP-46-030` TalkBack) were re-verified and their claims are TRUE.
- **FINAL CLASSIFICATION:** RESOLVED.

---

## FIR-04 — Evidence artifacts named a stale, dirty revision; one named none

- **STATUS:** RESOLVED
- **AFFECTED REQUIREMENTS:** the 238 rows carrying *"MEASURED, not asserted"*
- **ROOT CAUSE.** `code_revision()` stamped whatever HEAD happened to be, including
  `dirty: true` — which corresponds to no commit, so the artifact could not be
  reconstructed by anyone. `text_scale.json`, written by a Dart test, had no
  provenance at all.
- **INVARIANT.** An artifact names the CLEAN commit whose measured surface produced
  it. A dirty tree is not a revision, so it is not stamped — the verifier refuses
  to emit instead.
- **IMPLEMENTATION CHANGE.** `codeRevision` → `verifiedCodeRevision` + `dirty` +
  `treeHash` + `dirtyPaths`. `emit()` raises `REFUSING_TO_EMIT` on a dirty tree.
  Changes under `docs/audit/evidence/` are exempt, because that is this package's
  own output rather than the surface it measures — otherwise only the first
  verifier of a run could ever emit. `layout_size_matrix_test.dart` gained the same
  block and the same refusal. The self-reference problem is modelled, not wished
  away: **VERIFIED IMPLEMENTATION REVISION** `98a287d` vs **FINAL DOCUMENTATION
  HEAD**, stated in `PRODUCTION_AUDIT.md`.
- **NEGATIVE CONTROL.** Running any verifier on a dirty tree prints
  `REFUSING_TO_EMIT` and writes nothing (observed for all 11 plus the Dart one).
- **OBJECTIVE EVIDENCE.** 12/12 artifacts carry
  `verifiedCodeRevision = 98a287d…`, `dirty: false`, `measuredOn: 2026-08-15`.
- **FINAL CLASSIFICATION:** RESOLVED.

---

## FIR-05 — `PRODUCTION_AUDIT.md`'s provenance stamp and baseline table were stale

- **STATUS:** RESOLVED
- **ROOT CAUSE.** The stamp said `273864f` while HEAD was 43 commits and 129 files
  later — verbatim the R2-08 defect the section above it exists to explain.
- **IMPLEMENTATION CHANGE.** Three facts recorded separately and measured, not
  inherited: verified implementation revision, the evidence artifacts' revision,
  and the final documentation head. Every baseline command re-run at `98a287d` and
  its real result recorded: **1643** tests (was 1139), **846** text files scanned
  (was 733), **154 of 467** files unformatted (was 63 of 388), coverage per file,
  plus two rows the table did not have (absence claims, negative controls).
  Historical entries are labelled HISTORICAL rather than deleted. `MP-33-001`'s
  733-file surface and `EXTERNAL_LAUNCH_BLOCKERS.md`'s `273864f` stamp corrected.
- **OBJECTIVE EVIDENCE.** Every number in the table is reproducible by running the
  command in the same row on `98a287d`.
- **FINAL CLASSIFICATION:** RESOLVED.

---

## FIR-06 — Negative controls were per-verifier, not per-property

- **STATUS:** RESOLVED
- **ROOT CAUSE.** `run_negative_control` compared TOTAL violation counts, so one
  control satisfied it for a whole verifier — while 198 audit rows claimed "the
  negative control shows the verifier can report the opposite" about properties no
  mutation had touched. `layout.py`: 19 cited properties, 1 rule.
- **IMPLEMENTATION CHANGE.** Three parts.
  1. `expect_rules`: every control names the rules it trips and each must strictly
     increase. All 11 verifiers carry theirs.
  2. `propertyClasses` in every artifact, with a stated mechanical criterion:
     ENFORCED when the property's name is read by `measure()`, the function that
     emits violations; CENSUS otherwise. It errs toward CENSUS — under-claiming.
  3. The 198 boilerplate sentences replaced per row: **4 ENFORCED**, **194 CENSUS**.
     No row now claims a control proves a property it does not mutate.
- **NON-ZERO BASELINES, made explicit as the finding required.**
  - `color.py` = 5: **real open findings**, all four contrast measurements already
    recorded against `MP-06-014` (PARTIAL) whose fix is a brand-palette change
    reserved to the owner by CLAUDE.md rule 4. `emit()` now REFUSES to write an
    artifact that has violations but no `baseline_semantics`.
  - `assets.py` = 1: **a harness defect**, not a finding. The control's scratch tree
    never received `pubspec.yaml`, so `uses-material-design` could not be found and
    a phantom `materialIconFontNotDeclared` appeared at baseline. Manifests are now
    copied; the baseline is 0.
- **NEGATIVE CONTROL.** 11/11 `NEGATIVE_CONTROL_PASS`, each printing the rules that
  fired and their per-rule deltas.
- **FINAL CLASSIFICATION:** RESOLVED.

---

## FIR-07 — Dead `AuthGate` constructed an ungated `MainNavigation`

- **STATUS:** RESOLVED
- **AFFECTED REQUIREMENTS:** `MP-26-008`
- **ROOT CAUSE.** `lib/screens/auth_gate.dart` returned `const MainNavigation()`
  unconditionally, with zero consumers. Unreachable, but MP-26-008's security
  argument is that gate ordering is a property of CONSTRUCTION ORDER — which holds
  only while every construction sits behind the gates, and nothing checked that.
- **IMPLEMENTATION CHANGE.** File deleted, and its dangling references with it. The
  same sweep found `flows.py` publishing a FALSE cold-start route
  (`SplashScreen -> AuthGate -> MainNavigation`) and listing `auth_gate.dart` as a
  gate file; both corrected.
- **TEST/VERIFIER.** `flows.py` rules `ungatedTabShellConstruction` (construction in
  an unapproved file) and `tabShellBuiltBeforeItsGate` (construction before its own
  gate decision in an approved one), over comment-stripped sources so the prose
  describing this defect is not read as the defect. Mirrored in
  `test/core/navigation/main_navigation_construction_sites_test.dart` (5 cases),
  which also asserts the census is non-empty.
- **NEGATIVE CONTROL.** A revived gate-less constructor **and** an approved site
  moved in front of its gate: both rules fire by name. The Dart test goes red on
  an unauthorized production construction site.
- **OBJECTIVE EVIDENCE.** 4 construction sites, all `approved: true, gated: true`,
  in `flows.json` → `measurements.entryPoints.tabShellConstructionSites`.
- **FINAL CLASSIFICATION:** RESOLVED.

---

## FIR-08 — The volume growth claim was stronger than its assertion

- **STATUS:** RESOLVED
- **AFFECTED REQUIREMENTS:** `MP-47-011`
- **ROOT CAUSE.** The audit said "growth no worse than proportional"; the assertion
  is `timings[10000] / timings[100] < 1000` for a 100× data increase — up to ~10×
  worse than proportional before going red.
- **IMPLEMENTATION CHANGE.** **Option A**, deliberately: the wording was corrected,
  the threshold was NOT tightened. A tighter wall-clock bound on shared CI would
  flake for reasons unrelated to the query, and complexity cannot be claimed from a
  stopwatch. Both the audit row and the test comment now say exactly what the bound
  proves: a catastrophe guard that catches a quadratic blow-up (ratio ≈ 10 000) and
  would NOT catch n^1.5. Measured ratio ≈ 2.2 (3535 / 2478 / 7755 µs), re-measured
  and recorded.
- **NEGATIVE CONTROL.** None applicable, and none claimed: this is a wording
  correction. The regression protection it describes is unchanged.
- **FINAL CLASSIFICATION:** RESOLVED.

---

## Findings found by this remediation, not by the review

Recorded because they belong to the same defect classes and were fixed here.

| # | Finding | Where |
|---|---|---|
| 1 | The navigation-failure branch also printed the absolute failure claim over a ledger with reached targets | FIR-01 |
| 2 | `handleNativeGraceStarted` was a THIRD site dropping the notification outcome | FIR-02 |
| 3 | `MP-47-017` / `MP-69-010` denied a keyboard pass the repository records and four other rows cite as PASS | FIR-03 |
| 4 | `countdown_screen.dart` had no heading of its own; its only `header: true` lived in the dialog that moved out | FIR-01 |
| 5 | `flows.py` published a false cold-start route naming the dead `AuthGate` | FIR-07 |
| 6 | `assets.py`'s control ran against a scratch tree with no `pubspec.yaml`, producing a phantom baseline violation | FIR-06 |
| 7 | The release-change classifier rejected `FINAL_INDEPENDENT_REVIEW.md` — the rule's own comment says a new reviewer report must never fail the gate by existing | FIR-01 commit |
| 8 | `MP-78-001..003` and `MP-76-007` asked, as remediation, for an owner, a cadence and halt thresholds that `observability_and_slo.md` and `incident_runbook.md` §2 already carry | FIR-03 sweep |
| 9 | `MP-15-013` cited `auth_gate.dart` as evidence for the returning-user path — a file that never took part in that decision and is now deleted | FIR-07 sweep |
