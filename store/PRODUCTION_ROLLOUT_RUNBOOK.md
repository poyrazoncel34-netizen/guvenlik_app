# KoruBeni Production Rollout and Incident Runbook

Status: `CODE_DONE` as an operator procedure. Every dashboard, device, billing,
and production observation remains `NEEDS_OPERATOR_ACTION` until evidence is
attached. This document does not authorize a release by itself.

## 1. Non-negotiable release model

KoruBeni has no developer backend and no remote emergency-core kill switch.
That is intentional: emergency deadlines and calls must not depend on our
server. It also means a broken installed emergency flow cannot be remotely
disabled or repaired. A fixed AAB with a higher `versionCode` is the only code
remediation.

Google Play staged rollouts are available for **updates**, not a track's first
release. Google also states that the first fully rolled-out release on a track
cannot be halted back to a previous release because none exists. Therefore:

- `v1.0.0` must earn production eligibility in internal/closed testing. Do not
  describe its production launch as a canary or rollback-capable release.
- For `v1.0.1+`, use a staged rollout. Halting stops further assignment but
  does not remove the bad version from devices that already received it.
- Halting a later 100% rollout can make the previous eligible release available
  again, but already-updated devices are not automatically downgraded. A hotfix
  is still required for affected users.

Official anchors:

- <https://support.google.com/googleplay/android-developer/answer/6346149>
- <https://support.google.com/googleplay/android-developer/answer/16285429>

## 2. Roles and decision authority

One person may hold several roles, but each name and backup must be written in
the release evidence before launch.

| Role | Accountable for | Can stop rollout? |
| --- | --- | --- |
| Release commander | Go/no-go, Play rollout, evidence timeline | Yes |
| Safety QA owner | Panic, Check-In, Safe Walk, call target, denied-permission and Doze behavior | Yes, unilaterally for a safety defect |
| Billing owner | Play/RevenueCat purchase, restore and entitlement truth | Yes for purchase/access defects |
| Incident owner | Triage, severity, hotfix coordination, post-incident record | Yes |
| Legal/policy owner | Data Safety, declarations, privacy/store-copy parity | Yes for policy/privacy defects |

Never schedule a production change unless the release commander and incident
owner are both reachable for the entire observation window.

## 3. Pre-production go/no-go packet

The release commander creates one evidence folder named
`YYYY-MM-DD-versionCode-versionName` containing all of the following:

1. GitHub workflow URL, tag, commit SHA, AAB SHA-256, provenance file, pinned
   upload-certificate SHA-256, and retained Dart debug symbols.
2. Play App Bundle Explorer screenshots proving package/version, permissions,
   absence of forbidden FGS/Amazon surfaces, and 16 KB compatibility.
3. Completed `REAL_DEVICE_QA_MATRIX.md`, including API 29, API 36/16 KB,
   Samsung, Xiaomi, dual-SIM and low-memory physical-device evidence and
   at least one aggressive-OEM device; real SIM/test-safe number evidence for
   direct call and `ACTION_DIAL` fallback.
4. Completed `BILLING_RELEASE_CHECKLIST.md`: monthly, annual, restore,
   cancel/lapse, no-offering and network-error behavior.
5. Play pre-launch report disposition, App Content forms, live legal URLs,
   screenshot PII review, and closed-test/production-access evidence.
6. Known-issues list. `None known` must be written explicitly; silence is not a
   decision.
7. Named roles, start time, observation window, and hotfix tag reservation.

Any missing item is `NO-GO`. A deadline or marketing date cannot waive a
safety, signing, billing, legal, or physical-device gate.

## 4. Production exposure plan

### First production release (`v1.0.0`)

There is no staged-rollout or prior-release fallback. Required compensation:

1. Keep the identical signed candidate in closed testing for at least 72 hours
   after the final billing/device test. Any AAB change resets the soak.
2. During the soak, run the critical manual matrix once at start and once in
   the final 12 hours on the exact candidate version.
3. Submit production only during staffed local business hours, never before a
   holiday/weekend or when the signing/billing owners are unavailable.
4. Treat production as an irreversible exposure for already-installed copies.
   Prepare the next higher patch version before launch; do not create its tag.

### Later updates (`v1.0.1+`)

Default percentages are 5% → 20% → 50% → 100%. Percentages do not advance
automatically. Hold each step for at least 24 hours; hold 50% for 48 hours.
When traffic is too small for meaningful Play statistics, elapsed time alone is
not evidence: repeat the signed-build critical manual matrix at every step and
extend the hold.

Do not start a second staged release over an unfinished one. Google notes that
the next rollout may reuse the same selected user group, so this is not an
independent canary population.

## 5. Observation board

At T+0, T+1h, T+4h, T+12h, T+24h, then daily through day 7, record:

| Surface | Exact filter/check | Evidence |
| --- | --- | --- |
| Play Android vitals | Version code; user-perceived crash/ANR; clusters; device/OS; anomalies | Timestamped screenshot/export and affected-user count |
| Play pre-launch/reviews | New stability, policy, device, accessibility or safety report | Link/screenshot plus disposition |
| RevenueCat | Production only; product/package; active subscription movement, refunds, customer-level entitlement cases | Redacted screenshot/export; never copy SDK/server secrets |
| Google Play orders | Purchase/cancel/refund status against a sampled redacted order set | Redacted reconciliation note |
| Manual safety probe | Panic, Check-In deadline, direct call or dial fallback, location denial, offline/no-SIM | Device/build/time and PASS/FAIL |
| Support/local logs | Voluntary user report and explicit local-log export only | Redact names, numbers, coordinates and PIN-related data |

RevenueCat charts show production transactions and can differ from Play because
their metric definitions differ. They are not a sandbox-test oracle or the tax
record. Reconcile individual entitlement problems with redacted customer/order
history, not only aggregate charts.

KoruBeni deliberately has no remote crash SDK. Android vitals is opt-in,
aggregated and delayed; absence of a chart or cluster does **not** prove absence
of failures. Local logs stay on device and are obtained only with the user's
explicit action. No operator may request a raw database or unredacted emergency
contact/location record.

Official anchors:

- <https://developer.android.com/topic/performance/vitals>
- <https://support.google.com/googleplay/android-developer/answer/9844486>
- <https://www.revenuecat.com/docs/dashboard-and-metrics/charts>

## 6. Stop criteria

The Google Play bad-behavior thresholds (currently 1.09% overall
user-perceived crash, 0.47% overall user-perceived ANR, and 8% per-device for
either) are store visibility boundaries, **not KoruBeni's acceptable safety
budget**. A release must stop before relying on those limits.

### P0 — stop immediately; hotfix or cancel launch

- Wrong number called; official emergency short code synthesized/called; call
  starts without the documented user action/countdown; duplicate calls.
- Confirmed Panic, Check-In or Safe Walk deadline/call failure on a supported
  physical device when documented preconditions are met.
- PIN bypass, biometric unlock, secret/signing exposure, or unredacted personal
  data disclosure.
- Data-loss/corruption that removes emergency contacts or changes the primary
  call target.
- Play policy rejection requiring behavior/declaration changes.

One confirmed P0 is enough. Rate and sample size are irrelevant.

### P1 — hold; incident owner decides within two hours

- Any new crash/ANR cluster on onboarding, PIN, Panic, countdown, Check-In,
  Safe Walk, permission handling, or paywall/entitlement return path.
- A Play anomaly, overall user-perceived crash rate >= 0.50%, overall
  user-perceived ANR rate >= 0.20%, or either rate >= 2% on one device model.
  These are conservative internal stop lines, not Google requirements.
- Reproducible purchase charged without entitlement, valid entitlement lost,
  or restore failure on the production product mapping.
- Material mismatch between live app behavior and Data Safety/store/legal copy.

With fewer than 200 daily active devices, percentage thresholds are unstable;
use affected counts, cluster severity and reproduction. Never dismiss one
critical-path report as “statistically insignificant.”

### Continue only when

There is no P0/P1, every observation checkpoint is recorded, critical manual
probes pass, and the release commander plus relevant owner sign the next-step
decision. `No data available` means `HOLD/INSUFFICIENT_EVIDENCE`, not PASS.

## 7. Containment and recovery

1. Start an incident record: UTC/local time, version, track/percentage,
   reporter, symptoms, privacy classification, and commander.
2. For a staged update, Play Console → track → Releases → Manage rollout →
   Halt rollout. Record the screenshot/time. Do not claim this repairs devices
   that already received the version.
3. For a later fully rolled-out update with an eligible previous release, use
   Manage rollout → Halt rollout. Record which prior version becomes available.
   Still ship a higher-version hotfix for already-updated devices.
4. For the first release, do not waste time searching for rollback: Play cannot
   halt it to a prior version. Produce a fixed AAB with a higher versionCode,
   repeat proportionate gates, and submit an expedited hotfix. If availability
   itself creates unacceptable harm, the Play owner evaluates unpublishing with
   legal/policy; it does not uninstall or downgrade existing copies.
5. For billing-only failure, stop new production exposure and correct
   Play/RevenueCat configuration. Removing an offering is not an emergency-core
   rollback and must not be described as one.
6. Preserve AAB, symbols, manifest, logs, screenshots and dashboard exports.
   Never overwrite evidence with the hotfix artifacts.
7. Resume only after root cause, reproduction, fix, regression test, affected
   device/billing retest, and signed go/no-go are documented.

## 8. Closeout

Within five business days, write a blameless incident/release note containing
timeline, scope, root cause, why gates did or did not catch it, corrective tests,
owner/due date, and whether this runbook's stop criteria changed. Production is
not `100% ready` merely because rollout reached 100%; readiness remains a
continuously evidenced operating state.
