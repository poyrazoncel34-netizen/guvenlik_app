# Google Play Console Checklist

This checklist prepares operator actions only. No dashboard item is marked done by repo work.

## Required Operator Actions

| Area | Action | Status |
| --- | --- | --- |
| Privacy policy | Verify live URL and paste into Play Console | OPERATOR_ACTION |
| Data deletion URL | Verify live URL and paste if applicable | OPERATOR_ACTION |
| Data Safety | Submit answers from `store/DATA_SAFETY_FORM.md` | OPERATOR_ACTION |
| Content Rating | Complete questionnaire from `store/CONTENT_RATING_ANSWERS.md` | OPERATOR_ACTION |
| Target Audience | Select adult / 18+ intended audience; do not choose Designed for Families | OPERATOR_ACTION |
| Foreground service | Submit `specialUse` declaration for Android 14+ target requirements | OPERATOR_ACTION |
| Exact alarm | Submit declaration if Play Console requires it | OPERATOR_ACTION |
| Battery optimization | Submit declaration if Play Console requires it | OPERATOR_ACTION |
| CALL_PHONE | Submit declaration/reviewer note if requested | OPERATOR_ACTION |
| App Access | Submit reviewer-access instructions: no login required for basic features; Pro features need a Play Console license tester account. Use copy from `docs/play_console_declarations.md` (App Access / Reviewer Notes). Operator supplies actual license tester email(s). | OPERATOR_ACTION |
| Store listing | Paste TR/EN copy from `store/PLAY_CONSOLE_COPY_PASTE_PACK.md` | OPERATOR_ACTION |
| Store icon | Upload/verify 512x512 PNG | OPERATOR_ACTION |
| Feature graphic | Prepare/verify 1024x500 feature graphic | OPERATOR_ACTION |
| Screenshots | Upload from `store/screenshots/android/final/` after PII review | OPERATOR_ACTION |
| Signed AAB | Operator builds signed Play release AAB and uploads to internal/closed track | OPERATOR_ACTION |
| Billing | Configure Play subscriptions and RevenueCat; see `store/BILLING_RELEASE_CHECKLIST.md` | OPERATOR_ACTION |
| Real-device QA | Execute `store/REAL_DEVICE_QA_MATRIX.md` on physical devices | NEEDS_REAL_DEVICE_TEST |

## Build Artifact Reference

Production build command must use Play flavor, production env, and operator-supplied secrets:

```text
flutter build appbundle --release --flavor play --dart-define=ENV=production --dart-define=REVENUECAT_ANDROID_API_KEY=... --dart-define=ENCRYPTION_KEY=...
```

Expected AAB path:

```text
build/app/outputs/bundle/playRelease/app-play-release.aab
```

## Data Safety Notes

- Do not claim local-only data is collected/shared merely because it is stored on device.
- Disclose Google Play Billing and RevenueCat for optional Pro subscription processing.
- Disclose map tile provider behavior for online maps.
- No analytics, ads, crash SDK, auth backend, cloud database, SMS sending, microphone, or audio recording should be claimed unless the final build changes.

## Reviewer Notes To Prepare

- Panic/SOS is Pro-only.
- Basic access has no login.
- `FLAG_SECURE` blocks screenshots for safety/privacy; reviewers can still navigate the app.
- CALL_PHONE is user-initiated through Panic/SOS with confirmation/countdown and `ACTION_DIAL` fallback.
- Foreground service is only for active user-started safety sessions with visible persistent notification and no hidden tracking.
- Exact alarm denial has fallback/degraded behavior; no guarantee language.

## AAB Upload Gate

Internal testing upload is NOT READY until:

- Signed AAB is produced by operator.
- Play internal/closed testing track exists.
- Required app content forms are prepared.
- RevenueCat/Play subscription setup is ready for testing.

Production submission is NOT READY until all production gates in `store/release_checklist.md` are evidenced.
