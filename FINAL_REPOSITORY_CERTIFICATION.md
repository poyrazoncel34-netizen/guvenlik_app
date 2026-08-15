# FINAL REPOSITORY CERTIFICATION — KoruBeni

> Independent adversarial certification of the claim **REPOSITORY CONVERGENCE = COMPLETE**.
> This document does not remediate anything and does not modify production code, tests,
> audit rows, verifier code or any earlier report. Every temporary probe used here was
> removed and the tree was re-verified clean after each one.
>
> New findings are numbered `CERT-01`…`CERT-09`. They are additive to, not replacements
> for, the earlier `FIR-*` / `RER-*` / `R2-*` / `IR-*` series.

| Fact | Value |
|---|---|
| Certification date | 2026-08-15 |
| HEAD certified | `fa81404dbbab589076c8fcfc853835a4cc7c8370` |
| Implementation revision independently confirmed | `1950237` |
| Worktree at start and at end | clean (`git status --porcelain` empty) |
| Verdict | **FAILED — remediation required** |

---

## 1. Repository identity — VERIFIED

| Claim | Method | Result |
|---|---|---|
| HEAD = `fa81404` | `git rev-parse HEAD` | **confirmed** |
| Worktree clean | `git status --porcelain` | **confirmed**, empty at start and end |
| Implementation revision = `1950237` | `git diff 1950237..fa81404 -- lib android test scripts assets config` | **confirmed — empty diff** |
| Post-revision commits carry no measured behaviour change | full `git diff --stat 1950237..fa81404` | **confirmed**: 13 files, all `.md` text plus the 12 evidence-artifact provenance stamps (4 lines each, `verifiedCodeRevision` + `treeHash` only) |

The preflight record `docs/qa/incoming-call-preflight-2026-08-15.md` names build revision
`a5d2eaa`, one commit before `1950237`. This was checked rather than accepted:
`git diff a5d2eaa..1950237 -- lib android` is **empty**, so the app surface the preflight
drove is byte-identical to the verified implementation revision. Provenance is sound.

### The `c8c1388` → `068fc01` red-golden question

`c8c1388` changed `test/screens/layout_size_matrix_test.dart` so the text-scale artifact is
VERIFIED by default and regenerated only under `UPDATE_AUDIT_EVIDENCE=1`. At `c8c1388` the
committed `docs/audit/evidence/text_scale.json` still carried the older stamp, so that one
commit is transiently red; `068fc01` regenerates the twelve artifacts.

**No repository policy requires each commit to be independently green.**
Searched: `CLAUDE.md`, `.claude/rules/common/*.md`, `.claude/rules/dart/*.md`,
`.github/workflows/`. `.claude/rules/common/git-workflow.md` states *"One logical change per
commit; tests green at every commit."*

That sentence does exist, so the property is asserted somewhere — but it is a workflow
convention in a rules file, not a gate: CI runs on the branch head, no `rebase --exec`
verification is configured, and no test enforces it. It is recorded here as an observed
deviation from a written convention, not invented as a policy and not counted as a defect,
because the certification scope is the state of the tree at `fa81404`, which is green.

---

## 2. Independent canonical accounting — VERIFIED

Computed with a parser written from the file formats, sharing no code with
`scripts/verify_audit_accounting.py`, and run **before** the repository tooling.

| Property | Independent result | Claim | Verdict |
|---|---|---|---|
| Section headings in the checklist | 80 (unique, `1..80`, no gaps, no duplicates) | 80 | ✅ |
| `- [ ]` checkbox requirements | 1714 | 1714 | ✅ |
| Section-77 launch-matrix rows | 24 | 24 | ✅ |
| **Total checklist requirements** | **1738** | 1738 | ✅ |
| **Audit requirement rows** | **1738** | 1738 | ✅ |
| Pre-ticked checkboxes (must be 0) | 0 | — | ✅ |
| MISSING | 0 | 0 | ✅ |
| DUPLICATED | 0 | 0 | ✅ |
| UNACCOUNTED | 0 | 0 | ✅ |
| Requirement-text parity mismatches | 0 | 0 | ✅ |
| Section-placement mismatches | 0 | 0 | ✅ |
| Rows with ≠ 9 columns | 0 | — | ✅ |
| Rows outside a section body (P0/P1 register) | 29, correctly excluded | — | ✅ |

### Status and severity, recomputed from the rows

| Status | Count | | Severity | Count |
|---|---|---|---|---|
| PASS | 799 | | P0 | **0** |
| FAIL | 2 | | P1 | 29 |
| PARTIAL | 69 | | P2 | 112 |
| BLOCKED | 38 | | P3 | 19 |
| N/A | 779 | | (none) | 1578 |
| UNVERIFIED | 51 | | | |
| **Sum** | **1738** | | **Sum of graded** | **160** |

Every figure matches the audit's own summary, severity and per-section index tables.
Unresolved (non-PASS, non-N/A) = **160**.

### Cross-check of the repository tooling

`python3 scripts/verify_audit_accounting.py` → `AUDIT_ACCOUNTING_PASS checklist=1738
audit=1738 missing=0 duplicated=0 unaccounted=0 sections=80 launchMatrix=24`. Agrees with
the independent parser on every number.

The accounting gate was then mutation-tested on scratch copies (the tree was never
modified):

| Mutation | Rule that fired |
|---|---|
| delete row `MP-30-005` | `MISSING_ROW`, `NON_CONTIGUOUS_NUMBERING`, `SECTION_COUNT_DELTA`, cascading `TEXT_MISMATCH` |
| flip `MP-30-005` PASS → FAIL without touching the tables | `SUMMARY_DRIFT PASS/FAIL`, `SECTION_INDEX_DRIFT`, `UNRESOLVED_WITHOUT_SEVERITY` |
| rewrite `MP-01-003`'s requirement sentence | `TEXT_MISMATCH` |

The accounting gate is non-vacuous.

---

## 3. RER-01 … RER-05 re-attack

### RER-01 — incoming call during an armed countdown — **SURVIVES**

`store/REAL_DEVICE_QA_MATRIX.md` genuinely carries C5, C6 and C7 as an actionable family,
not as placeholders. Each of the required elements was checked and is present: matrix rows
with per-device pass/fail columns, an expanded executable case, five numbered
preconditions (including the third caller phone and DnD-off, both of which void the case if
missed), per-variant steps with explicit timing windows (6–8 s for C5/C6, ≤3 s for C7),
expected UI / countdown / audio-haptic / lifecycle / post-call state, **nine** numbered fail
criteria, and four evidence-capture requirements. The case is written against verified
design facts (deadline-driven countdown, `CountdownScreen` deliberately not a
`WidgetsBindingObserver`, haptic-only audio) and says so.

The emulator preflight limitation is **genuine and honestly recorded**:

- `mCallState` 0 → **1 (RINGING)** → 0 was actually reached, so the instrumentation works
  and the line does not leak between runs.
- Precondition 3 (*countdown genuinely armed*) **FAILED**, measured rather than asserted:
  the device-protected session store `korubeni_emergency_session_v1.xml` does not exist at
  all after driving onboarding to the home screen, because the SOS button is
  entitlement-locked and the panic flow fails closed.
- **Test Mode was not substituted, and the refusal is reasoned.** The record states that
  the Test Mode button exists and would have opened the countdown screen, but that
  `widget.isTestMode` starts the Dart timer *without arming the native session*, so a Test
  Mode screenshot would not satisfy the precondition — and counting it would be exactly the
  fake evidence this audit exists to remove. Verified against
  `lib/screens/countdown_screen.dart`.
- The "what was NOT proven" section is explicit that the scenario itself never ran.

Only irreducible hardware execution (licensed Play test account + physical device + third
phone) remains external.

### RER-02 — sequential reproducibility — **SURVIVES**

The exact sequence was executed with no intervening checkout or reset, twice
(`scripts/verify_repository_convergence.sh`, full mode):

```
clean tree → flutter analyze → flutter test --no-pub → clean tree → secret scan --require-clean → clean tree
```

All links passed. `flutter test --no-pub` run separately by me: **1651 passed / 0 failed**,
worktree clean before and after. `scan_release_secrets.py --require-clean` immediately
afterwards: `RELEASE_SECRET_SCAN_PASS mode=tracked-candidate text=853 binary=46 findings=0`.

**Evidence-update mode probed directly.** I perturbed two measured values in the committed
`docs/audit/evidence/text_scale.json` (`cellsOverflowing 0 → 7`, `cellsMeasured +1`) and ran
the ordinary test:

- exit code **1**
- diagnostic: *"The measured text-scale evidence no longer matches
  docs/audit/evidence/text_scale.json. Drifted keys: cellsMeasured, cellsOverflowing"*, with
  the regeneration command spelled out
- md5 of the artifact **unchanged** before and after the run — the ordinary run wrote
  nothing and did not silently rewrite the golden

The file was restored with `git checkout` and the tree re-verified clean. RER-02's fix is
real, and the diff it produces is useful rather than a blob dump.

### RER-03 — absence / stale-reference verifier — **SURVIVES AS BUILT, BUT ITS COVERAGE IS NARROWER THAN THE CONVERGENCE CLAIM NEEDS**

Coverage confirmed: `verify_absence_claims.py` scans the **evidence**, **gap** and
**remediation** cells (`FIELD_INDEX`), with the broad `ABSENCE_PHRASES` registry rule on
evidence and the narrower `STALE_REPO_REFERENCE` rule on gap/remediation. The registry holds
46 claims (44 evidence, 5 remediation, 1 gap). The negative control fires 3/3.

`MP-32-046` and `MP-32-047` verified specifically: the remediation no longer asks for work —
it cites `docs/release/incident_runbook.md` §6, which I read and which does state that
diagnosis depends on the user exporting their own local log via *Ayarlar → Yasal →
Verilerimi Dışarı Aktar*, and that support's first reply always requests it. The export path
exists in the tree (`lib/screens/settings_legal/legal_settings_screen.dart:136` →
`data_export_screen.dart` → `UserDataExportService.buildExportData`). Both rows are honest.

`MP-41-017` verified specifically: covered under RER-01 above; the repository half is done
and the remaining half is genuinely external.

**However**, an independent scan of all 160 unresolved rows — not trusting the registered
list — found remediations that request work the repository already contains, and the rule
structurally cannot see them. See **CERT-01 … CERT-05**. The gap has two mechanical causes:

1. `WORK_PHRASES` is matched **case-sensitively** (`any(re.search(p, text) …)`, no `re.I`,
   unlike the absence check on the line above it), and contains only
   `Document|Add|Create|Write|Implement|Extend|Author|Publish`. The imperatives the audit
   actually uses in unresolved remediations include `Run` (17), `Confirm` (8), `Verify` (7),
   `Include` (7), `Name` (4), `Rehearse` (4), `Measure` (2), `Ensure`, `Cover`, `Require`,
   `Introduce`, `Adopt` — none of which the rule recognises.
2. The rule only fires when the text **names a repository artefact** (a cited path or a
   `DOC_ALIASES` prose alias). A remediation asking for a *fact or behaviour* that already
   exists — "Name Play Console vitals as the alerting source", "Ensure the paywall links out
   to the Play subscription settings" — names no file and is therefore never examined.

### RER-04 — semantic notification-outcome verifier — **SURVIVES the specified mutation set**

`scripts/verify_alert_outcome_consumption.dart` resolves the invoked **element**, so
receiver spelling is irrelevant. I did not rely on the built-in control; I wrote my own
probe into `lib/` (removed afterwards) and mutated independently:

| # | Form | Result |
|---|---|---|
| 1 | direct dropped call | **flagged** |
| 2 | bare awaited dropped call | **flagged** |
| 3 | hoisted receiver | **flagged** |
| 4 | hoisted receiver + bare call | **flagged** |
| 5 | wrapper that discards result (`SafetyAlertDispatch.postWarning`) | **flagged** (wrapper fixpoint live) |
| 6 | async closure swallowing result | **flagged** |
| 7 | alias/prefixed import (`as ns`), bare **and** hoisted | **flagged** (both) |
| 8 | legitimate consumed forms (assigned-and-returned, pipeline callback, switch on result) | **not flagged** |
| + | cascade `..` | **flagged** |
| + | getter receiver | **flagged** |
| + | try/catch swallow | **flagged** |
| + | dynamic receiver | correctly **reported** as `unresolvedAlertLikeInvocation` |
| + | assigned to a never-read local | not flagged here, but `flutter analyze --no-fatal-infos` **exits 1** on `unused_local_variable` — covered by defence in depth |
| + | static tear-off then invoke | **silently missed** — see **CERT-08** |

**Independent enumeration of the production call graph.** `grep` over `lib/` finds five
direct sites (`emergency_bookkeeping.dart:54`, `check_in_service.dart:512`,
`check_in_service.dart:597`, `safety_alert_dispatch.dart:32`, `safe_walk_screen.dart:238`).
The verifier reports **3 resolved targets / 7 live sites** — the two extra
(`check_in_service.dart:490`, `check_in_service.dart:745`) are calls to the wrapper
`CheckInService._showGraceNotification`, which a grep for the alert method could never find
and which the fixpoint discovered. The claim is not inflated; it is larger than a grep and
correctly so.

I verified the two `handedToCallback` sites individually: both hand the outcome into a
ledger recorder (`BestEffortStep` → dispatch ledger; `DispatchLedgerRecorder.runRecorded`),
so the value is consumed by the pipeline rather than lost. **No live `showEmergencyAlert`
outcome is discarded in the current tree.**

### RER-05 — `EmergencyResultPolicy` — **SURVIVES**

Exercised against the real policy and the **real rendered `tr-TR` payload**
(`assets/translations/tr-TR.json`), not invented copy, via my own probe test (removed
afterwards). The required invariant — absolute *"nothing completed"* copy **iff**
`reachedCount == 0 AND unknownCount == 0` — held in every case:

| Case | reached / unknown / notReached | Headline rendered | Absolute? |
|---|---|---|---|
| definite failure only | 0 / 0 / 2 | "Hiçbir işlem tamamlanmadı" | ✅ true |
| unknown only | 0 / 4 / 0 | "…bazı adımların durumu belirsiz" | false |
| reached only | 2 / 0 / 0 | "…bazı adımlar tamamlandı" | false |
| reached + unknown | 1 / 1 / 0 | "…bazı adımlar tamamlandı" | false |
| reached + failures | 1 / 0 / 1 | "…bazı adımlar tamamlandı" | false |
| unknown + failures | 0 / 1 / 1 | "…bazı adımların durumu belirsiz" | false |
| **historical reached=4 / notReached=2** | 4 / 0 / 2 | "…bazı adımlar tamamlandı" | false |
| navigation failure (`resultScreenUnavailable`) with 4 reached | 4 / 0 / 0 | not the total-failure headline | false |
| navigation failure with unknowns only | 0 / 2 / 0 | unconfirmed headline | false |
| no ledger / empty ledger / only `notAttempted` | 0 / 0 / 0 | "Hiçbir işlem tamamlanmadı" | ✅ true |

Two additional attacks also held: `armRejected` / `dispatchThrew` discard any ledger handed
in (so no ledger is rendered beside absolute copy), and `bodyKeyOverride` **cannot** smuggle
total-failure copy over a ledger that reached targets. No headline contradicted its own
per-target ledger in any case.

**Mutation.** I temporarily restored the old guard
(`ledger == null || ledger.reachedCount == 0`). The repository's own suite went red with
**4 failures**, including the test explicitly named
*"NEGATIVE CONTROL — the old reachedCount-only guard permits the claim this policy now
forbids"* and *"RER-05 policy table: absolute claim iff reached==0 AND unknown==0"*. My
independent probe went red on the same cases. The file was restored with `git checkout` and
re-verified. The regression coverage is genuine, not decorative.

---

## 4. Convergence-guard attack — 16 gates

`./scripts/verify_repository_convergence.sh` returned **0** with **16/16 PASS**, twice, and
returned **1** when an invariant was deliberately broken. Per-gate assessment:

| # | Gate | Invariant proved | Can it false-pass? |
|---|---|---|---|
| 1 | `audit-accounting` | ID/section/text/table parity across 1738 rows | No — mutation-tested three ways, all caught |
| 2 | `audit-accounting-numbers` | the five totals are literally 1738/1738/0/0/0 | No — greps pinned strings, so a "silently consistent 1739" fails |
| 3 | `resolution-queue-classification` | `IN_REPO_RESOLVABLE == 0`, `RUNTIME_VERIFIABLE_NOW == 0`, no P0/P1 in either, queue byte-identical to the generator's output | **Yes — see CERT-01…CERT-06.** `classify()` returns `EXTERNAL_BLOCKER` for *any* BLOCKED row before reading the remediation (26 rows), and its `EXTERNAL_MARKERS`/`PRODUCT_MARKERS` are single substrings such as `hardware`, `console`, `deliberate`, `by design`, `golden` |
| 4 | `…-control` | an injected unblocked P1 moves the count off zero | No — control read and confirmed to inject a genuinely unmarked row |
| 5 | `absence-claims` | 46 registered absence claims, none refuted by the tree | **Partially — see CERT-01…CERT-05.** Coverage is narrower than the claim needs |
| 6 | `…-control` | 3/3 controls fire, incl. a remediation cell | No |
| 7 | `alert-outcome-consumption` | 172 files, 3 targets, 7 sites, 0 dropped | Only via the tear-off form (**CERT-08**) |
| 8 | `…-control` | 6 dropped forms flagged, 2 consumed not | No — I reproduced and extended it |
| 9 | `evidence-provenance` | 12 artifacts, one revision, `dirty:false`, `treeHash == git rev-parse <rev>^{tree}` | **It does not, and does not claim to, check artifact CONTENT — see CERT-09** |
| 10 | `…-control` | 3 stamp mutations rejected, artifact restored byte-identically | No |
| 11 | `worktree-clean:before-tests` | no exemptions, `docs/audit/evidence/` included | No |
| 12 | `flutter-analyze` | real exit code, no pipe | No |
| 13 | `flutter-test` | real exit code, no pipe | No |
| 14 | `worktree-clean:after-tests` | the heart of RER-02 | No — I broke it deliberately and it fired |
| 15 | `secret-scan-after-tests` | runs immediately after tests, no intervening checkout | No |
| 16 | `worktree-clean:after-secret-scan` | end state | No |

**Empty results cannot satisfy the gates:** `verify_evidence_provenance.py` fails on
`NO_ARTIFACTS`; `verify_resolution_classification.py` fails on `NO_ROWS_PARSED`;
`generate_resolution_queue.py` exits 1 on `no requirement rows parsed`;
`verify_audit_accounting.py` fails on `MISSING_FILE`. Preconditions are validated.

**Deliberate-break test (gate 9 vs the whole guard).** I hand-edited a measurement in
`docs/audit/evidence/flows.json` (`popSites 76 → 999`) while leaving the stamp intact:

- `verify_evidence_provenance.py` → **PASS** (it only validates stamps)
- the guard as a whole → **exit 1**, caught by `worktree-clean:before-tests`

So an *uncommitted* tamper is caught, by cleanliness rather than by content. A *committed*
one would not be — CERT-09.

**The structural weakness is gate 3.** A difficult repository task can be hidden as external
work simply by grading the row BLOCKED, or by using a word that appears in
`EXTERNAL_MARKERS`. `verify_resolution_classification.py`'s own docstring is admirably
honest that the BLOCKED shortcut exists and delegates that class to
`verify_absence_claims.py` — but that delegation only works for remediations that name a
file, and CERT-01…CERT-05 are exactly the ones that do not.

---

## 5. All 160 unresolved rows reviewed

Every unresolved row was read individually — gap, remediation, evidence and status — and
independently scoped. The following corrections were found.

### CERT-01 — four rows demand work the repository already contains, and are counted as external

- **Severity:** HIGH (falsifies `IN_REPO_RESOLVABLE = 0`)
- **Requirement IDs:** `MP-67-001`, `MP-67-002`, `MP-67-003`, `MP-67-004` (all P2/PARTIAL)
- **Claim falsified:** *"every remaining unresolved row is blocked on something outside the
  repository, or on an owner decision — and on NOTHING ELSE"*, and `IN_REPO_RESOLVABLE = 0`.
- **Reproduction:**
  ```bash
  grep -n 'MP-67-00[1-4]' PRODUCTION_AUDIT.md
  sed -n '/^## 2\. Yayilimi durdurma esikleri/,/^## 3\./p' docs/release/incident_runbook.md
  grep -n -iE 'owner|cadence|vitals' docs/release/observability_and_slo.md
  ```
- **Observed:** all four rows carry the remediation *"Name Play Console vitals as the
  alerting source and set a checking cadence after each release."* Both deliverables are
  already committed:
  - `docs/release/observability_and_slo.md` — source (`Play Console → Android vitals`,
    lines 41–43), **Owner** (`Repository owner`, line 66), **Cadence** (*"Check at 24h, 72h
    and 7 days after each staged rollout begins, and before each rollout percentage
    increase"*, line 67);
  - `docs/release/incident_runbook.md` §2 — the same source in a threshold table,
    **Sahip: depo sahibi (tek gelistirici)**, and **Kadans:** daily Android-vitals checks for
    the first 72 hours, weekly thereafter.

  The four requirements are the "who" questions (*Kim alarm alıyor? / Kim Incident
  Commander? / Kim teknik müdahaleyi yapıyor? / Kim kullanıcı iletişimini yapıyor?*), which
  §2 answers explicitly, including the reason no rotation is written. Their sibling rows
  `MP-65-005/006/007` and `MP-79-012/013` were regraded **PASS** against these very
  documents during FIR-03; `MP-67-001…004` were left behind, still evidenced only by
  *"DOC: the project is single-maintainer …"* with no citation.
- **Expected:** either PASS citing the runbook and the SLO document, or scope
  `IN_REPO_RESOLVABLE` (rewrite the evidence cell to cite what exists). Not
  `EXTERNAL_BLOCKER` — nothing outside the repository is being waited on.
- **Why the existing guards missed it:** `classify()` matched the substring `play console`
  in the remediation and returned `EXTERNAL_BLOCKER` without reading further.
  `verify_absence_claims.py`'s `STALE_REPO_REFERENCE` needs both a `WORK_PHRASES` imperative
  (case-sensitive `Document|Add|Create|Write|Implement|Extend|Author|Publish`) **and** a
  named repository artefact. *"Name … and set …"* satisfies neither.
- **In-repo resolvable:** **Yes.**
- **Remediation direction:** re-grade the four rows against `incident_runbook.md` §2 and
  `observability_and_slo.md` exactly as FIR-03 did for `MP-65-005/006/007`; then extend
  `WORK_PHRASES` to the imperatives the audit actually uses and match them case-insensitively.

### CERT-02 — `MP-23-012` asks for a link-out that already exists

- **Severity:** MEDIUM
- **Requirement ID:** `MP-23-012` (P2/PARTIAL, *Billing settings*)
- **Claim falsified:** the row's `PRODUCT_DECISION_REQUIRED` scope, and `IN_REPO_RESOLVABLE = 0`.
- **Reproduction:**
  ```bash
  grep -rn 'googlePlaySubscriptionsUrl' lib/
  ```
- **Observed:** the remediation reads *"Ensure the paywall links out to the Play subscription
  settings; verify during the paywall walkthrough proposed in section 13."* The link-out is
  already implemented twice: `lib/screens/subscription/subscription_management_screen.dart:82-90`
  (`_openPlaySubscriptionsFallback` → `launchUrl(AppConstants.googlePlaySubscriptionsUrl,
  LaunchMode.externalApplication)`) and `lib/core/widgets/subscription_deletion_notice.dart:35`.
- **Expected:** the "ensure" clause discharged in the evidence cell; the residue is at most a
  runtime walkthrough, not an owner decision. `PRODUCT_DECISIONS_REQUIRED.md` D-9 frames this
  as *"is this in scope?"*, which does not match what the remediation asks for.
- **Why missed:** `by design` in the gap triggered `PRODUCT_MARKERS`; `Ensure` is not in
  `WORK_PHRASES`, and the remediation names no file.
- **In-repo resolvable:** **Yes.**
- **Remediation direction:** cite the two call sites in the evidence cell and re-scope.

### CERT-03 — `MP-50-014/015/016` ask for documentation the runbook already carries

- **Severity:** MEDIUM (stale remediation; the row's external remainder is genuine)
- **Requirement IDs:** `MP-50-014`, `MP-50-015`, `MP-50-016` (P2/PARTIAL)
- **Claim falsified:** the FIR-03/RER-03 claim that no remediation still requests completed work.
- **Reproduction:** `head -25 docs/release/incident_runbook.md; sed -n '/^## 3\./,/^## 4\./p' docs/release/incident_runbook.md`
- **Observed:** remediation *"Document the Play reality explicitly (halt + roll-forward, not
  rollback) and rehearse a roll-forward once on the internal-test track…"*. The runbook's
  opening states *"Geri alma (rollback) Play'de YOKTUR … Bu belgede 'rollback' her yerde
  ileri sarma demektir"* and §3 gives the five-step halt-and-roll-forward procedure with a
  4-hour target. The first clause is done.
- **Expected:** first clause struck and cited; only the rehearsal remains, which is genuinely
  external.
- **Why missed:** `Document` *is* a `WORK_PHRASES` entry, so the rule reached the second
  test — but *"the Play reality"* is not a cited path and matches no `DOC_ALIASES` pattern
  (`rollout runbook|staged[- ]rollout` does not match `roll-forward`), so
  `referenced_existing_artifact()` returned `None`.
- **In-repo resolvable:** the stale clause, yes. The row's remaining scope stays external.
- **Remediation direction:** rewrite the clause to cite `incident_runbook.md` §3, as
  `MP-32-046/047` were rewritten.

### CERT-04 — `MP-53-006` carries an in-repo documentation deliverable, scoped external

- **Severity:** LOW–MEDIUM
- **Requirement ID:** `MP-53-006` (P2/PARTIAL, *Ransomware/hostile deletion*)
- **Observed:** remediation *"Confirm the GitHub repository has an off-platform mirror **or
  that a local clone is retained**, and note it in the DR section of `docs/release/`."* The
  disjunct is satisfiable inside this environment (the working copy is a retained local
  clone), and *"note it in the DR section"* is pure in-repo documentation.
  `docs/release/dr_and_key_custody.md` §1 currently records only
  `| Source code | git + GitHub | Development stops | Yes, from any clone |`, which does not
  state the retention decision the row asks for.
- **Expected:** `IN_REPO_RESOLVABLE`.
- **Why missed:** `Confirm` / `note` are not `WORK_PHRASES`, and `docs/release/` is a
  directory — `CITED_DOC_PATH` requires a `.md/.json/.sh/.py` suffix.
- **In-repo resolvable:** **Yes.**

### CERT-05 — `MP-50-012` remediation is an in-repo documentation directive

- **Severity:** LOW (stale clause; the D-7 decision behind the row is genuine)
- **Requirement ID:** `MP-50-012` (P2/PARTIAL, *Feature flag*)
- **Observed:** *"Play staged rollout percentage is the available runtime control; treat it
  as the flag mechanism and **document that in the rollout runbook**."* — an in-repo
  deliverable. `incident_runbook.md` §3 step 5 documents staged rollout as a *procedure* but
  never as the substitute flag mechanism the row asks for.
- **Why missed:** `WORK_PHRASES` is matched **case-sensitively**; the cell says lowercase
  `document`, so `\bDocument\b` never matched — even though the same sentence names
  *"the rollout runbook"*, which **is** a live `DOC_ALIASES` entry resolving to an existing
  file. Adding `re.I` alone would have caught this one.
- **In-repo resolvable:** the clause, yes.

### CERT-06 — the section-72 polish family is scoped on a remedy the repo forbids, while an available remedy is recorded as "not performed"

- **Severity:** LOW (P3 rows) — but the certification rule counts P3
- **Requirement IDs:** `MP-72-002`, `MP-72-004`…`MP-72-014`, `MP-72-016` (13 rows,
  P3/UNVERIFIED) and `MP-08-008` (P2/PARTIAL)
- **Claim falsified:** `RUNTIME_VERIFIABLE_NOW = 0`.
- **Observed:** all 13 section-72 rows share one gap — *"Polish is verified by eye on one
  device at one density, on a subset of screens. Several items … require deliberate close
  inspection **that was not performed**."* — and one remediation, *"Add Flutter golden tests
  … then do one deliberate polish pass over the captured goldens."* They are scoped
  `PRODUCT_DECISION_REQUIRED` because `.claude/rules/dart/testing.md` lists golden tests
  under *"NOT used … don't reach for them"*.

  That reasoning holds for the *regression-catching* half only. The recorded reason the rows
  are open is **"was not performed"**, which the certification standard names as an invalid
  reason, and a non-forbidden remedy is available in this environment: a systematic
  screen-by-screen capture pass. The repository already tools for it
  (`scripts/capture_screenshots.sh`), the audit's own RUN evidence comes from an API 36
  emulator, and an emulator run was performed as recently as 2026-08-15
  (`phase3_incoming_call_preflight.sh`). The queue's own vocabulary defines
  `RUNTIME_VERIFIABLE_NOW` as *"Needs the app running; an emulator in this environment
  suffices."*

  Where a genuinely hardware-bound argument applies it was made elsewhere and accepted —
  `MP-69-012/013` are external precisely because a real DPI panel is hardware. No such
  argument is made for section 72.

  `MP-08-008` is the clearest case: *"Button-level loading state not confirmed"*, remediated
  as *"Cover in the proposed golden-test suite."* Confirming that a button shows a loading
  state needs an ordinary widget test, not a golden.
- **Expected:** `RUNTIME_VERIFIABLE_NOW` for the 13 section-72 rows; `IN_REPO_RESOLVABLE`
  for `MP-08-008`.
- **Why missed:** `PRODUCT_MARKERS` contains the bare substring `golden`, so any remediation
  mentioning golden tests is classified as policy-blocked without asking whether a
  non-forbidden remedy exists.
- **In-repo resolvable:** `MP-08-008` yes; the 13 are runtime-verifiable now.
- **Remediation direction:** either execute the capture pass and grade the rows, or record
  the hardware argument explicitly the way `MP-69-012/013` do. Not both silences at once.

### CERT-07 — the Baseline commands table's provenance contradicts the provenance block

- **Severity:** MEDIUM
- **Requirement IDs:** none (document-level; affects every `TEST`/`CMD` citation)
- **Claim falsified:** *"**VERIFIED IMPLEMENTATION REVISION** — the tree every `TEST`/`CMD`/`RUN`
  result in the *Baseline commands* table below was produced against `1950237`"* and
  *"the numbers below come from that run, not from separate invocations."*
- **Reproduction:**
  ```bash
  grep -n 'Result at' PRODUCTION_AUDIT.md
  flutter test --no-pub                     # 1651 passed
  python3 scripts/scan_release_secrets.py --require-clean --output /tmp/s.json
  ```
- **Observed:**
  - the table's column header still reads **`| Command | Result at `ef40178` |`**, directly
    contradicting the provenance block two screens above it;
  - `flutter test --no-pub` is recorded as **1643 passed**; measured at `1950237`/`fa81404`:
    **1651 passed**;
  - the secret scan is recorded as **846 text + 46 binary**; measured now: **853 text + 46
    binary**;
  - several rows in the same table invoke verifiers that did not exist at `ef40178`
    (`verify_repository_convergence.sh`, `verify_evidence_provenance.py`,
    `verify_alert_outcome_consumption.dart` were added in `c5a1564` / `2f941a1` / `a5d2eaa`),
    so one header cannot be true of all rows.
- **Expected:** one header naming `1950237`, with every row re-measured there — which is
  precisely the defect this document's own provenance section says it exists to eliminate
  (*"the stamp below said `273864f` while HEAD was 43 commits and 129 files later"*),
  repeated one layer down again.
- **Why missed:** no gate reads the Baseline commands table. `verify_audit_accounting.py`
  parses the Result summary, severity and section-index tables only.
- **In-repo resolvable:** **Yes.**
- **Remediation direction:** re-measure the table at `1950237`, relabel the column, and add
  a gate that pins the test count and scan counts the way gate 2 pins 1738.

### CERT-08 — the alert verifier's stated blind-spot guarantee is overstated

- **Severity:** LOW (no such call exists in the current tree)
- **Claim falsified:** the verifier's docstring — *"CANNOT: a call reached only through a
  dynamic receiver or a `Function` value whose target the element model cannot resolve. Such
  a call is REPORTED as `unresolvedAlertLikeInvocation` rather than silently skipped, so the
  blind spot is visible instead of assumed empty."*
- **Reproduction:** temporary probe in `lib/` (removed):
  ```dart
  final f = NotificationService.instance.showEmergencyAlert;
  await f(id: 101, title: 'a', body: 'b');     // outcome dropped
  ```
- **Observed:** neither flagged nor reported. The tear-off is a `PropertyAccess` and the call
  is a `FunctionExpressionInvocation`; `_InvocationCollector` only overrides
  `visitMethodInvocation`, and the `unresolved` list is populated only for a
  `MethodInvocation` whose `methodName` is `showEmergencyAlert`. The **dynamic-receiver**
  form in the same probe *was* correctly reported, so the guarantee holds for one of the two
  cases it names, not both.
- **In-repo resolvable:** **Yes.**
- **Remediation direction:** either visit `FunctionExpressionInvocation` / tear-off
  expressions and report them, or narrow the docstring to the dynamic-receiver case it
  actually covers.

### CERT-09 — no gate verifies evidence *content*, only its stamp

- **Severity:** LOW (not currently violated)
- **Claim examined:** evidence integrity / reproducibility.
- **Observed:** `verify_evidence_provenance.py` validates `dirty`, `verifiedCodeRevision`,
  `treeHash` against `git rev-parse <rev>^{tree}`, and single-revision agreement — and
  nothing else. Only `text_scale.json` has a content check, via the golden test in
  `flutter test`. The other **eleven** artifacts, produced by `scripts/audit_evidence/*.py`,
  are never re-derived by any gate. A hand-edited measurement that is **committed** would
  satisfy all 16 gates.
- **Mitigating measurement:** I regenerated all eleven and diffed them against the committed
  files, ignoring only `codeRevision` / `measuredOn`: **zero measurement drift**. The
  committed evidence genuinely reproduces at this tree. The gap is a guard gap, not a data
  defect.
- **In-repo resolvable:** **Yes.**
- **Remediation direction:** add a gate that regenerates the eleven into a temp directory and
  diffs everything except provenance — the same shape the text-scale golden already uses.

### Rows examined and confirmed correctly scoped

All remaining unresolved rows were checked and their scope is genuine:

- **26 BLOCKED rows** auto-classified external were each read: post-launch data that does
  not exist until a rollout (`MP-76-007/012`, `MP-77-024`, `MP-78-001/002/003/005/010/020/021/022`),
  Play Console configuration (`MP-54-001/002/003`), Play internal-test personas
  (`MP-47-006/007`), device/OEM measurement (`MP-41-005/007/017/018/022`), and
  account/infrastructure facts with no in-repo referent (`MP-42-025`, `MP-63-004/005`,
  `MP-64-018/019`). None hides repository work.
- **12 × `MP-71-*`** — unmoderated first-run testing with five real users. Genuinely external.
- **20 × internal-test-track rows** (`MP-54-004…022`, `MP-46-013`, `MP-49-004`, `MP-53-014`,
  `MP-73-010`, `MP-75-015`, `MP-77-020/023`) — need a licensed Play test account and a
  RevenueCat sandbox key.
- **3 × branch protection** (`MP-48-006/007/008`) — GitHub repository settings.
- **`MP-63-006`, `MP-77-009`** — MFA state on the publishing accounts, unknowable from here.
- **`MP-41-004/006/009/010/011`, `MP-46-031`, `MP-69-012/013`, `MP-40-023`, `MP-59-027/030`,
  `MP-74-005/006`, `MP-75-007`, `MP-77-001/005/013`, `MP-41-021`** — the emulator verdict is
  kept and the irreducible remainder is an absolute number on real silicon or a real panel.
  Each names what the emulator could and could not give.
- **`MP-02-016`, `MP-03-013`** — comprehension is a claim about people; the structural
  measurement is retained as the in-repo half.
- **D-3/D-4 form-factor family** (`MP-07-004…015`, `MP-47-013/014`, `MP-59-018/022/023`,
  `MP-74-005`, `MP-80-002`) — a recorded product decision with an API-37 deadline.
- **`MP-04-015`, `MP-06-014`, `MP-32-040`, `MP-46-028`, `MP-22-001`, `MP-54-029`,
  `MP-75-012/013/014`, `MP-77-015`, `MP-27-023`, `MP-75-016`, `MP-65-004`, `MP-16-019`,
  `MP-49-012`, `MP-04-004`** — each names a specific owner decision (rendered-pixel change
  reserved by CLAUDE.md rule 4, a backend forbidden by rule 1, telemetry contradicting the
  published KVKK commitment, the golden-test rule, or a tooling-cost choice), and each maps
  to a registered decision D-1…D-9. `MP-16-019` is explicit that engineering can implement
  it *"as soon as the intended behaviour … is chosen"* — a real blocking question.

**Dead scope overrides (observation, not a defect):** 23 of the 61 `SCOPE_OVERRIDES` entries
name rows that are now PASS (`MP-08-003/004/015`, `MP-09-020`, `MP-12-001…009`, `MP-12-017`,
`MP-12-030`, `MP-27-010/011/012`, `MP-40-022`, `MP-41-001/002/003`, `MP-47-011`). They are
inert, and none names a nonexistent row — but they are the only place in the tree that still
records `IN_REPO_RESOLVABLE` / `RUNTIME_VERIFIABLE_NOW` judgements, so they should be pruned
deliberately rather than left to rot.

---

## 6. Evidence integrity — VERIFIED

| Check | Result |
|---|---|
| Tree hashes | 12/12 verified against `git rev-parse <rev>^{tree}` |
| `verifiedCodeRevision` | all 12 = `19502378e617…`, one shared revision |
| `dirty` | `false` on all 12 |
| **Reproducibility** | all 11 Python artifacts regenerated: **zero measurement drift** (only `codeRevision` / `measuredOn` differ). `text_scale.json` verified by the suite's golden test |
| Hard-coded measurements | none found; every artifact derives its numbers at run time |
| Stale provenance | none — but see **CERT-07** for the Baseline commands table, which is not an artifact |
| ENFORCED vs CENSUS truthfulness | truthful. `propertyClasses` distinguishes `rulesUnderNegativeControl` from census facts, and the audit's CENSUS rows state plainly that *"the verifier's negative control does not and cannot speak to this property"* rather than borrowing its credibility |
| Negative controls | **11/11 `NEGATIVE_CONTROL_PASS`**, re-run individually. Each names the rules that fired, not a total. `color.py` additionally prints `NEGATIVE_CONTROL_BASELINE` (5 pre-existing contrast violations, the ones `MP-06-014` records) *and then* `NEGATIVE_CONTROL_PASS` — I initially misread the first line as a failure and checked; the claim of 11/11 is accurate |
| Tree after all controls | clean |

`run_negative_control` requires each **named rule** to strictly increase, so a mutation that
merely moves a total does not pass. That closes FIR-06 properly.

---

## 7. Current-tree full verification

Executed in order, with real exit codes, no pipes, and **no checkout or reset between steps**.

| Step | Result |
|---|---|
| `git status --porcelain` (before) | **clean** |
| `flutter analyze --no-fatal-infos` | **exit 0** — *No issues found!* (2.3s) |
| `flutter test --no-pub` | **exit 0** — **1651 passed / 0 failed** |
| `git status --porcelain` (after tests) | **clean** |
| `scan_release_secrets.py --require-clean` | **exit 0** — `RELEASE_SECRET_SCAN_PASS` text=853 binary=46 findings=0 |
| `verify_repository_convergence.sh` | **exit 0** — `REPOSITORY_CONVERGENCE_PASS`, 16/16 |
| `git status --porcelain` (final) | **clean** |
| Independent accounting parser | 1738/1738/0/0/0, 80 sections, 0 text/placement mismatches |
| `verify_absence_claims.py` (+ control) | PASS / `NEGATIVE_CONTROL_PASS` 3/3 |
| `verify_alert_outcome_consumption.dart` (+ control) | PASS 172 files, 3 targets, 7 sites, 0 dropped / 6+2 control |
| `verify_evidence_provenance.py` (+ control) | PASS 12 artifacts / 3 stamp mutations rejected |
| 11 × `audit_evidence/<v>.py --negative-control` | **11/11 PASS** |
| Evidence reproducibility | 11/11 regenerate with zero measurement drift |
| `dart scripts/verify_critical_coverage.dart` | **CRITICAL_COVERAGE_PASS** — 99.18 / 95.04 / 94.87 / 90.81 / 93.08, all ≥ 90% |
| `audit_dependencies_osv.sh` | **OSV_EVIDENCE_PASS** — 197 pub + 203 maven queries, `findingCount: 0` |
| `verify_release_change_classification.py` | **PASS**, `classified_paths=0` on a clean tree |
| TODO / FIXME / HACK / XXX / `UnimplementedError` in `lib/` + `android/app/src` | **0 occurrences** |
| Emergency / notification / deep-link / restoration / accessibility regressions | all within the 1651-test suite, green |

Release-gate scripts that require a built AAB (`verify_masvs_assessment.py`,
`verify_gate_evidence.py`, `verify_external_release_gates.py`,
`verify_phase3_emulator_matrix.py`, `verify_sbom_license_policy.dart`) exit on missing
required arguments by design. They are launch-readiness tools, not repository-convergence
gates, and are out of scope here.

---

## 8. Release boundary

The production credential gate was probed directly (temporary test, removed). Every one of
these is **rejected** by `AppEnvironment.isProductionRevenueCatAndroidSdkKey`:

missing/empty · whitespace-only · `goog_PLACEHOLDER_KEY` · `goog_placeholder` ·
`goog_dummy_key` · `NON_RELEASE_SMOKE_REVENUECAT_KEY` ·
`goog_NON_RELEASE_SMOKE_REVENUECAT_KEY` · an `sk_` server key · a `test_` sandbox key ·
a key containing whitespace · a wrong-prefix key.

A well-formed `goog_…` key is accepted, so the gate is not vacuous. **No real secret was
inserted at any point.**

**REPOSITORY CONVERGENCE** (does the repository still contain closable engineering work?)
is a different question from **LAUNCH READINESS** (can this ship?). This certification
answers only the first. Physical-device execution, the Play internal-test track, the
RevenueCat sandbox, real TalkBack testing, MFA/branch-protection confirmation, Play policy
approval, staged rollout and canary all remain outstanding and are correctly recorded in
`EXTERNAL_LAUNCH_BLOCKERS.md`; **none of them caused this verdict.**

---

## 9. Results

### Accounting
`CHECKLIST = 1738` (1714 checkbox + 24 launch-matrix) · `AUDIT = 1738` ·
`MISSING = 0` · `DUPLICATED = 0` · `UNACCOUNTED = 0` · sections `80` ·
text-parity mismatches `0` · placement mismatches `0` — **all independently confirmed.**

### Status counts
PASS 799 · FAIL 2 · PARTIAL 69 · BLOCKED 38 · N/A 779 · UNVERIFIED 51 · **Σ 1738**

### Severity
P0 **0** · P1 29 · P2 112 · P3 19 · **Σ graded 160**

### Scope — claimed vs. independently determined

| Metric | Builder claim | Certified reality |
|---|---|---|
| P0 in-repo | 0 | **0** ✅ |
| P1 in-repo | 0 | **0** ✅ |
| `IN_REPO_RESOLVABLE` | 0 | **≥ 7** ❌ (`MP-67-001`, `MP-67-002`, `MP-67-003`, `MP-67-004`, `MP-23-012`, `MP-53-006`, `MP-08-008`) |
| `RUNTIME_VERIFIABLE_NOW` | 0 | **≥ 13** ❌ (`MP-72-002`, `MP-72-004`…`MP-72-014`, `MP-72-016`) |
| `EXTERNAL_BLOCKER` | 110 | **≤ 105** |
| `PRODUCT_DECISION_REQUIRED` | 50 | **≤ 35** |
| Unresolved total | 160 | **160** ✅ |

Additionally, four rows (`MP-50-012`, `MP-50-014`, `MP-50-015`, `MP-50-016`) retain a genuine
external remainder but carry a stale clause requesting work the repository already contains.

### RER verdicts
| | Verdict |
|---|---|
| RER-01 incoming-call QA case | **SURVIVES** |
| RER-02 sequential reproducibility | **SURVIVES** |
| RER-03 absence / stale-reference | **SURVIVES as built — coverage narrower than the convergence claim requires (CERT-01…CERT-05)** |
| RER-04 notification outcome semantics | **SURVIVES** for mutations 1–8; tear-off blind spot (CERT-08) |
| RER-05 `EmergencyResultPolicy` | **SURVIVES** |

### Convergence-guard verdict
**16/16 gates pass and the guard returns nonzero when an invariant is deliberately broken.**
It is a real gate, not decoration. Two structural weaknesses stand: gate 3 classifies any
BLOCKED row as external before reading its remediation and otherwise decides on single
substrings, and gate 9 validates stamps but never artifact content (CERT-09).

### All unresolved rows reviewed
- Reviewed: **160 / 160**
- Genuine `EXTERNAL_BLOCKER`: **105**
- Genuine `PRODUCT_DECISION_REQUIRED`: **35**
- **False classifications: 20** — 7 in-repo resolvable, 13 runtime-verifiable now
- Additional stale-remediation clauses on otherwise correctly scoped rows: **4**

### Verification summary
FULL TESTS **1651/0 pass** · ANALYZE **clean** · SECRET SCAN AFTER TESTS **pass, no
intervening reset** · OSV **0 findings / 400 queries** · COVERAGE **5/5 ≥ 90%** ·
EVIDENCE **12/12 provenance, 11/11 reproduce, 11/11 negative controls** · SECURITY **no
biometric API, no network in the dispatch path, credential gate fails closed** ·
ACCESSIBILITY / RESTORATION / EMERGENCY / NOTIFICATIONS / DEEP LINKS **green within the
suite** · FINAL WORKTREE **clean**

---

## 10. Verdict

Nine findings are recorded. `CERT-01` alone is decisive: four unresolved rows are counted as
externally blocked while the entirety of what they ask for is already committed in
`docs/release/incident_runbook.md` §2 and `docs/release/observability_and_slo.md` — the same
defect class FIR-03 closed for their sibling rows and missed for these. `CERT-02`, `CERT-04`
and `CERT-06` add three more in-repo rows and thirteen runtime-verifiable ones, and `CERT-07`
falsifies the document's own provenance claim about its Baseline commands table.

None of this is launch work. All of it is closable inside this repository, which is exactly
why it blocks a convergence certification rather than a launch decision. The repository is
close — the accounting is exact, the guard is real, the evidence reproduces, and every one of
RER-01…RER-05 survived a genuine attack — but "close" is not the standard.

`FINAL REPOSITORY CERTIFICATION FAILED — REMEDIATION REQUIRED`
