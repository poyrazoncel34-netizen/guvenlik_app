# Google Play Permissions Declaration Notes

Dashboard completion is PLAY_CONSOLE / NEEDS_OPERATOR_ACTION. This file only prepares copy/paste text.

## Declaration Summary

| Permission / App content item | Manifest / app use | Status |
| --- | --- | --- |
| Foreground service `specialUse` | Active user-started safety sessions with visible notification | CODE_DONE copy prepared; PLAY_CONSOLE submit |
| `SCHEDULE_EXACT_ALARM` | User-visible safety deadlines/timers | CODE_DONE copy prepared; PLAY_CONSOLE submit if required |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Optional reliability improvement for active safety sessions | CODE_DONE copy prepared; PLAY_CONSOLE submit if required |
| `CALL_PHONE` | User-initiated Panic/SOS call flow after confirmation/countdown | CODE_DONE copy prepared; PLAY_CONSOLE submit if required |
| `USE_FULL_SCREEN_INTENT` | Fake-call ring screen + emergency countdown alerts over lock screen | CODE_DONE (declared 2026-07-06); PLAY_CONSOLE submit if required |
| `POST_NOTIFICATIONS` | User-visible safety notifications/reminders | CODE_DONE copy prepared |
| Message/SMS permissions | Not present in this Android Play release | CODE_DONE |
| `READ_PHONE_STATE` | Not present; fake call is an on-device simulation | CODE_DONE |
| `ACCESS_BACKGROUND_LOCATION` | Not present | CODE_DONE |

## Foreground Service `specialUse`

```text
KoruBeni uses a foreground service only for active, user-started safety sessions such as Safe Walk, check-in, and emergency timer reliability. The session shows a visible persistent notification and is tied to the user's active safety flow. The user can stop or cancel the session. The service is not used for ads, analytics, hidden tracking, silent background surveillance, or indefinite background execution.
```

Subtype is declared in `AndroidManifest.xml` as `emergency_checkin_keepalive` via the `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property on the service entry.

For the full type-selection rationale (why `specialUse` over `location`, `dataSync`, `shortService`, etc.) and the Android 15 boot-restriction context, see [docs/play_console_declarations.md](../docs/play_console_declarations.md).

## `USE_FULL_SCREEN_INTENT`

Declared 2026-07-06. Core-functionality justification: the fake-call feature must
present a realistic incoming-call screen over the lock screen (personal-safety
exit scenario), and emergency countdown alerts must be visible when the device is
locked. The app never crashes on denial: `EmergencyNotificationHelper` checks
`NotificationManager.canUseFullScreenIntent()` and degrades to a high-priority
heads-up notification (Android 14+ may withhold the grant for non call/alarm
apps; the user can enable it in system settings). If Play Console presents an
FSI declaration form, answer with this justification.

## `SCHEDULE_EXACT_ALARM`

```text
KoruBeni uses exact alarms for user-visible safety deadlines and timers, including Panic/SOS countdown backup, check-in expiry, grace periods, and Safe Walk timers. Delay can affect the expected safety behavior of these user-started flows. The app is not using exact alarms for ads, analytics, marketing, hidden tracking, or arbitrary background work.
```

Fallback:

```text
If exact alarm access is denied or unavailable, the app falls back where possible to inexact alarms, foreground-service/session state, and local timer paths. The app presents degraded reliability messaging and does not guarantee that Android/OEM background behavior cannot delay timers.
```

## `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

```text
KoruBeni requests battery optimization exemption only as an optional reliability improvement for active user-started safety sessions such as Safe Walk and check-in. Android and OEM battery settings may still affect behavior. The user can decline, and the app explains that timer/background reliability may be degraded.
```

## `CALL_PHONE`

Category: Safety / Emergency

```text
CALL_PHONE is used only in the user-initiated Panic/SOS flow. The user explicitly starts the flow and sees a confirmation/countdown before any call attempt. If direct calling is denied, unavailable, or unsafe to use, the app falls back to ACTION_DIAL so the user can manually place the call. KoruBeni does not claim official 112/police integration and does not place hidden background calls.
```

## `POST_NOTIFICATIONS`

```text
Notifications are used for visible safety timer/session reliability and reminders in user-started flows. They are not used for ads, marketing, analytics, hidden tracking, silent surveillance, or indefinite background execution. The user can deny notification permission and the app must show degraded behavior where relevant.
```

## `FLAG_SECURE` Reviewer Note

```text
KoruBeni blocks screenshots in the app with FLAG_SECURE for user safety and privacy. Reviewers can still navigate the app normally. Use the provided store screenshots and reviewer instructions for visual review evidence.
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
