# Google Play Permissions Declaration Notes

Dashboard completion is PLAY_CONSOLE / NEEDS_OPERATOR_ACTION. This file only prepares copy/paste text.

## Declaration Summary

| Permission / App content item | Manifest / app use | Status |
| --- | --- | --- |
| Foreground service | Not declared or started in the Play build | NOT_APPLICABLE; verify uploaded AAB and remove stale Console draft |
| `SCHEDULE_EXACT_ALARM` | User-visible safety deadlines/timers | CODE_DONE copy prepared; PLAY_CONSOLE submit if required |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Optional reliability improvement for active safety sessions | CODE_DONE copy prepared; PLAY_CONSOLE submit if required |
| `CALL_PHONE` | User-initiated Panic/SOS call flow after confirmation/countdown | CODE_DONE copy prepared; PLAY_CONSOLE submit if required |
| `USE_FULL_SCREEN_INTENT` | Not requested; urgent events use heads-up notifications | NOT_APPLICABLE; remove stale Console declaration |
| `POST_NOTIFICATIONS` | User-visible safety notifications/reminders | CODE_DONE copy prepared |
| Message/SMS permissions | Not present in this Android Play release | CODE_DONE |
| `READ_PHONE_STATE` | Not present; fake call is an on-device simulation | CODE_DONE |
| `ACCESS_BACKGROUND_LOCATION` | Not present | CODE_DONE |

## Foreground Service — NOT APPLICABLE

The Play build does not request `FOREGROUND_SERVICE` or
`FOREGROUND_SERVICE_SPECIAL_USE` and does not declare/start a custom foreground
service. The session notification is ordinary status UI. Do not submit the old
`specialUse` copy; remove any stale Console draft and confirm the uploaded AAB
manifest has no transitive FGS entry. See
[docs/play_console_declarations.md](../docs/play_console_declarations.md).

## `USE_FULL_SCREEN_INTENT` — NOT APPLICABLE

The current Play manifest does not request this special access. KoruBeni is not
an alarm-clock or incoming phone/video-call app, and the simulated fake-call
feature must not be presented as a real calling-app use case. Urgent events use
a HIGH-importance heads-up notification. Remove any stale FSI declaration from
Play Console rather than submitting the former justification.

## `SCHEDULE_EXACT_ALARM`

```text
KoruBeni uses exact alarms for user-visible safety deadlines and timers, including Panic/SOS countdown backup, check-in expiry, grace periods, and Safe Walk timers. Delay can affect the expected safety behavior of these user-started flows. The app is not using exact alarms for ads, analytics, marketing, hidden tracking, or arbitrary background work.
```

Fallback:

```text
If exact alarm access is denied or unavailable, Check-In, Safe Walk, and scheduled fake-call sessions are not armed. Panic may continue only as a visible foreground countdown ending in `ACTION_DIAL`; no background guarantee is made. The independently keyed inexact alarm is created only after exact scheduling succeeds, as a residual backup for a later revocation.
```

## `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

```text
KoruBeni requests battery optimization exemption only as an optional reliability improvement for active user-started safety sessions such as Safe Walk and check-in. Android and OEM battery settings may still affect behavior. The user can decline, and the app explains that timer/background reliability may be degraded.
```

## `CALL_PHONE`

Category: Safety / Emergency

```text
CALL_PHONE is limited to user-armed Panic/SOS, Check-In, and Safe Walk expiry. Android may submit an unconfirmed Telecom request for the immutable pre-selected contact; the app never claims ringing or connection. If automatic submission cannot be used, an actionable notification exposes a user-tapped ACTION_DIAL path. KoruBeni has no official 112/police integration and never generates official short codes.
```

## `POST_NOTIFICATIONS`

```text
Notifications are used for visible safety timer/session reliability and reminders in user-started flows. They are not used for ads, marketing, analytics, hidden tracking, silent surveillance, or indefinite background execution. If notifications or the high-importance alert channel are unavailable, long-running safety sessions are not armed; the denial is surfaced without a crash.
```

## `FLAG_SECURE` Reviewer Note

```text
KoruBeni does not set Android FLAG_SECURE globally. Screenshots remain possible. The app uses an in-app privacy mask only for its background/recent-apps preview.
```

## Video / Manual Demo Notes

No SMS permission demo is needed because SMS sending and SMS composer flows are not in this Play release.

If Play review requests a demo, record on a physical test device:

1. First launch and legal/PIN setup.
2. Emergency contact add flow and KVKK contact notice.
3. Panic/SOS Pro flow with confirmation/countdown and `ACTION_DIAL` fallback if direct call is denied.
4. Safe Walk/check-in start and degraded reliability messaging.
5. Settings -> data export and data deletion.

Do not claim Play Console, RevenueCat, purchase, or real-device PASS status without operator evidence.
