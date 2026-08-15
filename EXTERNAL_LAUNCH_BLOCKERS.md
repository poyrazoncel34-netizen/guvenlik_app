# EXTERNAL LAUNCH BLOCKERS

> Requirements that **cannot** be closed from this repository, no matter how much work is
> done here. Each one names the exact external system, the exact procedure, the exact PASS
> criterion, and the evidence that must be captured.

**Two numbers, and they are not the same number.**

| Metric | Value |
|---|---|
| Blocked requirement IDs | **87** |
| External blocker categories | **9** |

A summary that says "9 blockers" and a queue that says "87 requirements" are both true and
must never be written as if one contradicted the other. The categories below carry every
one of the 87 IDs; no ID appears in two categories.

Generated against verified code revision `273864f`. Regenerate the ID lists with
`python3 scripts/generate_resolution_queue.py` and read them out of `RESOLUTION_QUEUE.md`
(`EXTERNAL_BLOCKER` scope).

---

## E1 — Play billing lifecycle (RevenueCat sandbox + Play internal-test account)

- **Requirement IDs (21):** `MP-13-014`, `MP-46-013`, `MP-47-006`, `MP-47-007`,
  `MP-49-009`, `MP-54-001`, `MP-54-002`, `MP-54-003`, `MP-54-004`, `MP-54-005`,
  `MP-54-006`, `MP-54-007`, `MP-54-008`, `MP-54-018`, `MP-54-019`, `MP-54-020`,
  `MP-54-021`, `MP-54-022`, `MP-55-006`, `MP-55-008`, `MP-55-009`, `MP-55-010`,
  `MP-73-010`
- **Severity:** P1 for the `MP-54-*` / `MP-73-010` set, P2 otherwise.
- **Why the repository cannot answer it.** A debug build carries a placeholder RevenueCat
  key, so `ensureInitialized()` returns false and every purchase path ends at the
  fail-closed entitlement message. Price, currency and tax are Play Console
  configuration, not repository state. No purchase, restore, trial, upgrade, downgrade,
  pause or cancel transition has ever been observed against this build — the in-repo tests
  prove the *gating logic*, never the *store transaction*.
- **Required environment.** Google Play Console access for
  `com.poyrazoncel.korubeni` · an internal-test track with the tester account added as a
  licensed tester · a RevenueCat project with a sandbox API key · a device or emulator
  signed into that tester account.
- **Procedure.**
  1. Build with the real key: `flutter build appbundle --flavor play --dart-define=REVENUECAT_ANDROID_API_KEY=<sandbox key>`.
  2. Upload to the internal-test track; add the tester account under **Licensed testers**.
  3. Install from the internal-test link (a sideloaded APK will not transact).
  4. Execute `store/BILLING_RELEASE_CHECKLIST.md` end to end: purchase monthly, purchase
     annual, cancel, restore on a second device, start a trial, let a trial expire,
     upgrade, downgrade, pause, and force a payment failure with a declining test card.
  5. For each transition record the RevenueCat customer-info payload and the on-screen
     result.
- **PASS criterion.** Every transition produces the entitlement state the app renders, in
  both directions, with no state where the UI and `SubscriptionGate` disagree.
- **Evidence to capture.** Dated screenshots per transition + the RevenueCat event log,
  filed under `docs/qa/` and cited per row in `PRODUCTION_AUDIT.md`.
- **Launch impact.** **Blocking.** Shipping an unexercised billing path on a paid safety
  feature risks charging users who then cannot arm SOS.

---

## E2 — Physical Android hardware (Doze, OEM battery managers, real telephony)

- **Requirement IDs (9):** `MP-40-023`, `MP-41-017`, `MP-41-021`, `MP-59-027`,
  `MP-59-030`, `MP-75-007`, `MP-77-001`, `MP-77-013`, `MP-45-005`
- **Severity:** P1 for `MP-41-017`, `MP-41-021`, `MP-59-027`, `MP-59-030`, `MP-77-001`,
  `MP-77-013`; P2 otherwise.
- **Why the repository cannot answer it.** `.claude/rules/common/performance.md` states it
  outright: the Doze race and OEM kill lists cannot be proven off hardware. An emulator
  does not reproduce Xiaomi/Huawei/Samsung battery managers, and it has no radio, so an
  incoming call cannot collide with an armed dispatch.
- **Required environment.** At least one aggressive-OEM phone (Xiaomi MIUI, Huawei EMUI or
  Samsung One UI) plus one AOSP-ish phone (Pixel), both with a live SIM, plus a second
  phone to call from.
- **Procedure.** Execute `store/REAL_DEVICE_QA_MATRIX.md`. Specifically: arm a countdown,
  lock the screen, force Doze with `adb shell dumpsys deviceidle force-idle`, and confirm
  the call still fires; repeat with battery saver on and measure timer drift; place an
  inbound call to the device during an armed countdown and record what Telecom does to the
  outgoing emergency call; measure panic-press-to-dial with a high-speed capture.
- **PASS criterion.** The call is placed in every Doze/battery-saver combination, timer
  drift stays inside the documented budget, and the inbound-call collision has a defined,
  non-silent outcome.
- **Evidence to capture.** `adb` logs, screen recordings and the measured press-to-dial
  numbers, filed in `docs/audit/`.
- **Launch impact.** **Blocking.** This is the product's core promise.

---

## E3 — Google Play policy review (sensitive permissions + `specialUse` FGS)

- **Requirement IDs (2):** `MP-62-020`, `MP-77-023`
- **Severity:** P1.
- **Why the repository cannot answer it.** Compliance with Play policy is a decision Google
  makes. The repository can only prove the declarations are *present and consistent*, which
  it does; it cannot prove they are *accepted*.
- **Required environment.** Play Console with the app in review.
- **Procedure.** Submit the CALL_PHONE and REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
  declarations plus the `specialUse` foreground-service declaration and its required demo
  video; respond to any reviewer follow-up.
- **PASS criterion.** Play accepts all three declarations without a policy warning.
- **Evidence to capture.** The Console decision screens and the submitted demo video URL.
- **Launch impact.** **Blocking.** A rejected declaration removes the ability to dial.

---

## E4 — Account security and key custody (Play Console + GitHub)

- **Requirement IDs (7):** `MP-48-006`, `MP-48-007`, `MP-48-008`, `MP-53-003`,
  `MP-53-006`, `MP-63-006`, `MP-77-009`
- **Severity:** P1 for `MP-53-003`, `MP-63-006`, `MP-77-009`; P2 otherwise.
- **Why the repository cannot answer it.** MFA status, branch-protection settings and Play
  App Signing *enrolment* are account facts. The runbook for all of them is already written
  in `docs/release/dr_and_key_custody.md`; only the console confirmation is missing.
- **Required environment.** Owner access to the Google account that publishes the app and
  to the GitHub repository settings.
- **Procedure.** Confirm hardware-key MFA on both accounts; screenshot the Play Console
  **App integrity → Play App Signing** enrolment state; screenshot GitHub branch protection
  showing required reviews and a protected default branch.
- **PASS criterion.** MFA enforced on both accounts, Play App Signing enrolled, default
  branch protected with required review.
- **Evidence to capture.** Dated screenshots filed in `docs/release/`.
- **Launch impact.** **Blocking for `MP-53-003` / `MP-63-006`.** Losing the publishing
  account is unrecoverable in a way losing the upload key is not.

---

## E5 — Release keystore (full `verify_release.sh` chain)

- **Requirement IDs (0 directly; gates the evidence for the release-governance rows).**
- **Severity:** P1 as a process gate.
- **Why the repository cannot answer it.** `scripts/verify_release.sh` runs
  analyze → test → **signed AAB** → Android lint/unit → 16 KB alignment. The signing step
  needs `korubeni_keystore_release.jks` and its password, which are deliberately not in the
  repository.
- **Required environment.** The release keystore file and password on the build machine.
- **Procedure.** `./scripts/verify_release.sh` with the keystore in place. Never hand-run
  the chain: piped hand-runs mask exit codes, and the script checks each step's real code.
- **PASS criterion.** The script exits 0 and reports 16 KB alignment on every native
  library.
- **Evidence to capture.** Full script output including the alignment table.
- **Launch impact.** **Blocking.** No AAB can be published without it.

---

## E6 — Post-launch operational data (nothing to measure before launch)

- **Requirement IDs (14):** `MP-44-035`, `MP-76-007`, `MP-76-012`, `MP-77-024`,
  `MP-78-001`, `MP-78-002`, `MP-78-003`, `MP-78-005`, `MP-78-010`, `MP-78-020`,
  `MP-78-021`, `MP-78-022`, `MP-50-014`, `MP-50-015`
- **Severity:** P1 for `MP-77-024` (canary), P2 otherwise.
- **Why the repository cannot answer it.** Crash rate, support volume, activation funnel,
  canary health and rollback-in-anger all require a released build with real users. They
  are not verifiable *in principle* before launch, and marking them PASS beforehand would
  be fabrication.
- **Required environment.** A staged rollout on the production track.
- **Procedure.** Release to 1 % → 5 % → 20 % → 50 % → 100 %, holding at each step for the
  window in `docs/release/observability_and_slo.md`, and record the Play Console
  vitals at each step.
- **PASS criterion.** Crash-free rate above the SLO at every rollout step, no spike in
  support volume, canary healthy before each expansion.
- **Evidence to capture.** Play Console vitals per step.
- **Launch impact.** **Not blocking for launch** — these are the launch and post-launch
  gates themselves. `MP-77-024` (canary) blocks *full* rollout, not the first step.

---

## E7 — Real-user usability testing (5 unassisted participants)

- **Requirement IDs (12):** `MP-71-001` … `MP-71-012`
- **Severity:** P2.
- **Why the repository cannot answer it.** The checklist asks for five real users given no
  help. No amount of in-repo work substitutes for that, and no emulator run does either.
- **Required environment.** Five participants matching the ICP, a moderator, consent for
  recording.
- **Procedure.** Unmoderated-task protocol: first-run setup to a working emergency contact,
  then a rehearsal (test mode), with no assistance. Record completion rate, time on task,
  and every point of hesitation.
- **PASS criterion.** At least 4 of 5 complete setup unaided and correctly describe what
  the panic button will do.
- **Evidence to capture.** Session recordings/notes and the completion table.
- **Launch impact.** **Not blocking**, but the highest-value unknown in the product.

---

## E8 — Screen-reader (TalkBack) verification on hardware

- **Requirement IDs (8):** `MP-46-030`, `MP-47-017`, `MP-47-018`, `MP-59-024`,
  `MP-69-010`, `MP-69-011`, `MP-74-006`, `MP-77-005`
- **Severity:** P2.
- **Why the repository cannot answer it.** The in-repo accessibility suite asserts semantic
  labels, roles, target geometry and real localized copy — and it is genuinely good — but
  it cannot prove what TalkBack *announces*, in what order, or whether an announcement is
  interrupted by the countdown's live region.
- **Required environment.** An Android device with TalkBack enabled.
- **Procedure.** Walk consent → onboarding → PIN → home → panic (entitled and locked) →
  countdown → cancel, entirely by screen reader, with the screen curtain on.
- **PASS criterion.** Every control is reachable and correctly announced; the countdown's
  remaining time is announced without flooding; PIN entry is operable.
- **Evidence to capture.** Screen recording with TalkBack audio.
- **Launch impact.** **Not blocking**, but this is a safety product whose users may be in
  the dark or unable to look at the screen.

---

## E9 — Operational tooling that does not exist by design

- **Requirement IDs (14):** `MP-32-044`, `MP-49-004`, `MP-53-012`, `MP-53-014`,
  `MP-67-001`, `MP-67-002`, `MP-67-003`, `MP-67-004`, `MP-75-015`, `MP-77-016`,
  `MP-77-020`, `MP-59-027` *(see E2; listed there)*, `MP-76-007` *(see E6; listed there)*
- **Severity:** P2.
- **Why the repository cannot answer it.** There is no server, no telemetry and no alerting
  pipeline — deliberately (CLAUDE.md rule 1, and no analytics by policy). "Alerting" is a
  human checking Play Console on a cadence. Roll-forward has never been rehearsed because
  Play forbids rolling *back* to a lower `versionCode`, so the only true rollback is a
  roll-forward release.
- **Required environment.** Play Console with an internal-test track.
- **Procedure.** Rehearse a roll-forward on the internal-test track: ship a deliberate
  regression, then ship the fix, and time it.
- **Already written, and NOT part of this blocker (corrected 2026-08-15, FIR-03).** The
  cadence and its owner exist: `docs/release/observability_and_slo.md` names the owner and
  the 24h/72h/7-day check, and `docs/release/incident_runbook.md` §2 names the owner again
  with the daily-for-72-hours vitals cadence and four numeric halt thresholds. The earlier
  text asked for work this repository had already done. `MP-53-012`'s repository half
  (`dr_and_key_custody.md` §3–§5) is likewise complete; only the rehearsal is external.
- **PASS criterion.** A timed roll-forward rehearsal exists.
- **Evidence to capture.** The rehearsal timing record and the signed cadence.
- **Launch impact.** **Not blocking**, but the absence of any automated signal means a
  regression is found by users first. That consequence should be an explicit owner
  acceptance, not an oversight.

---

## What is NOT on this list

Difficulty is not a blocker. Time cost is not a blocker. "No existing test" is not a
blocker. Everything closable in this repository or on the local emulator is in
`RESOLUTION_QUEUE.md` under `IN_REPO_RESOLVABLE` or `RUNTIME_VERIFIABLE_NOW`, and stays
there until it is actually closed.
