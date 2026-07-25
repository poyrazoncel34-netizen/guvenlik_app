# Play Console Declarations

Do not mark any Play Console declaration submitted from this repo. Copy/paste text is prepared here; dashboard completion is PLAY_CONSOLE / NEEDS_OPERATOR_ACTION.

## `USE_FULL_SCREEN_INTENT` — NOT DECLARED

Status: NOT_APPLICABLE in the current Play build. KoruBeni is not an alarm-clock
app and does not receive phone or video calls. Its fake-call feature is an
on-device simulation, so it must not be represented to Play as incoming-call
functionality. The app also has no dedicated in-app explanation and explicit
consent flow for this special access.

The manifest therefore does not request `USE_FULL_SCREEN_INTENT`, and urgent
safety events use a HIGH-importance heads-up notification. Remove any stale FSI
declaration from Play Console. If the product later adds a compliant consent
flow, policy and physical lock-screen testing must be repeated before restoring
the permission.

## Foreground service declaration — NOT APPLICABLE

Status: CODE_DONE. The Play build no longer declares or starts an Android
foreground service. `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, the
`specialUse` subtype property, and `flutter_background_service` were removed.

The visible notification shown during a user-started safety session is an
ordinary local status notification. It is not a foreground-service notification
and must not be described to Play as a process keepalive or timing guarantee.
Safety timing is owned by native `AlarmManager` scheduling instead:

- exact `setExactAndAllowWhileIdle` when exact-alarm access is available;
- an independently cancellable `setAndAllowWhileIdle` post-arm revocation backup;
- persisted deadline state restored by `BOOT_COMPLETED`;
- exact schedules restored after exact-alarm access is granted again.

Play Console action: do not submit a `specialUse` declaration or FGS demo for
this build. If an older draft declaration exists in Console, remove it before
submission. A release-bundle manifest inspection must confirm that no custom or
transitive foreground-service entry has returned.

## `SCHEDULE_EXACT_ALARM`

Status: CODE_DONE copy prepared; PLAY_CONSOLE to submit if Play Console requires it.

Declaration text:

```text
KoruBeni uses exact alarms for user-started safety timers such as Check-In, Safe Walk expiry, and emergency countdown backup. These timers are safety-critical because delayed execution may prevent timely emergency escalation. If exact alarm access is not granted, Check-In, Safe Walk, and scheduled fake-call sessions are not armed; Panic is limited to a visible foreground countdown and manual dial path without a background guarantee.
```

Denied/fallback note:

```text
The independently keyed inexact alarm is a backup only after exact scheduling has succeeded, so a later revocation does not silently erase every schedule. It is not used to mislabel an exact-denied long-running session as armed.
```

## `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

Status: CODE_DONE copy prepared; PLAY_CONSOLE to submit if Play Console requires it.

Declaration text:

```text
KoruBeni requests battery optimization exemption only as an optional reliability improvement for active user-started safety sessions such as Safe Walk and check-in. Android and OEM battery settings may still affect behavior. The user can decline, and the app explains that timer/background reliability may be degraded.
```

## `CALL_PHONE`

Status: CODE_DONE copy prepared; PLAY_CONSOLE to submit if Play Console requires it.

Reviewer note:

```text
KoruBeni is a personal safety app. CALL_PHONE is used only for a Panic/SOS, Check-In, or Safe Walk safety session that the user explicitly arms. When a countdown or long-session deadline expires, Android may submit an unconfirmed call request to the system Telecom service for the user's immutable pre-selected primary contact. The app never synthesizes 112/911 or another official short code and never claims that a call rang or connected. If automatic submission cannot be used, an actionable notification provides a user-tapped ACTION_DIAL path. The app does not read call logs.
```

## `FLAG_SECURE`

Status: NOT DECLARED (no Console form exists for it); reviewer copy must
describe the actual behaviour.

```text
KoruBeni sets Android FLAG_SECURE on its window in release builds, so screenshots, screen recording and the recent-apps thumbnail are blocked throughout the app. This is a duress-model control: the app holds a local safety PIN and emergency contact numbers, and screen-capturing software is the realistic way both leave the device. The in-app privacy mask remains as a defence in depth. Debug builds do not set the flag, which is how store screenshots are produced.
```

Reviewer note: a reviewer recording their screen will capture a black frame.
That is the intended behaviour, not a rendering defect.

## Target Audience

Status: CODE_DONE recommendation prepared; PLAY_CONSOLE to submit.

```text
KoruBeni is intended for adults / 18+ users. Do not enter Designed for Families unless the product decision, copy, legal basis, and child-safety review explicitly change.
```

## Health Apps Declaration

Status: CODE_DONE answer prepared; PLAY_CONSOLE submission is still required.

```text
The uploaded build does not provide a health feature, medical diagnosis,
health measurement, treatment, or Health Connect integration. Select “No
health features” for the Health Apps Declaration. Re-evaluate from the exact
AAB if the product scope changes.
```

## Data Safety Summary

Status: CODE_DONE copy prepared; PLAY_CONSOLE to submit.

KoruBeni does not operate a developer backend. Local-only data such as emergency contacts, display name, optional user-selected fake-call avatar images, PIN, local activity history, fake-call settings, and consent records stays on device unless the user uses Android/Google/third-party system flows.

The app does not read the full contacts list. It stores only emergency contacts selected or entered by the user, locally on the device.

Be accurate and conservative in Play Console:

- Do not claim local-only data is developer-collected or shared merely because it is stored on device.
- Mention Google Play Billing and RevenueCat subscription processing for optional Pro entitlement verification.
- Mention online map tile requests to the configured map provider, currently OpenStreetMap tile infrastructure, when maps are disclosed.
- Map screens request only user-viewed online tiles. For the default public OSM endpoint, an app-private 128 MiB cache honors provider HTTP cache directives and uses a seven-day lifetime only when no usable directive exists. The app must not bulk download, scrape, pre-seed, create offline packs, or package public OSM tiles. A configured alternative provider requires its own contract/cache evidence.
- No ads, Firebase Analytics, Crashlytics, Sentry, auth backend, cloud database, UGC, SMS sending, microphone, or audio recording is used in this release based on current repo checks.
- Do not mark blanket encryption-in-transit for all local-only data. Provider-controlled flows such as map tiles, Google Play Billing, and RevenueCat have their own transport/security behavior.

## App Access / Reviewer Notes

Panic/SOS is a KoruBeni Pro feature.

The free plan includes basic app access, immediate fake call, siren, emergency contact management, basic display name, map/location view where permission is granted, and legal/settings access.

Reviewer path:

```text
Home -> locked Pro Panic/SOS button -> Paywall/test purchase -> Pro entitlement active -> Home -> Panic/SOS button -> long press -> emergency countdown.
```

Testing instructions:

```text
Use a Google Play license tester account or internal/closed test track account.
Install the Play internal/closed testing build.
Open the paywall from the locked Panic/SOS button or Settings -> KoruBeni Pro.
Complete sandbox/test purchase for the configured monthly or annual plan.
Return to Home and verify the Panic/SOS button shows active Pro copy before long press.
```

Manual fields still needed:

- Final public privacy policy URL verification.
- Final public data deletion URL verification.
- Final Play subscription product IDs and RevenueCat offering identifiers.
- Reviewer test account/license tester notes required by the active Play test track.
- Signed AAB provenance.

## Sensitive Permissions / No Account Copy

Status: CODE_DONE copy prepared; PLAY_CONSOLE / NEEDS_OPERATOR_ACTION to submit or verify.

Sensitive permissions:

```text
KoruBeni requests only permissions needed for user-facing safety features: location for map/location sessions, CALL_PHONE for user-started SOS direct-call attempts with ACTION_DIAL fallback, POST_NOTIFICATIONS for visible timer/session alerts, SCHEDULE_EXACT_ALARM for user-started safety timers with fail-closed arming, and Google Play Billing for optional Pro subscriptions. It does not request an Android foreground-service permission.
```

No READ_CONTACTS:

```text
KoruBeni does not request broad READ_CONTACTS access. Emergency contacts are selected through the system picker or entered manually, and only the selected/entered emergency contact data is stored locally on the device.
```

No account:

```text
KoruBeni does not create developer-operated user accounts and has no auth backend in this release. Local app data can be removed by deleting app data/uninstalling the app. Google Play subscription cancellation is managed separately through Google Play.
```

OSM map tile disclosure:

```text
Online map screens may request OpenStreetMap/configured-provider tiles only for map areas the user actively views. The default public OSM endpoint uses an app-private bounded persistent cache that honors HTTP cache directives and falls back to a seven-day lifetime when no usable directive is supplied. KoruBeni does not bulk download, scrape, pre-seed, package, or generate offline tile packs. A configured alternative provider must have its own candidate-bound contract, cache, and network-capture evidence.
```
