# PROGRESS — production-readiness audit continuity file

**Purpose.** Let a fresh session continue this work without relying on conversational memory.
Everything needed is here or in the two documents it points at.

---

## Current phase

**Phase 6 in progress: remediation. Batches 0, 1 (testable subset), 3, 5 and 7 are done.**

Suite state is recorded in the report at the end of this file; do not hand-maintain a count here.
Next unstarted work is **Batch 9 (design tokens)** in [`REMEDIATION_PLAN.md`](REMEDIATION_PLAN.md).

| Phase | State |
|---|---|
| 1. Repository reconnaissance | ✅ Complete |
| 2. Baseline verification | ✅ Complete |
| 3. `PRODUCTION_AUDIT.md` (1,714 requirements) | ✅ Complete |
| 4. `REMEDIATION_PLAN.md` (12 batches) | ✅ Complete |
| 5. `PROGRESS.md` | ✅ Complete (this file) |
| 6. Remediation | 🟡 In progress — see the batch log below |

### Remediation batch log

| Batch | Theme | State | Evidence |
|---|---|---|---|
| 0 | Restore green release gate | ✅ Done | `config/release_change_classification.json` rule added; suite 1025/1025 |
| 1 | Billing — testable subset | 🟡 Partial | `test/screens/paywall_render_test.dart` (6 cases). Live purchase transitions remain **BLOCKED** |
| 2 | Device scenarios | 🟡 Partial | `:app:connectedPlayDebugAndroidTest` green on API 36 emulator (4 pass / 2 skipped). Physical device + incoming-call case remain **BLOCKED** |
| 3 | DR and key custody | ✅ Done | `docs/release/dr_and_key_custody.md` |
| 4 | Accessibility | 🟡 Partial | Harness rebuilt after IR-03: real localization + 2 negative controls + 3 screens. CountdownScreen and contrast still uncovered |
| 5 | Layout defect + regression test | 🟡 Partial | IR-01 fix device-verified; IR-02 test now fails without the fix. Golden-test deliverable dropped (repo forbids goldens) so MP-46-028 stays FAIL |
| 6 | Hostile-input robustness | ✅ Done | `test/core/input_robustness_test.dart` (12 cases), stability-checked over 3 consecutive runs |
| 7 | Observability posture | ✅ Done | `docs/release/observability_and_slo.md` + crash-log version stamping |
| 8 | Operational runbooks | 🟡 Partial | DR/incident content landed in Batch 3; `CHANGELOG.md` still pending |
| 9 | Design tokens | ⬜ Pending | — |
| 10 | Repository hygiene | ✅ Done | `.github/dependabot.yml`; README made canonical for local build; sqflite schema documented; formatting posture recorded as an explicit decision |
| 11 | Adaptive layout (API 37) | ⬜ Scheduled | External platform deadline |

### Defects found and fixed during remediation

1. **Dead database migration hook (latent, would have broken every upgrading user).**
   `LocalDatabaseService._onUpgrade` read `if (oldVersion < 1) { _onCreate(...) }`. sqflite's
   `user_version` starts at 1, so the branch could never execute — the migration system was dead
   code that looked functional. Any column added later would exist only on fresh installs while
   every insert naming it failed for upgrading users: invisible on a wiped emulator, broken for
   every real user. Fixed with additive-only `ALTER TABLE` migrations plus
   `test/core/services/local_database_migration_test.dart` (6 cases, including "migration never
   drops the user safety timeline").
2. **Flaky test on the most safety-critical control (found by running the suite repeatedly).**
   `panic_button_behavior_test.dart` passed in isolation but failed roughly half of full-suite
   runs. Root cause: `PanicButton` measures the hold with a real monotonic `Stopwatch` — which is
   the *correct* production choice, because a wall-clock change must never complete an armed hold —
   while `tester.pump()` advances only the FakeAsync clock. The assertion "released before the 3s
   gate does not arm" therefore depended on how fast the machine executed the test body, not on the
   gate. Under load, >3s of real time elapsed and the press genuinely armed. Fixed with a
   production-inert seam (`PanicButton.holdClockOverride`, never supplied outside tests) plus a
   controllable stopwatch. Verified green on 3 consecutive full-suite runs. A flaky test here is
   worse than no test: it trains people to re-run until green, which is how a real regression in
   the panic gate would have been dismissed.
3. **Save action unreachable behind the keyboard.** Confirmed twice by driving the real app on an
   API 36 emulator: focusing the phone field pushed "Kişiyi kaydet" out of the viewport and out of
   the uiautomator tree. Since that button is the only way to complete onboarding, and onboarding
   is what registers the emergency contact, a user who could not find the scroll gesture ended up
   with no contact — and therefore no panic flow. Fixed with a `FocusNode` +
   `Scrollable.ensureVisible`.

### Audit corrections made during remediation

- `MP-44-015` (log retention) was recorded as PARTIAL claiming no bound existed. A 100-row cap was
  already enforced unconditionally in `crash_log_service.dart`. Corrected to PASS.
- `MP-53-003` was written as if losing the keystore were catastrophic. The release workflow pins
  **both** an upload certificate and a Play app-signing certificate, which is only possible under
  Play App Signing — so upload-key loss is recoverable. Severity rationale corrected.
- `REMEDIATION_PLAN.md` Batch 5 proposed golden tests. `.claude/rules/dart/testing.md` explicitly
  forbids them in this repo. Replaced with direct layout-property assertions.

---

## Audit counts

Every one of the 1,714 checkboxes in `docs/MASTER_PRODUCTION_CHECKLIST.md` has an entry with a stable
ID (`MP-<section>-<item>`). Verified: 1,714 parsed, 1,714 rows emitted, 1,714 unique IDs.

> Counts are regenerated from `PRODUCTION_AUDIT.md` rows; do not hand-edit them here.

| Status | Baseline | After remediation | After independent review |
|---|---|---|---|
| PASS | 561 | 630 | **485** |
| FAIL | 44 | 21 | **21** |
| PARTIAL | 164 | 140 | **140** |
| BLOCKED | 27 | 28 | **28** |
| N/A | 775 | 773 | **773** |
| UNVERIFIED | 143 | 122 | **267** |
| **TOTAL** | **1,714** | **1,714** | **1,714** |

PASS fell by 145 on purpose: IR-06 showed 44% of PASS rows carried section boilerplate instead of
requirement-specific evidence. Every such row was downgraded to UNVERIFIED rather than left as an
unsupported PASS. That is a truer number, not a worse one.

| Severity (non-PASS) | Baseline | After independent review |
|---|---|---|
| P0 | 0 | **2** |
| P1 | 27 | **25** |
| P2 | 288 | **228** |
| P3 | 63 | **201** |

**P0 = 2** (`MP-22-001`, `MP-54-029`). The earlier "no P0, structurally" claim was withdrawn: it
enumerated only server/web hazards. This product's catastrophic event is the panic button failing to
dial, and an entitlement-grace expiry reaches it.

The large N/A share is architectural, not evasive: roughly 45% of this checklist targets server, web
or AI products. Every N/A carries a per-item justification.

---

## Unresolved P0

**None.** No P0 finding exists. This is structural: with no server, no accounts, no telemetry and no
AI, the catastrophic-risk classes this checklist targets (auth bypass, tenant leakage, mass data loss,
prompt injection, financial-ledger corruption) have no surface in this architecture.

---

## Unresolved P1 (27)

Three clusters:

**1. Billing path unverified (20 items)** — `MP-54-001`…`008`, `MP-54-018`…`024`, `MP-54-029`,
`MP-73-010`, `MP-74-007`.
A debug build has no RevenueCat key, so the walkthrough reached only the fail-closed entitlement
message. No purchase, restore, trial or cancel transition has ever been observed against this build.
→ Remediation Batch 1.

**2. Physical-device evidence missing (5 items)** — `MP-41-017` (incoming call during armed countdown),
`MP-41-021` (battery saver drift), `MP-59-027`, `MP-59-030`, plus `MP-62-020`/`MP-59-029` (Play policy
review, externally blocked).
→ Remediation Batch 2.

**3. Account and key custody (2 items)** — `MP-63-006` (MFA on the Play/GitHub accounts),
`MP-53-003` (credential-compromise procedure). Not verifiable from the repository.
→ Remediation Batch 3.

Also P1 but accepted-with-rationale, not defects: `MP-22-001` and `MP-54-029` (offline entitlement
anchor). Documented in `docs/audit/panik-entitlement-agi-bagimliligi-2026-07-31.md`. A
network-dependent panic button is a worse failure than a tampered entitlement — **do not narrow the
offline grace window.**

---

## Next remediation batch

**Batch 9 — design tokens.** Add `lib/core/design_tokens.dart` (spacing, radius, elevation,
duration, easing, icon size, semantic safety-state colours) and migrate `app_theme.dart` plus the
most duplicated call sites. Resolve the light-theme question: `lightTheme` ships but can never
render because `main.dart` pins `ThemeMode.dark`. This batch touches many files — sequence it last
and keep CLAUDE.md rule 4 (do not redesign) in view.

The five root `BUILD_*/DEBUG_*/KEYSETUP` notes were **marked stale in README rather than deleted** —
deleting a user's files was out of scope for an unattended pass. Deleting them is a safe follow-up.

Still open from Batch 4: `Semantics(header: true)` on screen titles, `textContrastGuideline`
(needs a production-representative harness), and review of the `MaterialTapTargetSize.shrinkWrap`
usage at `lib/screens/legal_disclaimer_screen.dart:386`.

Then Batch 10 (hygiene: dependabot, README consolidation, formatting decision) and Batch 9
(design tokens — sequence last, it touches many files).

---

## Commands already run (this session)

| Command | Result |
|---|---|
| `flutter pub get` | OK (110 packages have newer versions available) |
| `flutter analyze --no-fatal-infos` | **No issues found!** (2.9s) |
| `flutter test --no-pub` | baseline **1009 passed / 1 failed**; after remediation **1025 passed / 0 failed** |
| `./gradlew :app:connectedPlayDebugAndroidTest` | **BUILD SUCCESSFUL** on arm64 API 36 emulator — 4 passed, 0 failed, 2 skipped |
| `flutter test --coverage --no-pub` + `dart scripts/verify_critical_coverage.dart` | **CRITICAL_COVERAGE_PASS** — emergency_session_contract 99.18%, emergency_platform_service 95.04%, pin_verification_service 94.87%, contact_service 93.08%, check_in_service 90.70% (min 90%) |
| `scripts/audit_dependencies_osv.sh` (clean worktree) | **OSV_EVIDENCE_PASS** — 197 pub + 203 maven queries, `findingCount: 0`, `status: PASS` |
| `scripts/scan_release_secrets.py --require-clean` (clean worktree) | **RELEASE_SECRET_SCAN_PASS** — 706 text + 46 binary, 0 findings |
| `dart format --output=none --set-exit-if-changed lib/ test/` | 63 of 388 files would change (no CI format gate — deliberate) |
| `flutter build apk --debug --flavor play --target-platform android-arm64` | Built OK |
| Emulator run-through | Full first-run walkthrough, 9 screenshots captured |

**Not run:** `scripts/verify_release.sh` (needs the release keystore), Android instrumentation tests
(need a booted device with the project's gradle task), Play billing sandbox (needs a test account).

### Known baseline failure — not an app defect

`test/release_change_classification_test.dart` fails with
`RELEASE_CHANGE_CLASSIFICATION_FAIL / UNCLASSIFIED_PATH docs/MASTER_PRODUCTION_CHECKLIST.md`.
The gate is working as designed: it refuses to let an unclassified file enter release source. It
predates this session (the checklist arrived untracked). Batch 0 fixes it.

> Note for the next session: running the full suite twice attributed the failure to different files in
> the compact reporter's overwriting output. Use `--reporter expanded` when isolating a failure here.

### How to run the security gates

Both fail closed on a dirty working tree (`candidate source is dirty`). To get a real result without
touching the user's tree, use a detached worktree:

```bash
git worktree add --detach /tmp/clean-wt HEAD && cd /tmp/clean-wt && flutter pub get
```

The `flutter pub get` step is required — without it the OSV script's Gradle invocation fails on the
missing Flutter plugin loader.

### Emulator notes

`Medium_Phone_API_36.1` is **arm64** on Apple Silicon. Build with
`--target-platform android-arm64`; an x86_64 build installs but crashes with
`MissingLibraryException: Could not find 'libflutter.so'`. The emulator `/data` partition filled at
~91% — uninstall old APKs before reinstalling. `adb`/`emulator` are not on PATH; use
`~/Library/Android/sdk/platform-tools` and `~/Library/Android/sdk/emulator`.

---

## Important discovered architecture facts

**What this product is.** `com.poyrazoncel.korubeni` — Android-only, offline-first Flutter personal-safety
app. Turkish-only first runtime. Google Play is the sole distribution channel. minSdk 29, targetSdk 36,
compileSdk 36. Flutter 3.38.9 (pinned in CI and matching local).

**What it does not have** (this drives ~775 N/A verdicts):
no backend/API/server DB · no accounts, login, email or password · no analytics, telemetry or crash SDK ·
no AI/LLM/RAG/agents · no iOS or web target · no file uploads · no push (all notifications local) ·
no admin panel · no multi-tenancy · no UGC.

**Architecture.**
- ~35 focused services in `lib/core/services/`; provider (ChangeNotifier) + get_it. **Not** used: BLoC,
  Riverpod, freezed, GoRouter.
- Typed native Kotlin safety kernel under `android/app/src/main/kotlin/.../emergency/` is the authority
  for dispatch, alarms and session state. `docs/HANDOVER.md` is **ARCHIVED** and describes a removed
  architecture — do not use it as current truth. Current truth: `docs/release/safety_case.md`.
- Storage single sources of truth: emergency contacts → `flutter_secure_storage` key
  `emergency_contacts_v1` (the sqflite `contacts` table is deliberately kept EMPTY); KVKK consent log →
  plain SharedPreferences `kvkk_consent_log_v2` (deliberately off the keystore so consent proof survives
  a keystore reset); legal versions → `lib/constants/legal_texts.dart`.

**Binding product rules — these are decisions, not gaps. Do not "fix" them.**
1. **112 is never dialled by any flow.** Only user-configured 7–15 digit numbers. The "112" strings in
   legal copy say *you* should call 112 — unrelated.
2. **Local PIN only; biometrics strictly forbidden** (duress model — a finger can be forced, a PIN can be
   withheld). Never add `local_auth`, never suggest it.
3. **Emergency path is network-free.** Optional network: OSM tiles, RevenueCat, connectivity checks.
   Claiming "100% offline product" is also forbidden.
4. Panic/countdown and check-in/safe-walk are **deliberately different** (PIN-gated cancel + failover
   across all numbers vs. one-tap cancel + primary contact only). Do not unify them.
5. Backups are deliberately disabled (`allowBackup=false`, all domains excluded) — a cloud copy of a
   victim's contacts is a liability under the duress model.

**Strong areas found (do not disturb).** Release engineering is well above typical: signed-annotated-tag
release gate with main-ancestry verification, build provenance and attestations, deterministic CycloneDX
SBOM (400 components) with per-component licence evidence (named reviewer, date, SPDX, source URL,
SHA-256), OSV audit, secret scanner, MASVS assessment, safety mutation testing, critical-coverage gate at
90%, nightly connected-safety emulator matrix across API 29–36, and a family of policy tests that fail
closed on drift.

**Weak areas found.** No design-token layer · no golden/visual-regression tests · no accessibility
guideline matchers and no TalkBack pass · no telemetry (deliberate, but its consequences are
undocumented) · no SLO/alerting/incident runbook · no physical-device evidence for this build ·
billing path never exercised.

---

## Blockers

| Blocker | Blocks | Nature |
|---|---|---|
| No Play internal-test account / RevenueCat sandbox key | Batch 1 (20 P1 items) | External account access |
| No physical Android device in this environment | Batch 2 (12 items) | Hardware |
| Play Console + GitHub account settings not inspectable from the repo | Batch 3 (`MP-63-006`, `MP-48-006`…`008`) | External org access |
| Play policy review of CALL_PHONE + REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | `MP-59-029`, `MP-62-020` | External decision by Google |
| Android 16 large-screen compat opt-out expires at API 37 | Batch 11 (14 items) | External platform deadline |
| Release keystore not available in this environment | `scripts/verify_release.sh` full chain | Credential |

---

## Next action

1. Apply **Batch 0** (one rule in `config/release_change_classification.json`), then confirm
   `flutter test --no-pub` is 1010/1010 green.
2. Start **Batch 1** — build with a RevenueCat sandbox key, push to the Play internal-test track, and
   execute `store/BILLING_RELEASE_CHECKLIST.md` end to end, recording dated evidence in `docs/qa/`.

Per CLAUDE.md rule 5, write a plan and get approval before changing application code.
