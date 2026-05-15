# KoruBeni Release Checklist

Status vocabulary:

- CODE_DONE: completed entirely in repo with code, docs, and host-side tests.
- PLAY_CONSOLE: must be completed in Google Play Console with external evidence.
- REVENUECAT: must be completed in RevenueCat and/or Play Billing sandbox with external evidence.
- SIGNING: requires real release signing material and signed artifact provenance.
- NEEDS_OPERATOR_ACTION: requires live URL, store asset, log, screenshot, or dashboard review outside repo.
- NEEDS_OWNER_REVIEW: legal/policy wording needs owner confirmation.
- UNKNOWN: external account/dashboard state is unavailable from repo evidence.
- NEEDS_REAL_DEVICE_TEST: requires physical Android hardware.
- NOT_TESTED_RUNTIME: not tested because emulator, adb, installs, device execution, and live billing flows are forbidden in this audit.
- DO_NOT_CLAIM_READY: do not call production-ready without evidence for every production gate.

## Current Verdict

| Gate | Status | Evidence / blocker |
| --- | --- | --- |
| Code-side release fixes | CODE_DONE when final `flutter analyze`, `flutter test`, `dart format`, and static scans pass | See `store/release_audit_note.md` and final verification output. |
| Internal testing upload | SIGNING / PLAY_CONSOLE / REVENUECAT | Not ready until operator produces signed AAB, creates/uses Play internal or closed track, prepares required app content forms, confirms any Play Console internal-testing Data Safety exemption/submission status, and confirms RevenueCat/Play subscription setup is ready for testing. |
| Production submission | DO_NOT_CLAIM_READY | Not ready until Play Console forms, billing license-tester matrix, real-device QA, screenshot PII review, and closed testing if required are complete with evidence. |

No Play Console dashboard task, RevenueCat dashboard task, billing purchase test, signed AAB upload, or real-device QA is marked done in this repo.

## Final Operator Handoff Matrix

Every row below remains open until the named owner saves the required external evidence. Do not mark any row done from repo-only review.

| Item | Status | Owner | Where to perform | Done criteria | Evidence to save | Gate |
| --- | --- | --- | --- | --- | --- | --- |
| Signed AAB with production secrets | SIGNING | Release operator | Secure local release environment and Play Console track upload | `playRelease` AAB is built with production signing, `ENV=production`, production `REVENUECAT_ANDROID_API_KEY`, and production `ENCRYPTION_KEY`, then uploaded to the chosen test track | Build command record without secret values, AAB path, versionCode/versionName, SHA-256 or Play artifact screenshot | Internal testing |
| Play internal or closed track setup | PLAY_CONSOLE | Play Console operator | Play Console > Testing | Track exists, testers are configured, opt-in URL is available, and the signed AAB is assigned to the track | Track screenshot, tester list/export, opt-in URL, release name | Internal testing |
| Data Safety form | PLAY_CONSOLE | Policy operator | Play Console > App content > Data Safety | Internal testing exemption/submission status is checked; closed/open/production submissions use answers that match `store/DATA_SAFETY_FORM.md`, final SDK list, map provider behavior, RevenueCat setup, and store/legal copy | Internal exemption evidence if applicable, plus submitted form screenshots or exported answers before closed/open/production | Closed/open/production testing and production |
| Content Rating questionnaire | PLAY_CONSOLE | Policy operator | Play Console > App content > Content rating | Questionnaire submitted for adult personal-safety utility behavior; certificate issued | Rating certificate screenshot/export | Internal testing and production |
| Target Audience | PLAY_CONSOLE | Policy operator | Play Console > App content > Target audience | Adult / 18+ intended audience selected; Designed for Families is not selected | Submitted target audience screenshot | Internal testing and production |
| Foreground service declaration | PLAY_CONSOLE | Policy operator | Play Console > App content > Foreground services | `specialUse` declaration explains active user-started safety sessions, visible persistent notification, and no hidden tracking | Submitted declaration screenshot/text copy | Internal testing and production |
| Exact alarm declaration or rationale | PLAY_CONSOLE | Policy operator | Play Console > App content, if requested | Declaration/rationale explains safety timers, denied permission behavior, degraded acknowledgment, and fallback scheduling | Submitted declaration screenshot/text copy or evidence Play did not request it | Internal testing and production |
| Battery optimization reviewer note | PLAY_CONSOLE | Policy operator | Play Console app review notes, if requested | Note explains optional reliability prompt, user can decline, and no hidden bypass claim | Reviewer note screenshot/text copy or evidence not requested | Internal testing and production |
| CALL_PHONE reviewer note | PLAY_CONSOLE | Policy operator | Play Console app review notes, if requested | Note explains user-initiated Panic/SOS flow, countdown/confirmation, and `ACTION_DIAL` fallback | Reviewer note screenshot/text copy or evidence not requested | Internal testing and production |
| Privacy policy URL | NEEDS_OPERATOR_ACTION | Release operator | Hosted legal page and Play Console listing/app content | Live URL loads the Turkish privacy policy and is submitted in Play Console | Browser screenshot with URL/date and Play Console field screenshot | Internal testing and production |
| Terms URL | NEEDS_OPERATOR_ACTION | Release operator | Hosted legal page and Play Console listing/app content where applicable | Live URL loads `kullanim_sartlari.html`; subscription terms link also resolves | Browser screenshot with URL/date and Play Console field screenshot if field is used | Internal testing and production |
| Data deletion URL | NEEDS_OPERATOR_ACTION | Release operator | Hosted legal page and Play Console app content | Live URL explains local data deletion separately from Google Play subscription cancellation | Browser screenshot with URL/date and Play Console field screenshot | Internal testing and production |
| Google Play monthly subscription product | PLAY_CONSOLE | Billing operator | Play Console > Monetization products | Monthly product is active/available for the test track and matches RevenueCat package mapping | Product screenshot with product ID and status | Internal testing |
| Google Play annual subscription product | PLAY_CONSOLE | Billing operator | Play Console > Monetization products | Annual product is active/available for the test track and matches RevenueCat package mapping | Product screenshot with product ID and status | Internal testing |
| RevenueCat Android app | REVENUECAT | Billing operator | RevenueCat dashboard | App exists for package `com.poyrazoncel.korubeni` and is connected to Google Play | RevenueCat app/settings screenshot | Internal testing |
| RevenueCat entitlement `KoruBeni Pro` | REVENUECAT | Billing operator | RevenueCat dashboard | Entitlement identifier is exactly `KoruBeni Pro` | RevenueCat entitlement screenshot | Internal testing |
| RevenueCat current offering | REVENUECAT | Billing operator | RevenueCat dashboard | Current offering exists and contains monthly and annual packages mapped to Play products | Offering/packages screenshot | Internal testing |
| License tester setup | PLAY_CONSOLE | Billing operator | Play Console and tester Google accounts | Test accounts are configured, opted in to the track, and can see the test build | License tester screenshot and opt-in confirmation | Internal testing |
| Billing runtime validation | REVENUECAT | Billing operator | Play test track / Play Billing Lab / physical device | Monthly purchase, annual purchase, restore, cancel/manage, expired/lapsed/paused/account-hold if available, no-offering, and network-failure fallback are verified | Test matrix with account, date, build, screenshots/video, and PASS/FAIL notes | Production |
| Android 13 physical QA | NEEDS_REAL_DEVICE_TEST | QA operator | Physical Android 13 device | Required rows in `store/REAL_DEVICE_QA_MATRIX.md` pass on signed test build | Completed QA matrix with device model, OS, build, screenshots/video/log excerpts | Production |
| Android 14 physical QA | NEEDS_REAL_DEVICE_TEST | QA operator | Physical Android 14 device | Required rows in `store/REAL_DEVICE_QA_MATRIX.md` pass, including notification, foreground service, exact alarm degraded flow, and battery prompts | Completed QA matrix with device model, OS, build, screenshots/video/log excerpts | Production |
| Android 15 physical QA if available | NEEDS_REAL_DEVICE_TEST | QA operator | Physical Android 15 device | Same required rows pass if an Android 15 device is available before submission | Completed QA matrix or documented unavailability | Production |
| Screenshot PII review | NEEDS_OPERATOR_ACTION | Store operator | Local screenshot set and Play Console listing | Every uploaded screenshot contains no real names, phone numbers, emails, addresses, sensitive coordinates, private account data, or accidental profile info | Signed screenshot review checklist and final filenames | Internal testing and production |
| Feature graphic and final store assets | NEEDS_OPERATOR_ACTION | Store operator | Store asset source and Play Console listing | Play icon is verified as 512x512 PNG, feature graphic is 1024x500, screenshots come from `store/screenshots/android/final/`, and Turkish-only listing copy is used | Asset filenames, dimensions, and Play listing screenshots | Internal testing and production |
| Closed testing production-access requirement | PLAY_CONSOLE | Play Console operator | Play Console production access screen and closed testing | Operator checks the production access screen. If the account is subject to the personal-account rule, at least 12 testers stay opted in for 14 continuous days and Play unlocks production access | Production-access requirement screenshot, tester count, dates, and unlock evidence if applicable | Production |
| iOS / App Store readiness | NOT_APPLICABLE / FUTURE_SCOPE | Release owner | Separate future iOS epic | Not an Android Play release blocker; future iOS scope would need `ios/`, Info.plist permission strings, iOS IAP, App Store privacy details, account deletion review, TestFlight, and App Review Notes | Future-scope epic only if iOS release is requested | Not an Android gate |
| Pre-launch report review | PLAY_CONSOLE | QA operator | Play Console > Release testing report | Google pre-launch report is reviewed and any stability, performance, accessibility, or policy issue is triaged before production | Report screenshot/export with disposition for each finding | Production |
| Android vitals monitoring plan | PLAY_CONSOLE | Release owner | Play Console > Android vitals after rollout | Crash, ANR, battery, permission, and quality metrics are monitored during staged rollout with rollback/hold criteria | Monitoring owner, rollout dates, thresholds, and vitals screenshots | Production and post-release |
| CI/release log secret review | NEEDS_OPERATOR_ACTION | Release operator | GitHub Actions / local build logs / Fastlane logs | Logs contain no dart-define values, signing passwords, keystore material, RevenueCat API key values, or encryption key values; any secret names are masked/redacted | Saved log review note with values redacted | Internal testing and production |
| Review CI logs after real release workflow run for secret leakage | NEEDS_OPERATOR_ACTION | Release operator | GitHub Actions release workflow logs | Confirm no dart-define values, signing passwords, keystore material, RevenueCat API key values, encryption keys, or service credentials are visible | Saved redacted log review note | Internal testing and production |

## Versioning And Build Readiness

| Item | Status | Notes |
| --- | --- | --- |
| Build number increased for each store upload | NEEDS_OPERATOR_ACTION | Use `scripts/bump_version.sh` before operator build/upload. |
| Production AAB command prepared | CODE_DONE | `flutter build appbundle --release --flavor play --dart-define=ENV=production --dart-define=REVENUECAT_ANDROID_API_KEY=... --dart-define=ENCRYPTION_KEY=...` |
| Production AAB output path documented | CODE_DONE | `build/app/outputs/bundle/playRelease/app-play-release.aab` |
| Signed AAB produced | SIGNING | Operator must build with real signing config and secrets. |
| Keystore/secrets committed | CODE_DONE | No secret should be committed; `android/key.properties.example` remains placeholder-only. |

## Store Assets

| Item | Status | Notes |
| --- | --- | --- |
| Store listings source of truth | CODE_DONE | First Play release is Turkish-only. Public listing source is `store/play_store_listing_tr.md`; `store/play_store_listing_en.md` is internal reference only and must not be pasted into Play Console for this release. |
| TR short description | CODE_DONE | `Panik/SOS Pro; konum, sahte çağrı ve siren ücretsiz.` |
| EN short description | N/A_FOR_FIRST_RELEASE | Do not create an English Play listing until English runtime support is restored and tested. |
| Play store icon | NEEDS_OPERATOR_ACTION | Must be 512x512 PNG. Candidate asset: `store/assets/play_icon_512.png`; verify in Play Console. |
| Feature graphic | NEEDS_OPERATOR_ACTION | Prepare or verify 1024x500 feature graphic in Play Console. |
| Screenshots canonical upload path | NEEDS_OPERATOR_ACTION | Use `store/screenshots/android/final/`; see `store/screenshots/README.md`. |
| Screenshot PII review | NEEDS_OPERATOR_ACTION | Must confirm no real names, phone numbers, emails, addresses, sensitive coordinates, private account data, or accidental profile info. |

## Play Console Forms And Declarations

| Item | Status | Notes |
| --- | --- | --- |
| Data Safety prepared | CODE_DONE | See `store/DATA_SAFETY_FORM.md`; internal testing may be exempt depending on Play Console state, but closed/open/production submission is PLAY_CONSOLE. |
| Content Rating prepared | CODE_DONE | See `store/CONTENT_RATING_ANSWERS.md`; submit/certificate is PLAY_CONSOLE. |
| Target Audience prepared | CODE_DONE | Intended for adults / 18+; do not enter Designed for Families unless product decision changes. |
| Privacy URL prepared | CODE_DONE | `https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html`; operator must verify live URL. |
| Terms URL prepared | CODE_DONE | `https://poyrazoncel34-netizen.github.io/guvenlik_app/kullanim_sartlari.html`; operator must verify live URL. |
| Data deletion URL prepared | CODE_DONE | `https://poyrazoncel34-netizen.github.io/guvenlik_app/data_deletion.html`; operator must verify live URL. |
| Foreground service specialUse declaration prepared | CODE_DONE | Active user-started safety sessions only; visible persistent notification; no hidden tracking. |
| Exact alarm declaration prepared | CODE_DONE | User-visible safety deadlines/timers with denied/fallback/degraded behavior. |
| Battery optimization declaration prepared | CODE_DONE | Optional reliability improvement; user can decline; degraded mode remains supported; OEM/Android settings may still affect behavior. |
| CALL_PHONE reviewer note prepared | CODE_DONE | User-initiated Panic/SOS flow with countdown/confirmation and `ACTION_DIAL` fallback. |
| FLAG_SECURE reviewer note prepared | CODE_DONE | Screenshots are blocked for safety/privacy; reviewer can still navigate app. |

## RevenueCat / Google Play Billing

Canonical checklist: `store/BILLING_RELEASE_CHECKLIST.md`.

All external billing items are PLAY_CONSOLE / REVENUECAT / NEEDS_REAL_DEVICE_TEST until evidence exists:

- Play monthly subscription product.
- Play annual subscription product.
- RevenueCat Android app configured for `com.poyrazoncel.korubeni`.
- RevenueCat entitlement exactly `KoruBeni Pro`.
- Current offering with monthly and annual packages.
- Paywall product loading.
- Monthly/annual purchase tests with license tester.
- Restore, cancel/manage, expired/lapsed, account hold/paused behavior if available.
- No-offering and network-failure fallbacks.
- Production RevenueCat key present for release build, with no dummy/CI key. PR/smoke CI artifacts are `NON_RELEASE_SMOKE` only and are not release provenance.

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
- Required app content forms are at least prepared; Data Safety may be submit-pending only for internal testing if Play Console does not require it for that track.
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
- Play Console production access screen checked; if the account is subject to the personal-account rule, closed testing with 12 opted-in testers for 14 continuous days completed.
- Screenshots reviewed for PII.
- Final store listing reviewed for overclaims.

Until those have external evidence: Production submission is NOT READY.
