# Evidence-based remediation — F01–F17

Source of truth: `/Users/poyrazoncel/Projects/guvenlik_app`, branch
`codex/evidence-remediation-20260911`, baseline commit
`5f9f0576f408ae7724c7a27e06f3f62ada7ebd01`. The original review report is NOT
modified; this file is the separate remediation record it asked for.

Environment: Flutter 3.38.9 / Dart 3.10.8, macOS arm64 (Darwin 25.6.0), JDK 17,
Gradle 8.14. No dependency version was added, removed or upgraded; `pubspec.yaml`
and `pubspec.lock` are untouched and `flutter pub get --enforce-lockfile`
resolves.

## Honest status vocabulary

Implementation status and verification status are tracked SEPARATELY. "Local
tests pass" is never written as release approval, and no PASS is recorded for
anything requiring a physical device, the Play Console, a licensed billing
account, a hosted CI run, or a human legal review. Those stay OPEN in F13.

Two corrections to the record this file replaces, which described work as
pending that had in fact landed, and claimed one action that cannot be shown:

- F01/F02/F07 were listed "In progress / Pending". Their implementation is
  present and is described below with the code that carries it.
- The F14 note claimed a question "was sent to the user". That is not
  verifiable from this repository, so the wording now states only that the
  decision is open and belongs to the owner.

## Closure table

| ID | Root cause (verified against current source) | Fix | Meaningful verification | Remaining external dependency |
|---|---|---|---|---|
| F01 | `_restoreFromStorage` treated a timed-out/corrupt read and a missing Dart blob as ABSENCE, cleared the token and deleted the projection, so an alarm Android had already accepted became uncancellable | Native slot is the authority: app-private `discoverEmergencySession(kind)` finds the session without a Dart token; uncertainty keeps token/projection and raises `nativeScheduleDegraded`; `ArmUnknown.uncertainToken` is retained | `emergency_snapshot_parser_test`, `check_in_typed_session_test`, `check_in_service_behavior_matrix_test`, `native_emergency_history_test`; parser at 100% line coverage | Physical lifecycle acceptance (F13) |
| F02 | Grace warning and Safe-Walk pre-warning existed only in Dart (`Timer`, screen listener), so leaving the screen or losing the process removed the user's last cue while the native alarm kept running | Native `ACTION_GRACE` / `ACTION_PRE_WARNING` alarms scheduled in `AndroidEmergencySessionRuntime`, handled by `CheckInAlarmReceiver`, dispatched through `coordinator.warn()` with token+generation and idempotency checks; both cancelled on cancel/revision | `EmergencySessionCoordinatorTest`, `NativeNotificationTextTest` (Kotlin, 92 tests, 0 failures) | Device matrix: Doze, OEM restrictions, notifications-denied, force-stop vs normal kill (F13). Force-stop/reboot/OEM are NOT claimed equivalent |
| F03 | Any prefs/DB/files failure still fell through to an unconditional `clearSecureStorage()`, deleting the PIN while the data it protected survived | `if (!allDeleted) return WipeResult.unknown;` placed BEFORE the credential boundary; native-unknown returns before any Dart store is touched | `app_reset_native_prefs_test`, `app_reset_helper_pin_contract_test`, `startup_pin_boundary_test` — fault-injected prefs=false, DB throw, files=false, native unknown, then restart | Device storage-fault confirmation (F13) |
| F04 | The sensitive gate reused the armed-cancel modal, which WROTE the shared counter but never READ `isLocked`, so attempt 6+ verified immediately; a second surface in `app_reset_helper` called the verifier directly | `enforceLockout` reads lockout and reserves the attempt durably BEFORE comparing; counter read/write/delete faults deny; `app_reset_helper` now routes through the shared gate (~90 duplicated lines removed). Armed cancel keeps the deliberate unthrottled policy | `sensitive_action_pin_gate_test` — real widgets/gate/verifier/lockout, memory storage; proves the verifier is NOT reached (`pinReads` unchanged) under lockout and across a reopened modal, and that armed cancel still succeeds | — |
| F05 | Splash computed PIN presence but the re-consent branch never used it; consent pushed onboarding with no callback, and `MainNavigation` only checked that a PIN existed | `_continueStartup()` re-reads durable state after consent and puts PIN verification before unfinished onboarding and before main content; consent returns through `AppRoot`, preserving the state-restoration boundary | `startup_pin_boundary_test` — stored synthetic PIN/contact + stale legal version; no saved contact or MainNavigation before PIN; correct PIN proceeds; fresh-install and incomplete-onboarding paths unregressed | TalkBack / physical a11y (F13) |
| F06 | `RevenueCatService` returned null for any future anchor, so the persisted evidence never reached the state rule that grants emergency continuity to a previously verified Pro | Parseable anchors load; the safety-vs-commercial decision stays in `SubscriptionAccessState` | `subscription_provider_access_test`, `revenue_cat_evidence_persistence_test` — normal/future anchor cold start offline, absent/corrupt/single-key, confirmed-free | Sandbox offline/clock matrix (F13) |
| F07 | Native terminal outcomes only cleared counters; restore deleted the terminal snapshot without moving the result into history, so a native dispatch could reappear as "no session" | `EmergencyTerminalJournal` persists redacted terminal envelopes atomically with the envelope; `NativeEmergencyHistory` records them with an idempotent `eventId` (protocol:kind:randomId:generation) and acknowledges | `native_emergency_history_test`, `safety_alert_outcome_test`, `DeviceProtectedEmergencySessionStoreTest` — warm and cold consumption, no duplicate on second launch | Physical background dispatch (F13) |
| F08 | `LocationResult` carried no measurement time; a timed-out request returned the cached point as `success`, and MapPage cleared its staleness warning | Result carries measurement timestamp, source and staleness; MapPage states age truthfully; no synthetic measurement is produced | `location_service_test`, `map_freshness_widget_test` — stale+timeout, no measurement, permission denial, fresh fix; 360x640 at 1.0/1.3/2.0 text scale | Physical GPS/a11y (F13) |
| F09 | `process_artifact_contract_test` required the git-ignored `.claude/rules/common/development-workflow.md`, so a clean checkout failed | Canonical standard moved to tracked `docs/release/development_standard.md`; the test binds there. No skip, no weakened assertion, no personal `.claude` directory committed | Verified in a tracked-files-only clean checkout (see Verification runs) | — |
| F10 | Legacy Fastlane lanes built a local AAB and called upload/promotion with none of the release evidence gates | Both lanes fail closed with an explanatory error under the repo's CI-only policy; no rebuild of an accepted candidate | `scripts/test_fastlane_release_boundary.rb` — executes the ACTUAL Fastfile with a fake uploader across 5 candidate shapes: 55 assertions, upload never called | Hosted/Play acceptance (F13) |
| F11 | `build-mode: none` does not extract Kotlin (GitHub documents this), so the workflow's claimed native coverage was effectively zero | `java-kotlin` uses `build-mode: manual` with a traced `:app:assemblePlayDebug` after `flutter pub get --enforce-lockfile`; `actions` stays source-based. The workflow's coverage-honesty note is restored, including that YAML text is not evidence | Both prerequisites executed locally: `--enforce-lockfile` exit 0, `:app:assemblePlayDebug` BUILD SUCCESSFUL | **Hosted CodeQL database/extraction log is OPEN.** No native analysis coverage is claimed |
| F12 | The Console paste pack put history/rehearsal under Pro (the matrix makes them free), claimed all data stays on device, and requested a removed FGS declaration | Canonical pack rebuilt from the real feature tier table, actual permission/FGS surface and OSM/RevenueCat data flow; legacy docs redirect | `store_release_docs_test` — parity against runtime `FeatureAccessMatrix` | Human legal review and Console preview (F13) |
| F13 | Not a code bug: no candidate-bound physical/billing/Console evidence exists; `release-evidence/` holds templates | Full scenario and evidence inventory prepared in `docs/release/external_acceptance_20260911.md`, with required fields per record | Inventory reviewed against the actual template files | **OPEN / NO-GO.** Nothing marked PASS |
| F14 | Three conflicting threshold/cadence sources; first-line support asked for a full user-data JSON export | One canonical procedure with redirects; first diagnosis takes version/device/time/steps and an allowlisted error code only; user export stays a separate voluntary feature | `support_diagnostics_privacy_test` — synthetic contacts/phone/email/PIN/coordinates fed in; only allowlisted codes survive | Threshold decision **RESOLVED 2026-09-12 by the owner** (rollout-runbook values; `operations_threshold_decision.md`). Still open: named staffed owner/backup, an actual two-operator rehearsal, measured recovery time |
| F15 | A trusted-but-stale cached `CustomerInfo` was stamped with `DateTime.now()`, advancing "last verified" on every cache read | The anchor comes from the SDK's `CustomerInfo.requestDate`; a malformed date cannot create evidence | `subscription_provider_access_test` — repeated cache read does not advance the anchor; SDK 10.4.2 source and current caching docs reviewed | Real sandbox cancel/refund/offline cycle OPEN. **No claim that an "unlimited free Pro" hole was closed** |
| F16 | Consent writes were unchecked and an exception closed the loader and rethrew, leaving no on-screen reason or retry | Every persisted write must commit; the completion marker is written last; a localized retry message preserves selections and discards the optimistic prefs cache | `unified_consent_retry_test` — failure injected at each write boundary; error visible, no navigation, choices kept, retry yields one coherent consent set | — |
| F17 | Onboarding claimed the phone "cannot be forced open" and that Test Mode shows the number "works" | Copy limited to actual behaviour: local PIN, no biometric unlock, and Test Mode as a rehearsal that does NOT verify reachability. Informational pages made scrollable | `onboarding_safety_copy_render_test` — real screens at 320x640, text scale 1.0/1.3/2.0: 3 overflows before, 6/6 pass after; TR/EN parity enforced | **User comprehension NOT measured.** No claim about understanding or abandonment |
| H01 | `Future.wait` on best-effort startup work was awaited before the first `runApp`, so one never-completing plugin future could hold the app | Critical bootstrap takes ordered preliminary steps; optional work is bounded per operation and late failures are consumed. `ErrorWidget.builder` is installed before localization and falls back to literal copy | `best_effort_startup_test`, `app_bootstrap_service_test`, `main_startup_init_order_test` (contract deliberately updated) — never-completing and sync/async faults | No startup-time measurement is claimed |
| H02 | `release.yml` ran `git verify-tag` on a clean runner with no trusted signer configured | `scripts/verify_release_tag.sh` verifies against operator-configured public trust in a disposable keyring/allowed-signers file; empty trust fails closed; private keys rejected | `scripts/test_release_tag_trust.py` — synthetic disposable SSH tag: approved trust, wrong signer, absent trust, unsigned all behave correctly | Real trusted signer identity and hosted run OPEN. No signer identity invented |

## Findings this remediation itself introduced and fixed

| ID | Issue | Resolution |
|---|---|---|
| R-01 | The in-flight remediation left three analyzer **warnings** in new test files, which fails CI (`flutter analyze --no-fatal-infos` exited 1) | Warnings and all remaining infos removed; analyze reports "No issues found" |
| R-02 | Safety rationale in `check_in_service.dart` (SPEC §0/§3.1 references, the FIR-02 and MP-01-027 notes, restore-path invariants) had been deleted, partly to stay under the 800-line ratchet | Rationale restored and the file brought to 799 lines by EXTRACTING `CheckInProjectionStore`, the CLAUDE.md-prescribed fix, rather than deleting documentation. Coverage of the extracted file is enforced at 96.30% |
| R-03 | The CodeQL workflow's "what this does and does not cover" note had been removed, including the rule that unclosed gaps must not be shown as closed | Note restored and updated for `build-mode: manual` |
| R-04 | `safety_session_pin_lockout_test` had its file-wide bare-catch assertion NARROWED to a substring window to accommodate the new policy catches | File-wide guarantee restored: bare catches are pinned to exactly three and each must sit inside the `enforceLockout` branch. Mutation-checked — injecting a bare catch outside the guard fails the test |
| R-05 | `CheckInProjectionStore`, holding logic extracted from a critical file, was outside the 90% critical-coverage list | Added to `verify_critical_coverage.dart` and `critical_coverage_gate_test.dart` |

## New findings from this round's own review (N-)

These are NOT in the F01-F17 list. Two came out of an independent Kotlin review
of this round's own F02/F07 code; one came out of running the build on a booted
emulator. Every fix below was mutation-checked: the fix was reverted and the new
test was confirmed to fail.

| ID | Finding | Severity as verified | Fix |
|---|---|---|---|
| N-01 | All three notification channels were created with unguarded `.tr()` from the pre-runApp startup block, where the EasyLocalization delegate has not loaded the bundle yet, so `.tr()` returns the KEY. Android persists a channel's name on first creation, so the user sees `notification_channel_emergency_name` in system settings -- for the channel the grace warning posts to. Observed in the running build's own log on a booted emulator (API 36, commit 29757f5). Pre-existing, not a regression from this round | HIGH (user-visible, emergency notification surface) | Literal fallbacks via `_safeChannelTr`, the pattern `foreground_service.dart` already used for its own channel |
| N-02 | `warn()` committed the durable claim as `"unknown"` and only then posted. Because the idempotency check passed only `"notAttempted"`, a process death after the claim commit left the outcome permanently `"unknown"`, and the redelivered alarm returned it without ever posting. `reconcile()` never inspects warning outcomes. The warning was lost for that generation -- the exact defect the native warning exists to prevent | HIGH (missed warning) | `"unknown"` is a CLAIM, not a result, and is retryable. Safe: one notification id per kind means Android replaces rather than stacks, and `warn()` can never reach the final dispatch |
| N-03 | `EmergencyTerminalJournal.append` ran on every terminal `store.write()`. `expireFallback()` (up to 24h later) and `consumeFallbackTarget()` re-write the same terminal envelope to drop the retained target, which re-offered an already-acknowledged outcome from `pendingOutcomes()` | MEDIUM, **not** the HIGH it was reported as: `ActivityService.logEvent` uses `ConflictAlgorithm.ignore` keyed on `eventId`, so no duplicate history row and no re-dial could result. What broke was the "acknowledged stays acknowledged" contract | Journal on the TRANSITION into a terminal state; re-writing the same terminal state does not append, while a genuine change of terminal state still does |
| N-04 | `NativeNotificationText.preWarning()` read the DEVICE locale while every other copy in that file resolves the app's own persisted language. On an English phone with the app defaulting to Turkish, the Safe-Walk pre-warning arrived in English and the grace warning for the same session arrived in Turkish minutes later | MEDIUM (user-visible inconsistency) | Routed through the same `Strings`/`resolveLanguage` path as every other notification copy |
| N-05 | Warning notification ids 9998/9999 were duplicated as magic literals in the poster and in `cancel()`. Changing one and not the other would stop `cancel()` dismissing the warning, leaving "your time is nearly up" on screen after the session ended | MEDIUM (latent) | Unified under `EmergencyNotificationHelper.warningNotificationId(kind)` |
| N-06 | `CountdownScreen._cancelCountdownAndExit` awaited `PinLockoutService.instance.reset()` unguarded AFTER the native cancel was confirmed. A secure-storage failure there escaped the method: the Dart timer was already stopped, back is blocked (`canPop: false`) and the PIN pad ignores input while `_isNavigating` is set, so the user sat on a dead countdown until the app was killed. No call could result (the cancel was durable). Reproduced in a widget probe: correct PIN, `cancelled` from native, `PlatformException` from the lockout store, screen stayed, a second correct PIN produced no channel call. `safety_session_pin_gate.dart` already guarded the same call | MEDIUM (user trapped; no missed or unwanted call) | Reset failure caught as `Exception` only; cancel and exit continue, the counter persists. `countdown_lockout_reset_failure_test.dart`; reverting the fix fails it with `keystore_delete_failed`. Commit `0a6a8c5` |
| N-07 | The countdown awaited `WidgetsBinding.instance.endOfFrame` before arming the native session. `SchedulerBinding.scheduleFrame()` is a no-op while the app is `hidden`/`paused` (Flutter 3.38.9 `scheduler/binding.dart:949`), so if the phone was locked while the PIN/contact read was still pending, nothing requested a frame and the native session was not armed until the screen came back on. Widget probe: load finished, 60 s with no frame, no `armEmergencySession`; one frame, armed. **Not measured on a device:** a frame already pending at lock time (the glow pulse keeps one pending) may or may not be delivered by Android after the display turns off. The contract test pinned the unbounded wait | CRITICAL by this repo's definition if it occurs on devices (delays the emergency session); device occurrence UNVERIFIED | Wait bounded by `BoundedFrameWait` (300 ms, the fixed delay every dial paid before `endOfFrame`); the visible case is unchanged. `bounded_frame_wait_test.dart`, `countdown_locked_screen_arm_test.dart`; mutations: old wait -> no arm, no bound -> wait never ends, no timer cancel -> pending Timer caught. Commit `e79e56d` |
| N-08 | Force-stop during an armed panic countdown removes the app's alarms; no call is placed and nothing tells the user. When the app is next opened, Android (API 37 emulator) sends `LOCKED_BOOT_COMPLETED` on unstop and `BootCompletedReceiver` -> `reconcile` dispatches the overdue session immediately, before Flutter loads, with no age limit (`EmergencySessionCoordinator.kt:522-524`) -- one minute or days later. G6A expected the overdue state to be surfaced honestly, not called without asking. An update while stopped did NOT trigger dispatch (no `MY_PACKAGE_REPLACED` to a stopped package), disproving an earlier claim of mine. Observed on the emulator, not on OEM devices or older Android | HIGH (unrequested emergency call on app open; silent miss while stopped) -- **decision required, not fixed** | Open. Options for the owner: an age limit after which the session is surfaced instead of dialled, and/or a user-visible overdue notice. `docs/audit/device-verification-2026-09-13-force-stop.md`; phone check in `telefon-testi-protokolu-2026-09-14.md` Test C |

Reviewed and deliberately NOT changed, with reasons: `pendingOutcomes` /
`acknowledgeOutcome` do not take the coordinator's `PROCESS_LOCK`, but no
`android:process` is declared for any emergency component, so this is a single
process, SharedPreferences' own locking prevents corruption, and the N-03 fix
removes the resurrection path that made the missing lock reachable.
`CountdownAlarmReceiver` was not given a defensive action check: warning alarms
are never scheduled for PANIC today and `claimAndDispatch`'s own deadline guard
holds, so this is not an active bug. The real `AlarmManager` PendingIntent
identity behaviour for GRACE/PRE_WARNING cancellation cannot be proven in a unit
test and was added to the F13 device-verification inventory instead of being
asserted here.

One finding raised against F06 was checked and NOT confirmed: the future-anchor
plausibility guard was reported as "removed, not relocated". It is present and
intact in `lib/core/services/subscription_access_state.dart` -- unchanged by
this diff, which is why it is not visible in it: `canArmWithinOfflineGrace`
returns false and `remainingOfflineGrace` returns `Duration.zero` for a future
anchor, while the safety path deliberately checks presence only. That asymmetry
is the recorded owner decision of 2026-08-13 and is pinned by Scenario K in
`subscription_readiness_state_test.dart` plus the F06 cold-start test.

## Verification runs

| Check | Result |
|---|---|
| `flutter analyze --no-fatal-infos` | **No issues found** (exit 0) |
| `flutter test --no-pub` | **1816 passed, 0 failed** (exit 0), on the final commit and again in a tracked-only clean clone |
| `flutter test --coverage` + `dart scripts/verify_critical_coverage.dart` | **CRITICAL_COVERAGE_PASS**; every critical file ≥ 90% (contract 100.00, platform 94.99, parser 100.00, pin 96.15, check-in 91.71, projection store 96.30, contact 93.08); threshold unchanged at 90 |
| `./gradlew :app:testPlayDebugUnitTest` | **BUILD SUCCESSFUL**; 94 Kotlin tests, 0 failures, 0 errors, 0 skipped |
| `./gradlew :app:assemblePlayDebug` | **BUILD SUCCESSFUL** (F11 prerequisite) |
| `flutter pub get --enforce-lockfile` | exit 0; no dependency change |
| `ruby scripts/test_fastlane_release_boundary.rb` | 55 assertions, 0 failures (F10) |
| `python3 scripts/test_release_tag_trust.py` | OK (H02) |
| `python3 scripts/verify_release_change_classification.py` | **RELEASE_CHANGE_CLASSIFICATION_PASS**, 88 classified paths |
| `python3 scripts/verify_absence_claims.py` | **ABSENCE_CLAIMS_PASS**, 46 registered |
| `dart scripts/verify_alert_outcome_consumption.dart` | **PASS**, 176 files, 0 violations |
| Tracked-files-only clean checkout | analyze + full suite green; F09 acceptance met without any ignored machine file |

Not run, with reasons: the signed-AAB chain in `scripts/verify_release.sh`
requires the release keystore and `--dart-define` secrets, which this task is not
authorized to generate, change or print; hosted CodeQL, Play Console, RevenueCat
sandbox and physical devices were not accessible. No push, tag, merge, deploy,
upload, console change, payment or third-party contact was performed.

### Countdown review, 2026-09-13 (N-06, N-07)

Measured on the tree at `e79e56d`: `flutter analyze --no-fatal-infos` no issues;
`flutter test --no-pub` **1820 passed, 0 failed**; `lib/screens/countdown_screen.dart`
stays at its 1081-line ratchet (a 5-line doc comment for a method that had already
moved to `CountdownAnnouncement` was removed to absorb N-06's guard).

Still open, device-only: (1) whether a pending frame is delivered after the display
turns off (N-07 occurrence); (2) `MainActivity.openDialer` returns `true` after
`startActivity` even if Android's background-activity-launch restriction blocks it,
so a foreground-dial fallback with the screen off may report "dialer opened" when
nothing opened -- not reproduced; (3) `emergency_trigger_host.dart` also awaits an
unbounded `endOfFrame` on its cold-start navigator retry (runs on resume, lower risk).
Suggested device check: press panic, immediately press power, wait 15 s, confirm the call.

## Release decision

**NO-GO.** Local remediation and green local gates are not release approval. F13
is open by definition, F11's hosted CodeQL extraction evidence is missing, and
while F14's thresholds were approved by the owner on 2026-09-12, approving a
threshold is not the same as having rehearsed it: no named staffed owner/backup,
no two-operator tabletop and no measured recovery time exist yet. No signed
production candidate has been bound to physical-device, billing or Console
evidence.
