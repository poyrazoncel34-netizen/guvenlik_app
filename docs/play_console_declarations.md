# Play Console Declarations

Do not mark any Play Console declaration submitted from this repo. Copy/paste text is prepared here; dashboard completion is PLAY_CONSOLE / NEEDS_OPERATOR_ACTION.

## Foreground Service `specialUse`

Status: CODE_DONE copy prepared; PLAY_CONSOLE to submit in Play Console App content.

Declaration text:

```text
KoruBeni uses a foreground service only for active, user-started safety sessions such as Safe Walk, check-in, and emergency timer reliability. The session shows a visible persistent notification and is tied to the user's active safety flow. The user can stop or cancel the session. The service is not used for ads, analytics, hidden tracking, silent background surveillance, or indefinite background execution.
```

Suggested Play declaration text:

```text
KoruBeni uses a foreground service during active user-started safety sessions such as Safe Walk and Check-In. The service keeps a visible safety timer active and displays a persistent notification. If the timer expires without check-in, the app escalates to the emergency countdown flow. The service is user-visible, time-bound, and can be cancelled by the user.
```

Reviewer note:

```text
The app combines user-visible safety timers, check-in deadlines, Safe Walk sessions, and emergency countdown reliability. These do not fit cleanly into a single standard foreground service type. The work starts from user action, remains visible through notification/UI, and stops when the session ends or is cancelled.
```

Android 14+ note: apps targeting Android 14+ must declare foreground service types in Play Console App content.

## `SCHEDULE_EXACT_ALARM`

Status: CODE_DONE copy prepared; PLAY_CONSOLE to submit if Play Console requires it.

Declaration text:

```text
KoruBeni uses exact alarms for user-started safety timers such as Check-In, Safe Walk expiry, and emergency countdown backup. These timers are safety-critical because delayed execution may prevent timely emergency escalation. If exact alarm access is not granted, the app continues with degraded/inexact scheduling and informs the user that reliability may be reduced.
```

Denied/fallback note:

```text
If exact alarm access is denied or unavailable, the app falls back where possible to inexact alarms, foreground-service/session state, and local timer paths. The app presents degraded reliability messaging and does not guarantee that Android/OEM background behavior cannot delay timers.
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
KoruBeni is a personal safety app. CALL_PHONE is used only when the user explicitly starts an emergency SOS flow and grants phone permission. The app attempts to call the configured emergency number or 112. If CALL_PHONE is denied, unavailable, or direct calling fails, the app falls back to ACTION_DIAL so the user can manually confirm the call. The app does not read call logs and does not place background calls without user action.
```

## `FLAG_SECURE`

Status: CODE_DONE copy prepared; PLAY_CONSOLE to include as reviewer note if screenshots or review access are affected.

```text
KoruBeni blocks screenshots in the app with FLAG_SECURE for user safety and privacy. Reviewers can still navigate the app normally. If Play review needs visual evidence, use the provided store screenshots and reviewer instructions rather than expecting OS screenshots from protected screens.
```

## Target Audience

Status: CODE_DONE recommendation prepared; PLAY_CONSOLE to submit.

```text
KoruBeni is intended for adults / 18+ users. Do not enter Designed for Families unless the product decision, copy, legal basis, and child-safety review explicitly change.
```

## Data Safety Summary

Status: CODE_DONE copy prepared; PLAY_CONSOLE to submit.

KoruBeni does not operate a developer backend. Local-only data such as emergency contacts, display name, optional user-selected fake-call avatar images, PIN, local activity history, fake-call settings, and consent records stays on device unless the user uses Android/Google/third-party system flows.

The app does not read the full contacts list. It stores only emergency contacts selected or entered by the user, locally on the device.

Be accurate and conservative in Play Console:

- Do not claim local-only data is developer-collected or shared merely because it is stored on device.
- Mention Google Play Billing and RevenueCat subscription processing for optional Pro entitlement verification.
- Mention online map tile requests to the configured map provider, currently OpenStreetMap tile infrastructure, when maps are disclosed.
- Map screens request only user-viewed online tiles. The app must not bulk download, scrape, pre-seed, archive, or package OpenStreetMap public tiles; production-scale usage should move to a provider with an appropriate quota/API-key agreement.
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
KoruBeni requests only permissions needed for user-facing safety features: location for map/location sessions, CALL_PHONE for user-started SOS direct-call attempts with ACTION_DIAL fallback, POST_NOTIFICATIONS for visible timer/session alerts, SCHEDULE_EXACT_ALARM for user-started safety timers with degraded fallback, foreground service permissions for visible active safety sessions, and Google Play Billing for optional Pro subscriptions.
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
Online map screens may request OpenStreetMap/configured-provider tiles only for map areas the user actively views. KoruBeni does not bulk download, scrape, pre-seed, archive, package, or generate offline tile packs from public OSM tiles. Production-scale use should move to a proper tile provider with an appropriate quota/API-key agreement.
```
