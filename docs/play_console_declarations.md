# Play Console Declarations

Do not mark any Play Console declaration submitted from this repo. Copy/paste text is prepared here; dashboard completion is OPERATOR_ACTION.

## Foreground Service `specialUse`

Status: CODE_DONE copy prepared; OPERATOR_ACTION to submit in Play Console App content.

Declaration text:

```text
KoruBeni uses a foreground service only for active, user-started safety sessions such as Safe Walk, check-in, and emergency timer reliability. The session shows a visible persistent notification and is tied to the user's active safety flow. The user can stop or cancel the session. The service is not used for ads, analytics, hidden tracking, silent background surveillance, or indefinite background execution.
```

Reviewer note:

```text
The app combines user-visible safety timers, check-in deadlines, Safe Walk sessions, and emergency countdown reliability. These do not fit cleanly into a single standard foreground service type. The work starts from user action, remains visible through notification/UI, and stops when the session ends or is cancelled.
```

Android 14+ note: apps targeting Android 14+ must declare foreground service types in Play Console App content.

### Type selection rationale

The service is declared as `foregroundServiceType="specialUse"` because the work it performs does not fit any of the named Android 14 foreground service types cleanly:

- `location` would imply continuous location streaming. The keepalive does not stream location; location is only read on demand by the user-initiated map/SOS flows in the regular activity context.
- `dataSync` is subject to a 6-hour quota on Android 15+ (developer.android.com/about/versions/15/behavior-changes-15) and is not intended for safety-timer reliability.
- `shortService` is capped at ~3 minutes — too short for check-in/Safe Walk sessions that can run for tens of minutes.
- `mediaPlayback`, `mediaProjection`, `camera`, `microphone`, `connectedDevice`, `phoneCall`, `health`, `remoteMessaging` — none describe the actual work (a user-perceptible safety-session timer/keepalive that allows alarm and notification paths to fire reliably).

Per Android docs, `specialUse` is the documented fallback when a foreground service does real, user-perceptible work that does not match the other named types. The service is started only by user action, displays a persistent notification, and ends when the user cancels or the session timer expires.

### Subtype declaration

The manifest declares the special-use subtype as a `<property>` on the service entry, per Android requirements:

```xml
<property
    android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
    android:value="emergency_checkin_keepalive" />
```

The subtype value (`emergency_checkin_keepalive`) describes the use case in human-readable form for Play review.

### Android 15 BOOT_COMPLETED context

Android 15 restricts foreground service start from `BOOT_COMPLETED` for the following types: `dataSync`, `mediaPlayback`, `mediaProjection`, `phoneCall`, `microphone`, and `camera` (developer.android.com/about/versions/15/behavior-changes-15). `specialUse` and `location` are not in that restricted list, so KoruBeni's boot-restore path (re-arming an active check-in/Safe Walk after device reboot) remains supported on Android 15+.

### Reviewer demo

A 30–60 second physical-device recording showing: (1) user starts Safe Walk or check-in from the in-app button, (2) persistent notification with Stop action appears, (3) user taps Stop or session expires, (4) notification clears. Recording must avoid real PII (use test contacts and never dial real 112 — only verify dialer pre-fill).

## `SCHEDULE_EXACT_ALARM`

Status: CODE_DONE copy prepared; OPERATOR_ACTION to submit if Play Console requires it.

Declaration text:

```text
KoruBeni uses exact alarms for user-visible safety deadlines and timers, including Panic/SOS countdown backup, check-in expiry, grace periods, and Safe Walk timers. Delay can affect the expected safety behavior of these user-started flows. The app is not using exact alarms for ads, analytics, marketing, hidden tracking, or arbitrary background work.
```

Denied/fallback note:

```text
If exact alarm access is denied or unavailable, the app falls back where possible to inexact alarms, foreground-service/session state, and local timer paths. The app presents degraded reliability messaging and does not guarantee that Android/OEM background behavior cannot delay timers.
```

## `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

Status: CODE_DONE copy prepared; OPERATOR_ACTION to submit if Play Console requires it.

Declaration text:

```text
KoruBeni requests battery optimization exemption only as an optional reliability improvement for active user-started safety sessions such as Safe Walk and check-in. Android and OEM battery settings may still affect behavior. The user can decline, and the app explains that timer/background reliability may be degraded.
```

## `CALL_PHONE`

Status: CODE_DONE copy prepared; OPERATOR_ACTION to submit if Play Console requires it.

Reviewer note:

```text
CALL_PHONE is used only in the user-initiated Panic/SOS flow. The user explicitly starts the flow and sees a confirmation/countdown before any call attempt. If direct calling is denied, unavailable, or unsafe to use, the app falls back to ACTION_DIAL so the user can manually place the call. KoruBeni does not claim official 112/police integration and does not place hidden background calls.
```

## `FLAG_SECURE`

Status: CODE_DONE copy prepared; OPERATOR_ACTION to include as reviewer note if screenshots or review access are affected.

```text
KoruBeni blocks screenshots in the app with FLAG_SECURE for user safety and privacy. Reviewers can still navigate the app normally. If Play review needs visual evidence, use the provided store screenshots and reviewer instructions rather than expecting OS screenshots from protected screens.
```

## Target Audience

Status: CODE_DONE recommendation prepared; OPERATOR_ACTION to submit.

```text
KoruBeni is intended for adults / 18+ users. Do not enter Designed for Families unless the product decision, copy, legal basis, and child-safety review explicitly change.
```

## Data Safety Summary

Status: CODE_DONE copy prepared; OPERATOR_ACTION to submit.

KoruBeni does not operate a developer backend. Local-only data such as emergency contacts, display name, optional user-selected avatar images, PIN, local activity history, fake-call settings, and consent records stays on device unless the user uses Android/Google/third-party system flows.

Be accurate and conservative in Play Console:

- Do not claim local-only data is developer-collected or shared merely because it is stored on device.
- Mention Google Play Billing and RevenueCat subscription processing for optional Pro entitlement verification.
- Mention online map tile requests to the configured map provider, currently OpenStreetMap tile infrastructure, when maps are disclosed.
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
