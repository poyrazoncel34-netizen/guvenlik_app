# REMEDIATION PLAN — KoruBeni

Derived from [`PRODUCTION_AUDIT.md`](PRODUCTION_AUDIT.md) (1,714 individually evaluated requirements against
[`docs/MASTER_PRODUCTION_CHECKLIST.md`](docs/MASTER_PRODUCTION_CHECKLIST.md)).
Generated against git HEAD `fe83771`, branch `feat/tutundurma-ucretsiz-prova`.

## How to read this

Batches are ordered by the priority sequence the audit brief requires: P0 security/data integrity →
P1 production blockers → authentication/authorization → data correctness → broken critical journeys →
reliability → testing gaps → accessibility → performance → UX/UI → motion/polish → P2/P3.

**There are two P0 findings** (`MP-22-001`, `MP-54-029`). An earlier revision of this plan claimed P0
was *structurally* absent, reasoning that with no server, accounts, telemetry or AI the catastrophic
surface this checklist targets (auth bypass, tenant leakage, prompt injection, ledger corruption)
cannot exist. That enumeration is correct but incomplete — every hazard on it is a server/web hazard.
For THIS product the catastrophic event is **the panic button failing to dial**, and an independent
reviewer reproduced a path to it: a paying subscriber offline beyond the 7-day entitlement grace
loses SOS entirely. See INDEPENDENT_REVIEW.md IR-04.

| Batch | Theme | Severity | Requirements | Est. size |
|---|---|---|---|---|
| 0 | Restore the green release gate | P2 (blocker) | 3 | XS |
| 1 | Verify the billing path end to end | **P1** | 20 | M |
| 2 | Physical-device safety evidence | **P1** | 12 | M |
| 3 | Account, key custody and disaster recovery | **P1** | 9 | S |
| 4 | Accessibility assertions and a TalkBack pass | P2 | 24 | M |
| 5 | Visual regression baseline + two layout defects | P2 | 8 | M |
| 6 | Hostile-input robustness | P2 | 12 | S |
| 7 | Decide and document the observability posture | P2 | 30 | S |
| 8 | Operational runbooks (incident, rotation, roll-forward) | P2 | 22 | M |
| 9 | Design-token layer | P2 | 16 | L |
| 10 | Repository hygiene | P2/P3 | 8 | S |
| 11 | Adaptive layout for API 37 | P2 (scheduled) | 14 | XL |

---

## Batch 0 — Restore the green release gate

**Problem.** `flutter test` is 1009/1010 green. The single failure is not an app defect: it is
`test/release_change_classification_test.dart` reporting `UNCLASSIFIED_PATH docs/MASTER_PRODUCTION_CHECKLIST.md`.
The gate is working exactly as designed — it refuses to let an unclassified file enter release source.
`PRODUCTION_AUDIT.md`, `REMEDIATION_PLAN.md` and `PROGRESS.md` will trip the same gate for the same reason.

**Requirements affected.** `MP-75-001`, `MP-75-002`, and the release-source classification contract.

**Files.** `config/release_change_classification.json`.

**Change.** Add one rule classifying the checklist and its audit outputs:

```
{
  "pattern": "^(?:docs/MASTER_PRODUCTION_CHECKLIST\\.md$|PRODUCTION_AUDIT\\.md$|REMEDIATION_PLAN\\.md$|PROGRESS\\.md$)",
  "category": "release",
  "commitGroup": "04-ci-evidence-security",
  "reason": "Production-readiness standard and its audit outputs are release-governance source."
}
```

**Completion criteria.** `flutter test --no-pub` is fully green (1010/1010).

**Verification.** `flutter test --no-pub test/release_change_classification_test.dart`, then the full suite.

**Regression risk.** Very low. Adding a classification rule cannot weaken an existing one; the test
itself asserts completeness, so an over-broad pattern would be caught by the neighbouring assertions.
Do **not** widen the pattern to `^docs/` — that would silently classify future unrelated documents.

---

## Batch 1 — Verify the billing path end to end  **[P1, highest priority]**

**Problem.** The payment path is the largest untested surface in the product and it is the one that
takes money. A debug build has no RevenueCat key, so this audit's runtime walkthrough could only reach
the fail-closed entitlement message. No purchase, restore, upgrade, downgrade, cancel, trial-start or
trial-expiry transition has been observed against this build. The paywall screen itself was never
rendered, so the Play-mandated disclosures (price, billing period, auto-renewal, cancellation path)
are unverified on screen.

The architecture is sound — entitlement comes from RevenueCat rather than a local flag, the gate
fails closed (verified), and the app never touches a card number. The gap is evidence, not design.

**Requirements affected.** `MP-54-001` … `MP-54-008`, `MP-54-018` … `MP-54-024`, `MP-54-029`,
`MP-55-003` … `MP-55-011`, `MP-13-012` … `MP-13-014`, `MP-23-012`, `MP-23-015`, `MP-46-013`,
`MP-47-006`, `MP-47-007`, `MP-73-010`, `MP-74-007`, `MP-62-014`, `MP-62-015`.

**Files / components.** `lib/screens/subscription/paywall_screen.dart`,
`lib/core/services/revenue_cat_service.dart`, `lib/core/services/subscription_gate.dart`,
`lib/core/services/subscription_access_state.dart`, `store/BILLING_RELEASE_CHECKLIST.md`,
`store/CLOSED_TEST_TESTER_GUIDE.md`.

**Work.**
1. Build with a RevenueCat sandbox key (`--dart-define=REVENUECAT_ANDROID_API_KEY=goog_…`) and upload
   to the Play **internal-test** track with a licensed test account.
2. Execute `store/BILLING_RELEASE_CHECKLIST.md` in full, capturing a screenshot at each step.
3. Explicitly cover: purchase success, purchase cancel, purchase failure, **restore purchases**
   (the app already points users here on entitlement failure), trial start, trial expiry, cancel, and
   the entitlement state on a second device signed into the same Google account.
4. Verify the rendered paywall shows price, billing period, auto-renewal and the cancellation route —
   these are Play policy requirements, so this doubles as a store-compliance check.
5. Add the missing disclosure that a local data wipe does **not** cancel a Play subscription
   (`MP-23-015`) to the wipe confirmation dialog if it is absent.
6. Record dated evidence in `docs/qa/`.

**Completion criteria.** Every listed requirement moves from UNVERIFIED/BLOCKED to PASS or to a named
defect. `docs/qa/` contains dated billing evidence referencing the exact AAB.

**Verification.** Manual, against the internal-test track — a Play billing sandbox cannot run in CI.

**Regression risks.** If step 5 changes the wipe dialog, re-run `test/legal_*` and
`test/public_release_overclaim_copy_test.dart`; wipe-flow copy is claim-sensitive. Do not "fix"
anything in `subscription_gate.dart` timeouts while testing — the 1800ms/400ms budgets exist because
an unbounded wait in front of a panic button is a delayed emergency call.

---

## Batch 2 — Physical-device safety evidence  **[P1]**

**Problem.** All runtime evidence for this build comes from an emulator. The project's own rules
(`.claude/rules/common/testing.md`, `performance.md`) state that the Doze race and OEM kill lists are
device-only and must never be faked in a unit test. The highest-value missing case is the most
product-specific one: **an incoming phone call during an armed countdown**, on a product whose entire
purpose is placing a call.

**Requirements affected.** `MP-41-001` … `MP-41-011`, `MP-41-017` (phone-call interruption, P1),
`MP-41-018`, `MP-41-021` (battery saver, P1), `MP-41-022`, `MP-59-027` (P1), `MP-59-030` (P1),
`MP-69-012` … `MP-69-017`, `MP-40-022`, `MP-40-023`, `MP-47-025`, `MP-74-005`, `MP-75-007`.

**Files / components.** No source change expected. `store/REAL_DEVICE_QA_MATRIX.md`,
`scripts/phase3_physical_device_preflight.sh`, `docs/audit/`.

**Work.**
1. Execute `store/REAL_DEVICE_QA_MATRIX.md` on at least two physical devices: one recent mainstream
   handset and one aggressive-OEM device (Xiaomi/Huawei/Samsung) known for hostile battery management.
2. Add and run an explicit **"incoming call during armed countdown"** case — currently absent from the
   matrix.
3. Measure cold/warm/resume startup against Android's 2-second feedback threshold.
4. Measure timer drift with battery saver on and battery optimisation not exempted.
5. Capture a DevTools memory profile across an arm → cancel → arm cycle.
6. Record everything dated in `docs/audit/`, per the repository's existing convention.

**Completion criteria.** `docs/audit/` holds a dated physical-device report bound to a specific build,
covering interruption, Doze, battery saver and startup.

**Verification.** Manual on hardware; the nightly API 29–36 emulator matrix continues to cover the
kernel regression surface in CI.

**Regression risks.** None from measurement. If drift is found, resist adding a parallel wake mechanism —
`performance.md` explicitly forbids inventing one alongside `doze_mode_service`, the `specialUse`
foreground service and exact alarms.

---

## Batch 3 — Account, key custody and disaster recovery  **[P1]**

**Problem.** The highest-impact single failure available to this project is not a code defect: it is
loss or compromise of the Google account that owns the Play Console, or of the release keystore
(`korubeni_keystore_release.jks`, recorded as the only keystore with a known password). Neither MFA
status nor Play App Signing enrolment can be verified from the repository.

**Requirements affected.** `MP-63-006` (P1), `MP-53-003` (P1), `MP-53-009`, `MP-53-011` … `MP-53-014`,
`MP-63-004`, `MP-63-005`, `MP-63-022`, `MP-63-023`, `MP-48-006` … `MP-48-008`.

**Files.** New `docs/release/dr_and_key_custody.md`; GitHub and Play Console settings (outside the repo).

**Work.**
1. Confirm MFA — preferably a hardware key — on the Google account owning the Play Console and on the
   GitHub account. Record the date.
2. **Confirm Play App Signing enrolment.** If enrolled, upload-key loss becomes recoverable and the
   catastrophic scenario disappears; if not, enrol. This single item is the highest-value action in
   the batch.
3. Confirm branch protection on `main` requires a passing CI check (`MP-48-006`).
4. Write `docs/release/dr_and_key_custody.md` covering only the three scenarios that are real here:
   lost signing key, compromised Play/GitHub account, bad release already rolled out.
5. Include the credential-rotation procedure (RevenueCat key, GitHub secrets) that sections 32/33/67
   all point at.

**Completion criteria.** The document exists, states Play App Signing status explicitly, and records
dated MFA and branch-protection confirmation.

**Verification.** `DOC` — the document plus dated screenshots in `docs/qa/`.

**Regression risks.** None to the codebase. Changing signing configuration is high-risk and must not
be done casually — enrol in Play App Signing only through the documented Google flow.

---

## Batch 4 — Accessibility assertions and a TalkBack pass

**Problem.** Accessibility is better than typical — there are targeted semantics tests for the panic
button, the countdown live region and timeline deletion, plus honoured reduce-motion and 200% text
scaling. But no TalkBack pass has ever been run, no keyboard traversal has been exercised, and none of
Flutter's built-in guideline matchers are used anywhere in the suite.

**Requirements affected.** `MP-12-001` … `MP-12-009` (keyboard), `MP-12-017`, `MP-12-020`, `MP-12-021`,
`MP-12-023` … `MP-12-025` (contrast), `MP-12-029` … `MP-12-031` (targets), `MP-46-029`, `MP-46-030`,
`MP-47-017`, `MP-47-018`, `MP-59-024`, `MP-69-010`, `MP-69-011`, `MP-74-006`, `MP-06-014`, `MP-80-003`.

**Files.** `test/widgets/*_test.dart`, `test/screens/*_test.dart`, `lib/widgets/loading_overlay.dart`,
`lib/screens/legal_disclaimer_screen.dart:386`, screen title widgets.

**Work.**
1. Add `meetsGuideline(androidTapTargetGuideline)`, `meetsGuideline(textContrastGuideline)` and
   `meetsGuideline(labeledTapTargetGuideline)` to the existing widget tests for the consent gate,
   contact form, panic button and countdown. This closes several audit items at once and is cheap.
2. Review `MaterialTapTargetSize.shrinkWrap` at `legal_disclaimer_screen.dart:386` — it opts one
   control out of the 48dp minimum on a legally significant screen.
3. Add `Semantics(header: true)` to screen titles.
4. Add a semantics label to `loading_overlay.dart` so loading is announced.
5. Announce validation and entitlement errors via a live region or `SemanticsService.announce`
   (the countdown already does this correctly — copy that pattern).
6. Run one TalkBack pass and one hardware-keyboard pass over consent → contact → PIN → home; record in
   `docs/qa/`.

**Completion criteria.** Guideline matchers pass in CI; `docs/qa/` holds a dated TalkBack report.

**Verification.** `flutter test` for the matchers; manual for TalkBack.

**Regression risks.** Contrast assertions may fail on the current palette. If so, fix the palette —
do not weaken the assertion. Adding header semantics changes the TalkBack reading order; verify in the
same pass.

---

## Batch 5 — Visual regression baseline and two layout defects

**Problem.** There is no golden/screenshot test anywhere in the suite, so layout regressions are only
catchable by eye. This audit found two real defects in a single walkthrough, which is a fair estimate
of what a systematic pass would find: helper text under the phone field clips mid-sentence when the
keyboard is open, and the keyboard pushes the save action below the fold on the onboarding contact step.

**Requirements affected.** `MP-46-028`, `MP-07-023`, `MP-72-003`, `MP-72-030`, `MP-08-008`,
`MP-08-023`, `MP-03-006`, `MP-80-001`.

**Files.** `lib/screens/onboarding/onboarding_contact_step.dart`, new `test/goldens/`.

**Work.**
1. Fix the helper-text wrap (raise `maxLines`).
2. Ensure the save action scrolls into view when the phone field gains focus.
3. Add Flutter golden tests for the highest-risk screens: countdown, panic button, consent gate,
   onboarding contact step. Generate baselines and commit them.

**Completion criteria.** Both defects fixed; goldens committed and passing.

**Verification.** `flutter test --update-goldens` once to baseline, then `flutter test`.

**Regression risks.** Goldens are font- and platform-sensitive and can become noisy across Flutter
upgrades. Keep the set small and limited to high-value screens; the repo already pins
`FLUTTER_VERSION: 3.38.9` in CI, which makes goldens viable here.

---

## Batch 6 — Hostile-input robustness

**Problem.** The phone field is well defended (`emergency_number_validator.dart`, 7–15 digits, verified
at runtime). The optional contact **name** field has no comparable constraint and is untested against
hostile input. SQL injection is structurally prevented by parameterised sqflite queries and XSS has no
surface (no DOM, no WebView), so the realistic risk is rendering and overflow, not compromise.

**Requirements affected.** `MP-70-013` … `MP-70-018`, `MP-05-019`, `MP-05-022`, `MP-05-023`,
`MP-14-018`, `MP-47-026`, `MP-47-027`.

**Files.** New `test/core/input_robustness_test.dart`; `lib/screens/contacts_page.dart`,
`lib/screens/onboarding/onboarding_contact_step.dart`.

**Work.** One test pushing through the name field: a 10,000-character string, a 100-character name,
HTML, `<script>`, a SQL-like string, unicode garbage, an emoji flood, and combining characters — then
asserting the app renders and stores without overflow or exception. Add a sane `maxLength` if absent.

**Completion criteria.** Test passes; no layout overflow at any input.

**Verification.** `flutter test`.

**Regression risks.** Adding `maxLength` changes existing stored data behaviour only for new entries;
verify contact-service tests still pass (`contact_service.dart` is a 93.08%-covered critical file).

---

## Batch 7 — Decide and document the observability posture

**Problem.** The product ships no telemetry, deliberately, for KVKK reasons — and that is a defensible,
published commitment. But the consequence is currently undocumented: after launch, the operator has
**no** production signal except Play Console vitals, store reviews and user email. Thirty audit items
across sections 44, 45, 75, 76 and 78 fail or are blocked for this single reason.

This batch adds no telemetry. It converts an implicit absence into an explicit, owned decision.

**Requirements affected.** `MP-44-014`, `MP-44-015`, `MP-44-035`, `MP-45-001` … `MP-45-012`,
`MP-75-012` … `MP-75-014`, `MP-78-004`, `MP-79-012`, `MP-79-013`, `MP-68-014`, plus the section 76
canary gate.

**Files.** New `docs/release/observability_and_slo.md`; `store/PRODUCTION_ROLLOUT_RUNBOOK.md`.

**Work.**
1. State plainly that no telemetry ships and why, and that Play Console vitals are therefore the sole
   operator-facing production signal.
2. Define two objectives that are genuinely observable for this architecture:
   crash-free session rate and ANR rate thresholds (Play publishes both without an SDK), and the
   panic-press-to-dial budget verified per release on hardware rather than continuously.
3. Set explicit **halt thresholds** for staged rollout and name the owner and cadence.
4. Bound the local `crash_logs` table (row cap or age limit) so it cannot grow unbounded (`MP-44-015`).
5. Stamp app version and environment onto every local crash log row so a user-submitted export is
   self-describing (`MP-44-007` … `MP-44-009`).
6. Document that post-incident evidence depends on the user exporting their own local log.

**Completion criteria.** Document exists with named owner, thresholds and cadence; crash-log retention
bound implemented and tested.

**Verification.** `DOC` plus a unit test for the retention bound.

**Regression risks.** Low. Do **not** resolve this batch by adding an analytics SDK — that would
contradict the in-app KVKK text, the Play Data Safety declaration, and
`.claude/rules/common/security.md`.

---

## Batch 8 — Operational runbooks

**Problem.** `docs/veri_ihlali_bildirimi_proseduru.md` covers KVKK breach notification well, and
`store/PRODUCTION_ROLLOUT_RUNBOOK.md` covers rollout. Everything between them is missing: no severity
model, no incident procedure, no credential-rotation procedure, and no rehearsed roll-forward. Critically,
**Play forbids rolling back to a lower versionCode** — the only remedy for a bad release is halt plus
roll-forward, and that has never been rehearsed.

**Requirements affected.** `MP-67-001` … `MP-67-016`, `MP-50-006`, `MP-50-014` … `MP-50-016`,
`MP-50-019`, `MP-50-020`, `MP-53-009`, `MP-75-015`, `MP-75-017`, `MP-75-018`, `MP-79-001` … `MP-79-005`,
`MP-80-016`, `MP-80-017`, `MP-32-045`, `MP-32-048`, `MP-33-005`, `MP-33-006`, `MP-65-004` … `MP-65-007`.

**Files.** New `docs/release/incident_runbook.md`; new `CHANGELOG.md`;
`store/PRODUCTION_ROLLOUT_RUNBOOK.md`.

**Work.**
1. Severity model tied to product reality: **S1** panic/dispatch path broken, **S2** Pro entitlement
   or check-in broken, **S3** cosmetic.
2. Incident procedure: how the problem is noticed (Play vitals, user email), how to halt a staged
   rollout, how to roll forward, how to rotate the RevenueCat key and GitHub secrets, when the breach
   procedure triggers, and how evidence is preserved.
3. **Rehearse a roll-forward once on the internal-test track** so the real timing is known before it
   is needed.
4. Adopt checklist section 79 verbatim as the postmortem template.
5. Add `CHANGELOG.md`, maintained by the release script and reused for Play "what's new".
6. Support process: severity, response expectation, and how to ask a user to export their local log
   (`user_data_export_service.dart` already exists — the missing piece is telling anyone to use it).

**Completion criteria.** Runbook exists; roll-forward rehearsed and timed; `CHANGELOG.md` in place.

**Verification.** `DOC`, plus a dated internal-track rehearsal record.

**Regression risks.** None to the codebase. If the release script is changed to write `CHANGELOG.md`,
re-run `test/release_*` — those tests pin script contents.

---

## Batch 9 — Design-token layer

**Problem.** `lib/core/app_theme.dart` defines colours and component themes well, but there is no token
layer: no named spacing, radius, elevation, z-index, motion-duration, easing, breakpoint, icon-size or
density scale. Widgets consume raw numbers. Nothing is visibly broken today — this is drift risk, and
it is the prerequisite for the adaptive-layout work in Batch 11.

**Requirements affected.** `MP-04-001`, `MP-04-003` … `MP-04-013`, `MP-04-016`, `MP-04-017`,
`MP-03-009`, `MP-03-010`, `MP-09-016`, `MP-09-017`.

**Files.** New `lib/core/design_tokens.dart`; `lib/core/app_theme.dart`; high-traffic widgets.

**Work.** Create the token module (spacing, radius, elevation, duration, easing, icon size, plus
semantic safety-state colours for armed/safe/degraded). Migrate `app_theme.dart` first, then the most
duplicated call sites. Resolve the light-theme question: either wire a theme setting or delete
`lightTheme`, which currently ships but can never render because `main.dart` pins `ThemeMode.dark`.

**Completion criteria.** Token file is the single source; `app_theme.dart` references it; no new
literals introduced in touched files.

**Verification.** `flutter analyze` + `flutter test`; goldens from Batch 5 prove no visual change.

**Regression risks.** Moderate — this touches many files. **Sequence it after Batch 5** so the goldens
can prove the migration is visually inert. Respect CLAUDE.md rule 4 (do not redesign) and the file-size
ratchet: extract into `lib/core/`, do not grow the known oversize screens.

---

## Batch 10 — Repository hygiene

**Problem.** Small items with real friction cost. Five root-level build documents
(`BUILD_NOW.md`, `BUILD_FIX.md`, `BUILD_FINAL.md`, `DEBUG_BUILD.md`, `KEYSETUP.md`) date from
February 2026 and read as scratch notes; this audit had to derive the correct build invocation by
inspection. Dependencies are updated manually (110 packages have newer versions). The formatting
situation is deliberate but undocumented as a decision.

**Requirements affected.** `MP-68-002`, `MP-68-006`, `MP-68-007`, `MP-27-003`, `MP-48-009`,
`MP-63-024`, `MP-63-025`, `MP-04-027`.

**Files.** `README.md`, the five root build docs, new `.github/dependabot.yml`,
`.claude/rules/common/coding-style.md`.

**Work.**
1. Consolidate the five build documents into one current setup section in `README.md`; delete the rest.
2. Document the local sqflite schema and the **additive-only** migration rule (`ALTER TABLE ADD COLUMN`, never drop-and-recreate). An earlier draft of this step said "recreate-on-upgrade", which is the opposite of what is implemented and would have documented a data-loss design the code correctly does not have (INDEPENDENT_REVIEW.md IR-07).
3. Add `.github/dependabot.yml` for pub and Gradle. The OSV gate already blocks known-vulnerable
   versions, so this is currency hygiene, not a security hole.
4. **Decide the formatting question explicitly.** Either record "this repo is not uniformly formatted
   and that is policy" in `coding-style.md`, or format once in an isolated commit and add a CI gate
   from that point forward. Do not half-fix it — the current state is the worst of both.

**Completion criteria.** One setup path in `README.md`; dependabot active; formatting decision recorded.

**Verification.** `CMD`/`DOC`.

**Regression risks.** Deleting build docs is irreversible in working memory — confirm nothing in them
is unique before removal. If the format-once path is chosen, it must be a standalone commit touching
nothing else.

---

## Batch 11 — Adaptive layout for API 37  **[scheduled, externally dated]**

**Problem.** `AndroidManifest.xml` sets `PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY=true` — Google's
documented temporary opt-out from Android 16 large-screen resizability, which expires when the app
targets API 37. Tablet, foldable, landscape and split-screen layouts are consequently unsupported. The
manifest comment already records this as planned work; the deadline is Google's, not the project's.

**Requirements affected.** `MP-07-004` … `MP-07-008`, `MP-07-011`, `MP-07-014`, `MP-07-015`,
`MP-47-013`, `MP-47-014`, `MP-59-018`, `MP-59-022`, `MP-59-023`, `MP-80-002`.

**Files.** `android/app/src/main/AndroidManifest.xml`, `lib/main.dart` (orientation lock),
all screen layouts.

**Work.** Define breakpoints (ideally on the Batch 9 token layer), build adaptive layouts for the four
highest-traffic screens, verify on tablet and foldable emulators, remove the compat property, then bump
`targetSdk`.

**Completion criteria.** Compat opt-out removed; large-screen evidence recorded in `docs/qa/`.

**Verification.** Emulator matrix plus the physical-device pass.

**Regression risks.** Highest of any batch — it touches every screen and removes the portrait lock that
the panic-button UX currently assumes. Do it after Batch 5 (goldens) and Batch 9 (tokens), never
before. Start it well ahead of the API 37 deadline; this is the project's largest scheduled debt.

---

## Sequencing

```
Batch 0  (XS, unblocks CI)
  ├─► Batch 1  ── P1, do first: it is the money path and it is untested
  ├─► Batch 2  ── P1, needs hardware; can run in parallel with Batch 1
  └─► Batch 3  ── P1, mostly account settings; can run in parallel
        │
        ├─► Batch 7, 8, 10   (documentation/decisions — no code risk, parallelisable)
        ├─► Batch 4, 6       (tests — independent)
        └─► Batch 5 (goldens) ──► Batch 9 (tokens) ──► Batch 11 (adaptive layout)
```

Batches 1–3 are the release-blocking set. Batches 4–8 and 10 are safe to run concurrently by anyone.
Batches 5 → 9 → 11 are strictly ordered: goldens make the token migration provably inert, and tokens
make adaptive layout tractable.
