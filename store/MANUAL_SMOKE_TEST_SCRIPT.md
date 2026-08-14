# Manual Smoke Test Script

Status: NEEDS_REAL_DEVICE_TEST. This script is an evidence template, not evidence. Record results in `store/REAL_DEVICE_QA_MATRIX.md` and keep screenshots/videos/log excerpts redacted.

Never place a real emergency call unless the release owner has a controlled, written emergency-call test plan. Prefer test-safe numbers for device validation.

| Gate | Area | Steps | Expected | Status | Evidence file |
| --- | --- | --- | --- | --- | --- |
| NEEDS_REAL_DEVICE_TEST | App launch | Install signed Play/internal test build and open the app | App reaches consent/onboarding/unlock or home without crash | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Consent/onboarding | Complete required legal consent and onboarding | App records local consent and enters main navigation | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Empty emergency target validation | Configure no emergency contact or an empty target in a controlled setup, start SOS/test flow without real call | Empty target is blocked/fails visibly and never falls back to `112`; app remains user-initiated and honest about manual confirmation | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Emergency permission granted | Grant `CALL_PHONE`, use test-safe number, start countdown | Direct-call path is attempted only after explicit countdown/user action | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Emergency permission denied | Deny `CALL_PHONE`, use test-safe number, start countdown | ACTION_DIAL opens and copy says the user must press the call button manually | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Emergency permanently denied | Permanently deny phone permission in Android settings, start countdown | App shows settings/manual dial path and does not silently fail | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | No SIM / airplane mode | Enable no-SIM or airplane-mode test state and start SOS with test-safe number | App shows dialer/manual/failure path visibly; no crash | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Notification allowed | Allow notifications, start Safe Walk or Check-In, background app | Persistent safety-session notification is visible and names the active session | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Notification denied | Deny notifications, start Safe Walk or Check-In | App explains reduced timer reliability/visibility and does not crash | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Session cancellation | Start Safe Walk or Check-In, then cancel/check in | Native exact/inexact schedules are cancelled and the status notification clears | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Exact alarm allowed | Grant exact alarm access, start Safe Walk, Check-In, countdown backup | No degraded exact-alarm warning; scheduling succeeds | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Exact alarm denied | Deny exact alarm access, then try Check-In, Safe Walk, scheduled fake call, and Panic | Long-running/scheduled sessions are not armed; Panic is foreground/manual-dial only with no background promise; no crash | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Boot restore | Start active timer, reboot, reopen app | Timer restores or expired state is surfaced honestly | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Contacts picker select/cancel | Select a test contact, then repeat and cancel picker | Only selected contact is stored; cancel stores nothing; no READ_CONTACTS prompt | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Manual contact entry | Add a test contact manually | Contact saves locally and can be selected as emergency contact | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Location allowed/denied | Test map with location permission allowed and denied | Allowed shows location; denied shows clear fallback/no fake coordinates | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Offline map/network failure | Disable network or block tile provider and open map | Offline fallback is clear and does not crash | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | OSM attribution | Open every map surface while online | OpenStreetMap attribution is visible | NOT_RUN | TBD |
| REVENUECAT | Paywall no-offering | Use controlled no-offering dashboard/build state and open paywall | Fallback/retry UI appears; no crash | NOT_RUN | TBD |
| REVENUECAT | Billing purchase | With Play license tester and internal/closed build, buy monthly and annual plans | Pro entitlement activates | NOT_RUN | TBD |
| REVENUECAT | Billing restore | Reinstall/clear data and tap restore | Active purchase restores, or no-purchase state is explicit | NOT_RUN | TBD |
| REVENUECAT | Billing cancel/manage | Open customer center/manage subscription | Google Play/RevenueCat manage path opens safely | NOT_RUN | TBD |
| REVENUECAT | Billing expired/lapsed | Let sandbox subscription expire/lapse and refresh app | Pro access is removed and paywall/no-entitlement copy is shown | NOT_RUN | TBD |
| NEEDS_REAL_DEVICE_TEST | Power user (long path) | Drive the whole journey in one session, in order: arm a safety session -> cancel it -> record a rehearsal -> export local data -> revoke one consent -> re-consent. Do not restart the app between steps. | Every step's record survives the steps after it: the timeline still shows BOTH the arm and the cancel, the rehearsal timestamp is unchanged, the export contains the consent log, and after re-consent a fresh app launch still reads the consent as granted. No step erases an earlier one. | NOT_RUN | TBD |
| NEEDS_OPERATOR_ACTION | Legal URLs | Open privacy, terms, data deletion, and aydınlatma URLs | Live pages load expected content; date/URL evidence saved | NOT_RUN | TBD |

The **Power user (long path)** row is also driven automatically by
`test/core/services/power_user_path_test.dart`, which runs on every release.
The manual row remains because a human notices things a test does not — but the
path itself is no longer answered only once and then left to rot (MP-47-003).

Keep final evidence filenames in the QA matrix. Do not store screenshots containing real phone numbers, real precise locations, account emails, or purchase IDs in the repo.
