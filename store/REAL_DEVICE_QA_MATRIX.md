# Real-Device QA Worksheet & Evidence Matrix

Status: NEEDS_REAL_DEVICE_TEST. Runtime/device execution is not evidenced from this repo. Emulator output, adb-only output, static review, Play Console assumptions, and RevenueCat assumptions are not production evidence.

Every scenario remains not-run until an operator records physical-device evidence in the Evidence log (§5). Redact phone numbers, precise coordinates, account emails, order IDs, screenshots with PII, and any sensitive logs before sharing evidence.

> **Process death is not Force stop.** Use `adb shell am kill PACKAGE` (or an OEM
> process-kill action that does not put the package in the stopped state) for
> Dart-dead/native-alarm tests. `adb shell am force-stop PACKAGE` is a separate
> user-stop contract: the package cannot self-start while stopped. On Android 15
> the system also [cancels all pending intents when the package enters the stopped
> state](https://developer.android.com/about/versions/15/behavior-changes-all).
> Therefore a call firing *during* Force stop is not a valid pass criterion; G6A
> tests honest suspension and recovery after explicit user relaunch.

> ⚠️ **Run device QA on the SIGNED RELEASE AAB** (internal-testing track): debug builds skip
> R8/obfuscation, so keep-rule regressions (receiver names, MethodChannel) only show in release.
> Never place a real emergency call; use the second test phone as the emergency contact.

This worksheet is the execution and evidence companion of
[MANUAL_SMOKE_TEST_SCRIPT.md](MANUAL_SMOKE_TEST_SCRIPT.md) (same expectations, condensed) and
covers all eight device-only proof items of `docs/HANDOVER.md` §11 — see the mapping in §4.

## 1. Device pool (minimum)

| Column | Device class | Target Android | Why this device |
| --- | --- | --- | --- |
| PIX | Stock Android / Google Pixel | API 36, 16 KB kernel | Upper-bound OS and page-size behavior |
| SAM | Samsung (One UI) | API 34/35+ | OEM battery management, lock-screen notification skinning |
| XIA | Xiaomi / HyperOS | API 34/35+ | Aggressive app-kill / autostart policies |

In addition to the three columns, the evidence bundle must include an arm64
API 29 boundary phone and must collectively cover one dual-SIM device and one
low-memory phone. These are mandatory support-envelope checks, not optional
substitutes. Record their repeated deadline/race sweeps as additional device
entries in the Evidence log.

Cell legend: `☐P ☐F` = mark P (passed) or F (failed) after the run; `—` = not applicable on
that device; "1 device" in Notes = running it on a single device is enough.

### 1.1 Release-blocking repetition and timing acceptance

On every Pixel/Samsung/Xiaomi column, execute 100 fake deadline deliveries,
50 cancel-vs-expiry races, and 20 process-kill/Doze/reboot cycles. Across the
pool, use a controlled second phone for at least 10 automatic Telecom requests
and 10 manual dial observations; include dual-SIM, ask-every-time, no-SIM,
airplane, no-service, and ongoing-call states.

- Panic backup: p99 no more than 5 seconds late; no sample over 10 seconds.
- Check-In/Safe Walk final deadline: p99 no more than 10 seconds late; no
  sample over 30 seconds.
- One unexplained missed deadline, wrong target, confirmed-cancel dispatch, or
  PIN bypass fails G7 and invalidates the candidate.
- Connection may be observed by a witness but remains `unknown` in app state.

### 1.2 Mandatory signed-candidate preflight

Before scenario A1 on each fresh device/build combination, run the read-only
preflight. Copy the Play Console **app-signing** SHA-256 certificate fingerprint,
not the upload-certificate fingerprint:

```bash
ANDROID_SERIAL=<adb-serial> \
PHASE3_DEVICE_LABEL=PIX-01 \
EXPECTED_VERSION_NAME=1.0.0 \
EXPECTED_VERSION_CODE=10000 \
EXPECTED_APP_SIGNING_SHA256=<64-hex-play-app-signing-digest> \
./scripts/phase3_physical_device_preflight.sh
```

The preflight refuses emulators, the wrong package/version, debug/test-only
builds, non-Play installs and a mismatched Play app-signing certificate. It
records no device serial and performs no app launch, permission mutation, call,
process kill or reboot. `PASS_PREFLIGHT_ONLY` proves device/build identity; it
does **not** pass any scenario row. Attach its generated Markdown file to the
evidence bundle, then execute the operator-observed matrix below.

## 2. Recommended run order (per device)

Run phases in this order on EACH device. **Destructive steps — permission revoke, process kill, force-stop,
data wipe — always come LAST (Phase 8):** they invalidate install state, and anything executed
after them on the same install is not clean evidence.

1. **Phase 0 — fresh install & guards:** A1 → A2 → **A3 (empty-target guard, BEFORE any contact is configured)**.
2. **Phase 1 — contacts & target validation:** B1 → B2 → B3 → B4 → B5.
3. **Phase 2 — emergency call paths (prompt-level permission states):** C1 → C2 → C3 → C4 →
   C5 → C6 → C7 (the incoming-call interruption family; needs a THIRD phone as the caller).
4. **Phase 3 — sessions & timers:** D1 → D6.
5. **Phase 4 — notifications & locale:** E1 → E6.
6. **Phase 5 — Doze / OEM reliability:** F1 → F4.
7. **Phase 6 — maps & extras:** H1 → H4, I1 → I4. (A4 legal URLs anytime; K video on the best-looking device.)
8. **Phase 7 — billing (license-tester device only):** J1 → J7.
9. **Phase 8 — DESTRUCTIVE, in this order:** G1 (reboot, active) → G2 (reboot, expired) →
   G3 (exact-alarm revoke mid-session) → G4 (process death + formatted number + BAL) →
   G5 (CALL_PHONE revoke + process-death tour) → G6 (process-death dedup race) →
   G6A (explicit Force stop contract) → G7 ("Delete my data" wipe) →
   G8 (reinstall + billing restore).

## 3. Scenario catalog + per-device matrix

### A — Fresh install, guards, legal

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | NEEDS_REAL_DEVICE_TEST | App launch (signed build) | Install signed internal-testing AAB; open app | Reaches consent/onboarding/unlock or home without crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| A2 | NEEDS_REAL_DEVICE_TEST | Consent/onboarding | Complete required legal consent and onboarding | Consent recorded locally; main navigation entered | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| A3 | NEEDS_REAL_DEVICE_TEST | Empty emergency target fail-safe | With NO emergency contact configured, try to arm Panic, Check-In, and Safe Walk; in a controlled setup force an empty persisted target and run a test flow | Arming is blocked with visible "add a contact" guidance; a forced empty-target dispatch fails VISIBLY (blocking full-screen fail-safe); never falls back to `112`; no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/7; run BEFORE adding contacts |
| A4 | NEEDS_OPERATOR_ACTION | Legal URLs open | Open Privacy, Terms, Data deletion, and Aydınlatma links from the app | Each live URL opens the expected page; save URL+date screenshot per link | ☐P ☐F | — | — | 1 device |
| A5 | NEEDS_REAL_DEVICE_TEST | Consent re-prompt after legal version bump | In a controlled build with a bumped legal version, update and open | Required consent is re-prompted and recorded locally | ☐P ☐F | — | — | 1 device; before production if legal version changes |

### B — Contacts & target validation

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| B1 | NEEDS_REAL_DEVICE_TEST | Contacts picker select | Pick a test contact via the system picker (ACTION_PICK) | Only the selected contact is stored locally; no READ_CONTACTS prompt appears | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| B2 | NEEDS_REAL_DEVICE_TEST | Contacts picker cancel | Open picker, cancel | App returns without error; nothing stored | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| B3 | NEEDS_REAL_DEVICE_TEST | Manual contact entry | Enter name and phone manually | Contact saves locally; selectable as emergency contact | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| B4 | NEEDS_REAL_DEVICE_TEST | Short-code target rejection | Try to enter/select `112` (or another official short code) as the emergency number | Rejected as a callable target (only 7–15 digit user numbers are callable); short codes can NEVER become auto-call targets; legal copy still tells the USER to dial 112 themselves | ☐P ☐F | ☐P ☐F | ☐P ☐F | Replaces the stale "112 is accepted" row; see HANDOVER §2.1 |
| B5 | NEEDS_REAL_DEVICE_TEST | Formatted-number save via picker (audit F5, part 1) | Via ACTION_PICK save the second test phone whose contact number is stored formatted as `(0555) 010-20-30`; set it as primary | Contact saves; number is normalized/dialable from the app (the Dart-dead proof is G4) | ☐P ☐F | ☐P ☐F | ☐P ☐F | |

### C — Emergency call paths (test-safe number = second test phone)

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C1 | NEEDS_REAL_DEVICE_TEST | Emergency CALL_PHONE granted Telecom path | Grant CALL_PHONE; start SOS/countdown from an explicit user action | An unconfirmed request is submitted to Android Telecom only after the user-armed flow; the app never records ringing/connection | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| C2 | NEEDS_REAL_DEVICE_TEST | CALL_PHONE denied ACTION_DIAL fallback | Deny CALL_PHONE; try long-running sessions and a visible Panic countdown | Check-In/Safe Walk are not armed. Panic remains a foreground countdown and opens the dialer only from the visible Activity; no automatic/background claim | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| C3 | NEEDS_REAL_DEVICE_TEST | Native Telecom request failure fallback | Where safely forceable, make the native Telecom request fail | An actionable TTL-bounded notification opens ACTION_DIAL **for the user's target number** after user tap, or a visible failure is surfaced; never `112` | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| C4 | NEEDS_REAL_DEVICE_TEST | No SIM / airplane mode | Enable airplane mode or remove SIM; start SOS with the test-safe number | Visible dialer/manual/failure state; app never silently fails; no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| C5 | NEEDS_REAL_DEVICE_TEST | Incoming call during armed countdown — REJECT | Arm Panic; while the countdown is visibly running, place a call from the third phone; reject it; return to the app | Countdown continues against its ORIGINAL deadline (no reset to 10, no second countdown); at most one dispatch occurs; PIN cancel gate still required | ☐P ☐F | ☐P ☐F | ☐P ☐F | Expanded case below; C5–C7 are one interruption family |
| C6 | NEEDS_REAL_DEVICE_TEST | Incoming call during armed countdown — ACCEPT, deadline elapses during the call | Arm Panic; place a call from the third phone; ANSWER it; stay on the call past the 10 s deadline; hang up; return to the app | Dispatch happens exactly once (Dart or native claim, never both); the app shows a typed outcome, never a false "completed"; ledger and result surface agree | ☐P ☐F | ☐P ☐F | ☐P ☐F | Answering may block the outbound request — a typed failure is a PASS, a silent success is a FAIL |
| C7 | NEEDS_REAL_DEVICE_TEST | Incoming call inside the final-3 s dispatch window | Arm Panic; time the incoming call to land with ≤3 s remaining, i.e. inside the claim race | Exactly one Telecom request per generation in normal execution; any duplicate is recorded against the declared request/terminal-commit window; no missed dispatch | ☐P ☐F | ☐P ☐F | ☐P ☐F | Hardest timing row; run it last of the three |

#### C5–C7 expanded case — incoming phone call while the emergency countdown is armed

Written as an executable case because the interruption crosses four subsystems at once
(Android Telecom, the Dart countdown, the native AlarmManager claim, and the PIN cancel
gate) and a table cell cannot carry the fail criteria for that.

**Design facts this case is written against** (verify against the tree, do not assume):

- The panic countdown is **deadline-driven, not tick-decrementing**:
  `_startDartCountdownTimer` polls every 200 ms and derives the remaining seconds from
  `CountdownClock.secondsUntil(_armedDeadline)` (`lib/screens/countdown_screen.dart`).
  A pause therefore cannot make the countdown drift or restart — it recomputes.
- `CountdownScreen` is deliberately **not** a `WidgetsBindingObserver`. It reacts to no
  lifecycle callback; the wall-clock deadline plus the native session is the authority.
  This case exists to prove that design on hardware, not to assume it.
- The native AlarmManager session is armed **before** the Dart timer starts, and both race
  the same deadline. `EmergencySessionCoordinator` documents an at-least-once durable
  CLAIMED state: `submittedInProcess` blocks a second Telecom request for the same
  generation **within one process**, while a crash between Telecom accepting and the
  terminal commit is a declared, irreducible duplicate window.
- Panic countdown audio is **haptic only** (`HapticService.countdownTick`). There is no
  siren and no audio player in this path — do not record a siren observation here.

**PRECONDITIONS**

1. Signed release AAB from the internal-testing track (§1.2 preflight already `PASS_PREFLIGHT_ONLY`).
2. Pro entitlement active; PIN configured; primary emergency contact set to the **second**
   test phone; CALL_PHONE granted; notifications allowed; exact-alarm access granted.
3. A **third** phone able to call the device under test. The second phone stays the
   emergency target and must never be the caller — otherwise the two roles collide.
4. Device unlocked, app foreground, screen on, no other safety session active.
5. Starting alarm/ring volume recorded, and Do-Not-Disturb OFF (DnD suppresses the incoming
   call and voids the case).

**STEPS**

1. Arm Panic from an explicit user action and confirm the countdown is visibly running.
2. From the third phone, place a voice call to the device under test:
   - **C5** with roughly 6–8 s remaining, then **reject**.
   - **C6** with roughly 6–8 s remaining, then **answer** and stay connected past the
     deadline, then hang up.
   - **C7** with ≤3 s remaining (repeat until the timing actually lands; a mistimed
     attempt is discarded, not recorded as a pass).
3. In every variant, return to the app and observe without touching anything for 5 s.
4. Then attempt to cancel; then inspect the safety timeline.

**EXPECTED UI STATE**

- The incoming-call UI takes the foreground; the countdown screen is backgrounded. No crash,
  no ANR, no black or blank frame on return.
- On return the countdown screen (or its successor surface) is shown, with **one** countdown
  visible. Two stacked countdown routes is a FAIL.
- Safety controls — cancel affordance and the PIN entry it leads to — are reachable and hit
  their ≥48 dp target after the interruption.

**EXPECTED COUNTDOWN STATE**

- The remaining seconds on return equal `original deadline − now`, within one tick.
- Never resets to 10. Never jumps backwards. Never runs two timers (visible as a
  double-speed decrement or duplicate haptic ticks).
- If the deadline passed while the app was backgrounded, the countdown does not "resume" —
  the dispatch path has already been entered exactly once by whichever contender claimed.

**EXPECTED AUDIO/HAPTIC STATE**

- Haptic ticks may be suppressed by the platform while the call UI owns the foreground; that
  is acceptable. Duplicate or double-rate ticking on return is NOT.
- Ring/alarm volume is unchanged by the app at the end of the case.
- No siren is expected in this path; if one is heard, that is a defect against the design
  facts above and must be recorded.

**EXPECTED APP LIFECYCLE BEHAVIOR**

- The app moves to `inactive`/`paused` and is expected to survive as a process. If the OEM
  kills it, the native alarm remains the authority — record which contender fired.
- No autonomous navigation happens because of the interruption: an incoming call must not
  push, pop, or replace a route on its own.
- The foreground-service/wakelock scope must not widen. A wakelock still held after the case
  ends is a FAIL.

**EXPECTED POST-CALL STATE**

- **Exactly one** dispatch per armed generation in normal execution. If a duplicate appears,
  it must be attributable to the declared request/terminal-commit crash window and recorded
  as such — never rounded down to "fine".
- The result surface shows a **typed** outcome. If the outbound request was blocked because a
  call was active (the realistic C6 outcome), the app must say so as a definite failure or an
  explicit unconfirmed state, and offer the manual-call affordance.
- **No false completed state.** A "completed / handed off" claim with no corresponding
  Telecom request is the most serious failure this case can find.
- The safety timeline records the session once, with the outcome that actually occurred.
- **No lost security gate:** cancelling still demands the correct PIN plus native
  acknowledgment. Returning from a call must never leave a PIN-less cancel, and must never
  land the user inside the tab shell without passing consent → onboarding → PIN unlock.

**FAIL CRITERIA** (any one of these fails the row)

| # | Failure |
|---|---|
| 1 | Countdown resets, jumps, or drifts more than one tick from the original deadline |
| 2 | Two countdowns run, or a second countdown route is stacked |
| 3 | Two Telecom requests for one generation outside the declared crash window |
| 4 | No dispatch at all after the deadline passed during the call |
| 5 | A "completed"/"handed off" claim with no observed request on the second phone |
| 6 | Cancel becomes possible without the correct PIN, or the PIN gate is skipped on return |
| 7 | The tab shell is reachable after the interruption without passing its gates |
| 8 | Crash, ANR, or a wakelock still held after the case ends |
| 9 | The emergency target changes, or `112` appears as an auto-call target at any point |

**EVIDENCE TO CAPTURE**

1. Screen recording of the whole case from arm to post-call state (redact the number).
2. Second-phone photo/recording showing whether a request arrived, with wall-clock time.
3. `adb logcat` excerpt around the deadline, filtered to the emergency tags, showing which
   contender claimed the generation.
4. Post-case screenshot of the safety timeline entry.
5. The countdown value observed at the moment of return, against the recorded arm time.
6. Device, Android version, build versionName/versionCode, track, and DnD state.
7. For C7 only: the actual remaining-seconds value when the call landed, so the timing is
   auditable rather than asserted.

### D — Sessions & timers (Pro active)

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | NEEDS_REAL_DEVICE_TEST | Safe Walk start/check-in/expiry/cancel | Start, check in, cancel; separately run the expiry path | Session is user-visible, cancellable, clears state, escalates only through the expected flow on expiry | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| D2 | NEEDS_REAL_DEVICE_TEST | Check-In start/grace/expiry/cancel | Start timer, enter grace, expire; repeat with cancel/reset | Grace and expiry are visible; "I'm safe" in grace is a single PIN-less tap; state clears correctly | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| D3 | NEEDS_REAL_DEVICE_TEST | Countdown cancel & PIN gate | Try to arm without a PIN; configure PIN; then cancel with wrong and correct PIN | No-PIN state cannot arm; loading/read failure never becomes PINless cancel; only correct PIN plus native acknowledgment shows confirmed cancellation | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| D4 | NEEDS_REAL_DEVICE_TEST | Single-dispatch claim (Dart alive) | Start countdown, keep app foreground, let it fire | One generation claim and at most one Telecom request in normal execution; connection remains `unknown`; exact/inexact loser reads durable terminal state | ☐P ☐F | ☐P ☐F | ☐P ☐F | Process-death residual is G6 |
| D5 | NEEDS_REAL_DEVICE_TEST | Exact alarm allowed | With exact-alarm access granted start Safe Walk, Check-In, countdown backup | No degraded warning; timer scheduling succeeds | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| D6 | NEEDS_REAL_DEVICE_TEST | Exact alarm denied/default-denied | Fresh install with exact alarm denied; try Check-In, Safe Walk, scheduled fake call, and Panic | Long-running/scheduled sessions never become `ARMED`; Panic is visible foreground/manual-dial only and has no background guarantee; no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | Mid-session revoke is G3 |

### E — Notifications & locale

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E1 | NEEDS_REAL_DEVICE_TEST | Notification allowed | Allow notifications; start Safe Walk or Check-In; background the app and lock the screen | Ongoing safety-session notification exists; secure-lock-screen content follows Android privacy settings and must not expose the contact number | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| E2 | NEEDS_REAL_DEVICE_TEST | Notification denied | Deny notification permission; try to start long-running sessions | Session is not armed, readiness explains the blocker, and no crash occurs | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| E3 | NEEDS_REAL_DEVICE_TEST | Status-notification truth (A14/15) | Start a session, background the app; inspect App info → active services where available | Ordinary local ongoing notification names the session; no foreground service is running or declared, and the notification is never treated as process-liveness proof | ☐P ☐F | ☐P ☐F | — | |
| E4 | NEEDS_REAL_DEVICE_TEST | Status notification stop/cancel | Cancel / check in / end session | Timer state and native schedules stop; ongoing status notification clears | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| E5 | NEEDS_REAL_DEVICE_TEST | Urgent alert | Let the timer expire with the app backgrounded | A HIGH-importance heads-up/actionable fallback is attempted. No full-screen-intent or DnD-bypass claim exists; the number is absent from lock-screen copy | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| E6 | NEEDS_REAL_DEVICE_TEST | Turkish notification on English system locale (audit F8) | Set SYSTEM LANGUAGE to English; start Check-In; lock the screen; let the main timer expire; then unlock | Secure lock screen shows only privacy-appropriate notification presence; after unlock, emergency/grace copy is TURKISH and actions work | ☐P ☐F | ☐P ☐F | ☐P ☐F | |

### F — Doze / OEM reliability

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| F1 | NEEDS_REAL_DEVICE_TEST | Battery optimization not exempted | Without the exemption, start a safety timer and background the app | App explains the optional reliability improvement and the degraded behavior; works degraded | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| F2 | NEEDS_REAL_DEVICE_TEST | Doze/process death: countdown native backup fires | Start countdown; background + screen off; use `adb shell am kill PACKAGE`, never `am force-stop`; `adb shell cmd deviceidle force-idle` may trigger Doze, but evidence is the observed request/fallback | At least one request or actionable fallback is observed. Any duplicate is recorded and investigated against the documented request/terminal-commit crash window; no “exactly once” claim is made | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| F3 | NEEDS_REAL_DEVICE_TEST | Doze/process death: check-in & safe-walk escalation fires | Same as F2 for Check-In and Safe Walk expiry, using process death rather than Force stop | Native escalation targets ONLY the immutable primary snapshot; at least one request/actionable fallback is observed, and duplicate residual risk is recorded rather than hidden | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| F4 | NEEDS_REAL_DEVICE_TEST | OEM-kill survival | On Samsung/Xiaomi default aggressive battery settings, run the repeated deadline suite in background | Armed sessions meet the declared delivery bounds with no missed deadline; any miss fails G7. No FGS survival claim exists | — | ☐P ☐F | ☐P ☐F | |

### G — DESTRUCTIVE (always LAST on each device, in this order)

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| G1 | NEEDS_REAL_DEVICE_TEST | Direct Boot restore (active timer) | Start an active timer; reboot and leave the device locked past boot completion | Device-protected token/generation/deadline is reconciled without Flutter, secure storage, PIN, or RevenueCat; the alarm remains armed | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| G2 | NEEDS_REAL_DEVICE_TEST | Direct Boot restore (expired session) | Arrange final deadline to pass during reboot; keep device locked | Native request+actionable fallback are attempted before user unlock; app later shows only typed unconfirmed/manual/failed truth | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| G3 | NEEDS_REAL_DEVICE_TEST | Exact alarm revoked mid-session | Revoke exact-alarm access while timers are active | Android cancels the exact alarm and may stop the app; the independently armed inexact backup remains the degraded path. On next user open, degraded state is surfaced/reconciled; delivery may be late; no crash or guarantee claim | ☐P ☐F | ☐P ☐F | ☐P ☐F | [Android alarm permission behavior](https://developer.android.com/develop/background-work/services/alarms); HANDOVER §11/5 |
| G4 | NEEDS_REAL_DEVICE_TEST | Dart-dead native call with formatted number + BAL visibility (audit F5) | Primary = B5 formatted contact; start shortest Check-In; background it; run `adb shell am kill PACKAGE` (not Force stop); let main+grace expire | Native backup targets the CORRECT normalized number. Confirm by eye whether the call UI/second phone is reached; `startActivity` returning is not proof. If Android BAL blocks UI, the unconfirmed/manual notification path must be visible after unlock | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| G5 | NEEDS_REAL_DEVICE_TEST | Dispatch-failure fail-safe tour | With a session active: revoke CALL_PHONE, kill the process (not Force Stop), and let final deadline expire | Actionable notification appears without exposing the number. A user tap atomically consumes the token-gated target and opens the dialer; stale/replayed actions fail closed | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| G6 | NEEDS_REAL_DEVICE_TEST | Dispatch race under process death | Kill the process around expiry; let exact/inexact/native/Dart contenders run; reopen app | Normal execution is at-most-one request. Any duplicate in the narrow request-before-terminal-commit crash window is recorded as the declared residual; missed dispatch or false confirmed cancel fails the gate | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| G6A | NEEDS_REAL_DEVICE_TEST | Explicit Force stop contract (Android 15+) | Arm a controlled test-safe timer; run `adb shell am force-stop PACKAGE`; wait past deadline; explicitly relaunch app | No autonomous alarm/call is expected while stopped because Android 15 cancels PendingIntents. Relaunch removes stopped state; app/BOOT_COMPLETED restoration surfaces the overdue state honestly without duplicate dispatch | ☐P ☐F | ☐P ☐F | ☐P ☐F | This is platform suspension, not a native-alarm failure |
| G7 | NEEDS_REAL_DEVICE_TEST | "Delete my data" native wipe | Run full data deletion from the app; then probe behaviorally | Native `korubeni_emergency` prefs are empty: no stale primary number anywhere; arming demands re-adding a contact; no expiry path can ever call the OLD number | ☐P ☐F | ☐P ☐F | ☐P ☐F | HANDOVER §11/6 |
| G8 | REVENUECAT | Reinstall + billing restore | Reinstall/clear data; tap restore | Active tester purchase restores Pro, or the no-purchase state is explicit | ☐P ☐F | — | — | 1 device (license tester); PLAY_CONSOLE also required |

### H — Maps & location

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| H1 | NEEDS_REAL_DEVICE_TEST | Location allowed | Allow location; open map | Real location appears only after permission; attribution visible | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| H2 | NEEDS_REAL_DEVICE_TEST | Location denied | Deny location; open map | Clear fallback; no fake coordinates | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| H3 | NEEDS_REAL_DEVICE_TEST | Offline map/network failure | Disable network or block the tile provider; open map | Offline fallback is clear, localized, no crash | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| H4 | NEEDS_REAL_DEVICE_TEST | OSM attribution visible | Open every map surface online | `OpenStreetMap contributors` attribution is visible | ☐P ☐F | ☐P ☐F | ☐P ☐F | |

### I — Extras

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| I1 | NEEDS_REAL_DEVICE_TEST | Fake call immediate | Start an immediate fake call | Fake call UI appears; no real call placed | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| I2 | NEEDS_REAL_DEVICE_TEST | Fake call scheduled | Schedule a fake call | Scheduled fake-call notification/UI appears; no real call placed | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| I3 | NEEDS_REAL_DEVICE_TEST | Siren max volume and restore | Record the starting alarm volume; start/stop siren | Siren uses alarm volume; original volume restored | ☐P ☐F | ☐P ☐F | ☐P ☐F | |
| I4 | NEEDS_REAL_DEVICE_TEST | Volume-button panic foreground-only | Press the trigger sequence in foreground and background | Triggers in foreground only; background never triggers a hidden SOS | ☐P ☐F | ☐P ☐F | ☐P ☐F | |

### J — Billing (license-tester device; 1 device is enough)

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| J1 | REVENUECAT | Billing license tester purchase | Purchase monthly and annual products | Entitlement activates after purchase | ☐P ☐F | — | — | PLAY_CONSOLE also required |
| J2 | REVENUECAT | Billing cancel/manage | Open manage subscription / customer center | Manage/cancel path opens Google Play/RevenueCat safely | ☐P ☐F | — | — | |
| J3 | REVENUECAT | Billing expired/lapsed | Let the sandbox subscription expire/lapse; refresh app | Pro access removed; paywall/no-entitlement copy appears | ☐P ☐F | — | — | |
| J4 | REVENUECAT | Billing renewal/lapse cycle | Observe a sandbox renewal and lapse cycle | Entitlement follows sandbox state | ☐P ☐F | — | — | |
| J5 | REVENUECAT | Billing account hold/paused | Trigger the available sandbox state | Non-active entitlement handled without crash | ☐P ☐F | — | — | If available in sandbox |
| J6 | REVENUECAT | No-offering fallback | With a controlled no-offering dashboard/build state, open the paywall | Fallback/retry UI appears; no crash | ☐P ☐F | — | — | |
| J7 | REVENUECAT | Billing network failure | Open paywall/purchase/restore while offline | Sanitized error appears; no secret/error dump | ☐P ☐F | — | — | Restore itself is G8 |

### K — Release QA evidence video

| ID | Gate | Scenario | Steps | Expected | PIX | SAM | XIA | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| K1 | NEEDS_REAL_DEVICE_TEST | Alarm/status-flow evidence capture | Record per the canonical shot list: [docs/play-submission.md §1 → "QA evidence video — shot list"](../docs/play-submission.md) | Video shows user-started, visible, time-bound, cancellable behavior; all numbers/account data redacted | ☐P ☐F | — | — | Internal release evidence; do not submit as an FGS declaration |

## 4. HANDOVER §11 coverage map

| §11 item (device-only proof) | Worksheet rows |
| --- | --- |
| 1. Native backup call actually fires under Doze/app-kill (countdown + check-in/safe-walk) | F2, F3 |
| 2. Boot-restore expired-session native call | G1, G2 |
| 3. Dedup race (Dart resume ↔ native fire) | D4, G6 |
| 4. OEM-kill (Xiaomi/Samsung) native-alarm behavior | F4 |
| 5. Exact-alarm denial → fail-closed arming; post-arm revoke → inexact backup | D6, G3 |
| 6. "Delete my data" → native `korubeni_emergency` really emptied | G7 |
| 7. Empty-target fail-safe visible/blocking on device | A3 |
| 8. Dispatch-failure fail-safe tour (F1): manual-call notification, 7304/7303 tap paths, lock screen, BAL visibility | G5 (+ G4 for the BAL eye-check) |

Post-audit additions requested after FRESH_AUDIT: F5 formatted-number normalization (B5 + G4),
F8 Turkish notification under English system locale (E6), 7304/7303 notification tap paths (G5),
receiver-launched call screen visibility / BAL (G4, G5).

## 5. Evidence log (append-only)

Append one row per executed scenario per device. Keep evidence filenames here; do not store
screenshots containing real phone numbers, real precise locations, account emails, or purchase
IDs in the repo.

| Gate | Device | Android version | Build version | Track | Preconditions | Scenario | Steps | Expected | Actual | Pass/Fail | Evidence file | Tester | Date | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | | | | | | |
