# Observability and service objectives — KoruBeni

> This document exists to convert an *implicit absence* into an *explicit decision*.
> KoruBeni ships no telemetry. That is deliberate and published. The consequence — that
> the operator is nearly blind after release — was previously undocumented, which meant a
> future maintainer could reasonably assume production data existed somewhere. It does not.

Last reviewed: 2026-08-12 · Owner: repository owner (single maintainer)

---

## 1. What is deliberately absent

There is **no** analytics SDK, crash-reporting SDK, APM, log shipper or event pipeline.
`lib/core/config/app_environment.dart` states it, `AGENTS.md` mandates it ("No developer backend, no analytics, no ad SDKs"), and the in-app KVKK text
tells users the app collects no advertising or attribution identifier.

**Do not resolve any gap in this document by adding an analytics SDK.** Doing so would
contradict a published KVKK commitment, the Play Data Safety declaration, and the project's
own security rules. The commercial cost of blindness is accepted in exchange for a privacy
claim the product actually makes to users.

Telemetry that does exist is local only and never leaves the device:

| Mechanism | File | Reaches operator? |
|---|---|---|
| Structured error codes | `lib/core/services/local_logger_service.dart` | No |
| Crash log table | `lib/core/services/crash_log_service.dart` | Only via user export |
| Native safety event ring | `android/.../NativeSafetyEventRing.kt` | No |
| Startup diagnostics / health check | `startup_diagnostics_service.dart`, `health_check_service.dart` | No |

---

## 2. What is actually observable

Google Play Console provides these **without any SDK** and without a Data Safety change:

| Signal | Source | Use |
|---|---|---|
| Crash-free session rate | Play Console → Android vitals | Primary release health gate |
| ANR rate | Play Console → Android vitals | Primary release health gate |
| Excessive wakeups / stuck wake locks | Play Console → Android vitals | Watches native alarm/wakelock paths; no custom FGS |
| Install / uninstall counts | Play Console → Statistics | Coarse retention proxy |
| Subscription retention & cancellations | Play Console → Subscriptions | Commercial KPI |
| Store reviews and ratings | Play Console → Ratings | Highest-signal qualitative channel |
| Support email volume | korubeni.destek@gmail.com | Qualitative |

For a trust product with no telemetry, **store reviews are the most informative production
signal available.** Treat them as monitoring, not marketing.

---

## 3. Objectives

Two objectives, both genuinely measurable for this architecture. Neither is a classic
uptime SLO, because there is no service to be up.

### SLO-1 — Release stability (continuous, Play-observed)

| | |
|---|---|
| **SLI** | Crash-free session rate, and ANR rate, per release, from Play Console vitals |
| **Objective and halt decision** | The single canonical procedure in `store/PRODUCTION_ROLLOUT_RUNBOOK.md` §§4–6; OPERATOR_DECISION_RESOLVED 2026-09-12 by the owner |
| **Owner / cadence** | Thresholds and cadence are approved; a named staffed owner/backup and an actual rehearsal are still required before release. `docs/release/operations_threshold_decision.md` records the decision and the superseded historical values |

### SLO-2 — Dispatch latency (per release, hardware-verified)

| | |
|---|---|
| **SLI** | Wall-clock time from panic press to the Telecom call request being submitted, screen off, Doze active |
| **Objective** | Within the budget defined in `.claude/rules/common/performance.md` |
| **Verification** | Physical device, per release, recorded in `docs/audit/` |
| **Why not continuous** | Measuring this in production would require telemetry. It is a **release gate**, not a monitor. |

`test/screens/dispatch_path_latency_contract_test.dart` enforces the *structural* half of
SLO-2 continuously in CI (no fixed delay before arming, no transition animation on the
dispatch path, haptics not awaited). The numeric half is device work.

---

## 4. Error budget

A conventional error budget needs a request stream. There isn't one. The operative
equivalent: **unresolved safety defects or an unapproved observation/stop decision block release.** Feature work continues; distribution does not.

---

## 5. Post-launch watch list

For the first 30 days after a production rollout, check on the SLO-1 cadence:

- [ ] Crash-free session rate and ANR rate
- [ ] Subscription conversion and cancellation reasons
- [ ] Store reviews — specifically for reports that the panic flow did not work
- [ ] Support email volume and top themes
- [ ] Uninstall rate relative to installs

**Explicitly unobservable by design** (do not go looking for these; they do not exist):
activation funnel, feature-usage rates, time-to-value, in-app error rates, session length,
screen-flow analytics, per-user behaviour of any kind.

---

## 6. Known limitation: post-incident evidence

When a user reports that a safety flow failed, the operator has **no** server-side trace.
The only evidence path is:

First diagnosis requests only app version, Android/device model, approximate incident time, reproduction steps and an allowlisted local error code if available. Do not ask for a full user-data export, raw database, screenshots containing contacts, or free-form diagnostic payloads. Do not collect names, phone numbers, email, PINs or coordinates. User data export remains a separate voluntary personal-data-copy feature, not a support prerequisite. If the user cannot safely obtain a code, proceed with the non-personal reproduction description. No new telemetry is introduced.
