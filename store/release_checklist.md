# KoruBeni Release Checklist

Status vocabulary:

- CODE_DONE: completed entirely in repo with code, docs, and host-side tests.
- OPERATOR_ACTION: requires Play Console, RevenueCat, GitHub secrets, keystore, signed AAB upload, tester account, or other manual dashboard action.
- NEEDS_REAL_DEVICE_TEST: requires physical Android hardware.
- NOT_TESTED_RUNTIME: not tested because emulator, adb, installs, device execution, and live billing flows are forbidden in this audit.
- DO_NOT_CLAIM_READY: do not call production-ready without evidence for every production gate.

## Current Verdict

| Gate | Status | Evidence / blocker |
| --- | --- | --- |
| Code-side release fixes | CODE_DONE when final `flutter analyze`, `flutter test`, `dart format`, and static scans pass | See `store/release_audit_note.md` and final verification output. |
| Internal testing upload | OPERATOR_ACTION | Not ready until operator produces signed AAB, creates/uses Play internal or closed track, prepares required app content forms, and confirms RevenueCat/Play subscription setup is ready for testing. |
| Production submission | DO_NOT_CLAIM_READY | Not ready until Play Console forms, billing license-tester matrix, real-device QA, screenshot PII review, and closed testing if required are complete with evidence. |

No Play Console dashboard task, RevenueCat dashboard task, billing purchase test, signed AAB upload, or real-device QA is marked done in this repo.

## Versioning And Build Readiness

| Item | Status | Notes |
| --- | --- | --- |
| Build number increased for each store upload | OPERATOR_ACTION | Use `scripts/bump_version.sh` before operator build/upload. |
| Production AAB command prepared | CODE_DONE | `flutter build appbundle --release --flavor play --dart-define=ENV=production --dart-define=REVENUECAT_ANDROID_API_KEY=... --dart-define=ENCRYPTION_KEY=...` |
| Production AAB output path documented | CODE_DONE | `build/app/outputs/bundle/playRelease/app-play-release.aab` |
| Signed AAB produced | OPERATOR_ACTION | Operator must build with real signing config and secrets. |
| Keystore/secrets committed | CODE_DONE | No secret should be committed; `android/key.properties.example` remains placeholder-only. |

## Store Assets

| Item | Status | Notes |
| --- | --- | --- |
| Store listings source of truth | CODE_DONE | TR/EN short descriptions are in `store/play_store_listing_tr.md`, `store/play_store_listing_en.md`, and `store/PLAY_CONSOLE_COPY_PASTE_PACK.md`. |
| TR short description | CODE_DONE | `Panik/SOS Pro; konum, sahte çağrı ve siren ücretsiz.` |
| EN short description | CODE_DONE | `Panic/SOS requires Pro; location, fake call, and siren are free.` |
| Play store icon | OPERATOR_ACTION | Must be 512x512 PNG. Candidate asset: `store/assets/play_icon_512.png`; verify in Play Console. |
| Feature graphic | OPERATOR_ACTION | Prepare or verify 1024x500 feature graphic in Play Console. |
| Screenshots canonical upload path | OPERATOR_ACTION | Use `store/screenshots/android/final/`; see `store/screenshots/README.md`. |
| Screenshot PII review | OPERATOR_ACTION | Must confirm no real names, phone numbers, emails, addresses, sensitive coordinates, private account data, or accidental profile info. |

## Play Console Forms And Declarations

| Item | Status | Notes |
| --- | --- | --- |
| Data Safety prepared | CODE_DONE | See `store/DATA_SAFETY_FORM.md`; submit in Play Console is OPERATOR_ACTION. |
| Content Rating prepared | CODE_DONE | See `store/CONTENT_RATING_ANSWERS.md`; submit/certificate is OPERATOR_ACTION. |
| Target Audience prepared | CODE_DONE | Intended for adults / 18+; do not enter Designed for Families unless product decision changes. |
| Privacy URL prepared | CODE_DONE | `https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html`; operator must verify live URL. |
| Data deletion URL prepared | CODE_DONE | `https://poyrazoncel34-netizen.github.io/guvenlik_app/data_deletion.html`; operator must verify live URL. |
| Foreground service specialUse declaration prepared | CODE_DONE | Active user-started safety sessions only; visible persistent notification; no hidden tracking. |
| Exact alarm declaration prepared | CODE_DONE | User-visible safety deadlines/timers with denied/fallback/degraded behavior. |
| Battery optimization declaration prepared | CODE_DONE | Reliability enhancement; user can decline; OEM/Android settings may still affect behavior. |
| CALL_PHONE reviewer note prepared | CODE_DONE | User-initiated Panic/SOS flow with countdown/confirmation and `ACTION_DIAL` fallback. |
| FLAG_SECURE reviewer note prepared | CODE_DONE | Screenshots are blocked for safety/privacy; reviewer can still navigate app. |

## RevenueCat / Google Play Billing

Canonical checklist: `store/BILLING_RELEASE_CHECKLIST.md`.

All external billing items are OPERATOR_ACTION until evidence exists:

- Play monthly subscription product.
- Play annual subscription product.
- RevenueCat Android app configured for `com.poyrazoncel.korubeni`.
- RevenueCat entitlement exactly `KoruBeni Pro`.
- Current offering with monthly and annual packages.
- Paywall product loading.
- Monthly/annual purchase tests with license tester.
- Restore, cancel/manage, expired/lapsed/paused behavior if available.
- No-offering and network-failure fallbacks.
- Production RevenueCat key present for release build, with no dummy/CI key.

Code-side fail-safe remains required: release builds must fail if `REVENUECAT_ANDROID_API_KEY` or `ENCRYPTION_KEY` is missing, and no secret may be committed.

## Real-Device QA

Canonical matrix: `store/REAL_DEVICE_QA_MATRIX.md`.

Minimum required evidence before production:

- Android 13 physical device: required rows PASS.
- Android 14 physical device: required rows PASS.
- Android 15 physical device: optional but recommended.
- Aggressive OEM battery device such as Samsung/Xiaomi/Oppo: optional but recommended.

Emulator, adb, `flutter run`, install, Play Billing runtime purchase flow, and device execution are not accepted as substitute evidence for this audit.

## Internal Testing Upload Gate

Internal testing upload may be marked ready only when:

- CODE_DONE fixes are complete.
- `flutter analyze --no-fatal-infos` passes.
- `flutter test --reporter=compact` passes.
- Signed AAB is produced by operator.
- Play Console internal/closed track exists.
- Required app content forms are at least prepared.
- RevenueCat/Play subscription setup is ready for testing.

## Production Submission Gate

Production submission may be marked ready only when:

- Signed AAB uploaded.
- Data Safety submitted.
- Content Rating submitted.
- Target Audience submitted.
- Privacy URL submitted.
- Data deletion URL submitted if applicable.
- Foreground service declaration submitted.
- Exact alarm declaration submitted if required.
- Battery optimization declaration submitted if required.
- Billing license-tester matrix passed.
- Real-device QA matrix passed on Android 13 and Android 14.
- Closed testing with 12 testers for 14 continuous days completed if the developer account requires it.
- Screenshots reviewed for PII.
- Final store listing reviewed for overclaims.

Until those have external evidence: Production submission is NOT READY.
