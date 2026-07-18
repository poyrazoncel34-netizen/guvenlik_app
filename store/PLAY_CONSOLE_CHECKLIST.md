# Google Play Console Checklist

This checklist prepares operator actions only. No dashboard item is marked done by repo work.

## Required Operator Actions

| Area | Action | Status |
| --- | --- | --- |
| Privacy policy | Verify live URL and paste into Play Console | NEEDS_OPERATOR_ACTION |
| Data deletion URL | Verify live URL and paste if applicable | NEEDS_OPERATOR_ACTION |
| Data Safety | Verify Play Console track requirements; internal testing may be exempt, closed/open/production require submission from `store/DATA_SAFETY_FORM.md` | PLAY_CONSOLE |
| Content Rating | Complete questionnaire from `store/CONTENT_RATING_ANSWERS.md` | PLAY_CONSOLE |
| Target Audience | Select adult / 18+ intended audience; do not choose Designed for Families | PLAY_CONSOLE |
| Foreground service | Do not submit `specialUse`; verify uploaded AAB has no FGS permission/service and remove any stale draft | NEEDS_OPERATOR_ACTION |
| Exact alarm | Submit declaration if Play Console requires it | PLAY_CONSOLE |
| Battery optimization | Submit declaration if Play Console requires it | PLAY_CONSOLE |
| CALL_PHONE | Submit declaration/reviewer note if requested | PLAY_CONSOLE |
| App Access | Submit reviewer-access instructions: no login required for basic features; Pro features need a Play Console license tester account. Use copy from `docs/play_console_declarations.md` (App Access / Reviewer Notes). Operator supplies actual license tester email(s). | PLAY_CONSOLE |
| Store listing | Paste Turkish-only first-release copy from `store/PLAY_CONSOLE_COPY_PASTE_PACK.md`; do not add an English Play listing for this release | PLAY_CONSOLE |
| Store icon | Upload/verify 512x512 PNG | NEEDS_OPERATOR_ACTION |
| Feature graphic | Prepare/verify 1024x500 feature graphic | NEEDS_OPERATOR_ACTION |
| Screenshots | Upload from `store/screenshots/android/final/` after PII review | NEEDS_OPERATOR_ACTION |
| Signed AAB | Operator builds signed Play release AAB and uploads to internal/closed track | SIGNING |
| Billing | Configure Play subscriptions and RevenueCat; see `store/BILLING_RELEASE_CHECKLIST.md` | REVENUECAT |
| Real-device QA | Execute `store/REAL_DEVICE_QA_MATRIX.md` on physical devices | NEEDS_REAL_DEVICE_TEST |

## Build Artifact Reference

Production build command must use Play flavor, production env, release signing, and the RevenueCat `goog_` Android public SDK key (`test_`/`sk_` keys are forbidden):

```text
flutter build appbundle --release --flavor play --target-platform android-arm64 --dart-define=ENV=production --dart-define=REVENUECAT_ANDROID_API_KEY=...
```

Expected AAB path:

```text
build/app/outputs/bundle/playRelease/app-play-release.aab
```

## Data Safety Notes

- Internal testing may be exempt from the Data Safety section depending on Play Console state, but closed/open/production testing and production require the form when presented by Play.
- Legal/privacy docs must still be consistent before internal testing.
- Do not claim local-only data is collected/shared merely because it is stored on device.
- Disclose Google Play Billing and RevenueCat for optional Pro subscription processing.
- Disclose map tile provider behavior for online maps.
- No analytics, ads, crash SDK, auth backend, cloud database, SMS sending, microphone, or audio recording should be claimed unless the final build changes.

## Reviewer Notes To Prepare

- Panic/SOS is Pro-only.
- Basic access has no login.
- Global `FLAG_SECURE` is not declared; screenshots remain possible. An in-app privacy mask covers the recent-apps preview while backgrounded.
- CALL_PHONE is limited to user-armed Panic/SOS, Check-In, and Safe Walk expiry; the result is an unconfirmed Telecom request, with a user-tapped `ACTION_DIAL` fallback notification.
- The build does not use an Android foreground service. Safety-session notifications are status UI; native alarms own deadlines.
- Exact alarm denial blocks long-running/scheduled arming; Panic is foreground/manual-dial only and makes no background guarantee.

## AAB Upload Gate

Internal testing upload is NOT READY until:

- Signed AAB is produced by operator.
- Play internal/closed testing track exists.
- Required app content forms are prepared; Data Safety may remain submit-pending for internal testing only if Play Console does not require it for that track.
- RevenueCat/Play subscription setup is ready for testing.

Production submission is NOT READY until all production gates in `store/release_checklist.md` are evidenced.
