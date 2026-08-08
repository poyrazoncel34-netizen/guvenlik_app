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
| Code-side release hardening | LOCAL_SOURCE_PASS / EXTERNAL_UNVERIFIED | Bu kaynak ağacında 688 Dart ve 60 native test ile zero-issue analyzer yeniden doğrulandı; önceki temiz baseline'daki 6/6 mutant ve dört kritik dosyada ≥%90 coverage kanıtı korunuyor. Bu sayılar production candidate için otomatik PASS değildir; exact source/tag üzerinde yeniden üretilen raporlar belirleyicidir. SBOM 400 bileşendir ve insan lisans incelemesi 0/400'dür. Fiziksel cihaz, exact production AAB ve bütün dış kapılar açıktır. 18 Temmuz ledger'ı tarihsel snapshot'tır. |
| Internal testing upload | SIGNING / PLAY_CONSOLE / REVENUECAT | Not ready until operator produces signed AAB, creates/uses Play internal or closed track, prepares required app content forms, confirms any Play Console internal-testing Data Safety exemption/submission status, and confirms RevenueCat/Play subscription setup is ready for testing. |
| Production submission | DO_NOT_CLAIM_READY | Not ready until Play Console forms, billing license-tester matrix, real-device QA, screenshot PII review, and closed testing if required are complete with evidence. |

No Play Console dashboard task, RevenueCat dashboard task, billing purchase test, signed AAB upload, or real-device QA is marked done in this repo.

## Final Operator Handoff Matrix

Every row below remains open until the named owner saves the required external evidence. Do not mark any row done from repo-only review.

| Item | Status | Owner | Where to perform | Done criteria | Evidence to save | Gate |
| --- | --- | --- | --- | --- | --- | --- |
| Exact SBOM human licence review | NEEDS_OWNER_REVIEW | Security/licensing reviewers + counsel | Exact lockfiles, primary upstream licence sources and `config/dependency_license_evidence.json` | 400/400 exact purl has reviewed source bytes/hash, SPDX disposition, accountable reviewer/date; policy and notice parity pass | Reviewed evidence, licence bytes, assignment/review record, SBOM/policy/notices hashes | G4 / Production |
| Candidate-bound MASVS assessment | NEEDS_OWNER_REVIEW / NEEDS_REAL_DEVICE_TEST | Independent security reviewer | Exact candidate evidence folder plus physical/dashboard security checks | All 24 current controls PASS or justified NOT_APPLICABLE; exact AAB/version and every evidence hash verify | `kind: masvsAssessment` manifest item, assessment, redacted reports and verifier output | G4 / Production |
| Signed AAB with pinned upload identity | SIGNING | Release operator | GitHub release workflow and Play Console track upload | `playRelease` AAB is built with production signing, `ENV=production`, the RevenueCat `goog_` Android public SDK key, and a keystore whose certificate matches `EXPECTED_UPLOAD_CERT_SHA256`; signature, 16 KB alignment and SHA-256 gates pass before upload | Workflow run URL, provenance file, SHA-256, AAB path/version, and Play artifact screenshot | Internal testing |
| Play internal or closed track setup | PLAY_CONSOLE | Play Console operator | Play Console > Testing | Track exists, testers are configured, opt-in URL is available, and the signed AAB is assigned to the track | Track screenshot, tester list/export, opt-in URL, release name | Internal testing |
| Data Safety form | PLAY_CONSOLE | Policy operator | Play Console > App content > Data Safety | Internal testing exemption/submission status is checked; closed/open/production submissions use answers that match `store/DATA_SAFETY_FORM.md`, final SDK list, map provider behavior, RevenueCat setup, and store/legal copy | Internal exemption evidence if applicable, plus submitted form screenshots or exported answers before closed/open/production | Closed/open/production testing and production |
| KVKK cross-border transfer mechanism for RevenueCat | NEEDS_OWNER_REVIEW | Release owner + Turkish privacy counsel | RevenueCat contract/DPA and KVKK Article 9 transfer mechanism | Counsel documents an applicable lawful transfer mechanism and any required standard-contract notification for the actual RevenueCat data flow, or RevenueCat is removed and the revised billing/privacy design is revalidated; disclosure text alone is not treated as authorization | Signed decision, counsel memo/contract-notification evidence, or RevenueCat-removal change evidence | Production |
| Content Rating questionnaire | PLAY_CONSOLE | Policy operator | Play Console > App content > Content rating | Questionnaire submitted for adult personal-safety utility behavior; certificate issued | Rating certificate screenshot/export | Internal testing and production |
| Target Audience | PLAY_CONSOLE | Policy operator | Play Console > App content > Target audience | Adult / 18+ intended audience selected; Designed for Families is not selected | Submitted target audience screenshot | Internal testing and production |
| Foreground service absence | NEEDS_OPERATOR_ACTION | Policy operator | Uploaded AAB details / Play Console App content | Bundle has no FGS permission/service; any stale `specialUse` Console draft is removed | Bundle permission/manifest evidence and Console screenshot | Internal testing and production |
| Exact alarm declaration or rationale | PLAY_CONSOLE | Policy operator | Play Console > App content, if requested | Declaration/rationale explains safety timers, fail-closed long-session arming, foreground-only Panic fallback, and post-arm inexact backup | Submitted declaration screenshot/text copy or evidence Play did not request it | Internal testing and production |
| Battery optimization reviewer note | PLAY_CONSOLE | Policy operator | Play Console app review notes, if requested | Note explains optional reliability prompt, user can decline, and no hidden bypass claim | Reviewer note screenshot/text copy or evidence not requested | Internal testing and production |
| CALL_PHONE reviewer note | PLAY_CONSOLE | Policy operator | Play Console app review notes, if requested | Note explains user-initiated Panic/SOS flow, countdown/confirmation, and `ACTION_DIAL` fallback | Reviewer note screenshot/text copy or evidence not requested | Internal testing and production |
| Privacy policy URL | NEEDS_OPERATOR_ACTION | Release operator | Hosted legal page and Play Console listing/app content | Live URL loads the Turkish privacy policy and is submitted in Play Console | Live content/hash PASS: `docs/qa/phase5-live-legal-url-evidence-2026-07-18.md`; Play Console field screenshot remains open | Internal testing and production |
| Terms URL | NEEDS_OPERATOR_ACTION | Release operator | Hosted legal page and Play Console listing/app content where applicable | Live URL loads `kullanim_sartlari.html`; subscription terms link also resolves | Live content/hash PASS: `docs/qa/phase5-live-legal-url-evidence-2026-07-18.md`; Play Console field screenshot remains open | Internal testing and production |
| Data deletion URL | NEEDS_OPERATOR_ACTION | Release operator | Hosted legal page and Play Console app content | Live URL explains local data deletion separately from Google Play subscription cancellation | Live content/hash PASS: `docs/qa/phase5-live-legal-url-evidence-2026-07-18.md`; Play Console field screenshot remains open | Internal testing and production |
| Google Play monthly subscription product | PLAY_CONSOLE | Billing operator | Play Console > Monetization products | Monthly product is active/available for the test track and matches RevenueCat package mapping | Product screenshot with product ID and status | Internal testing |
| Google Play annual subscription product | PLAY_CONSOLE | Billing operator | Play Console > Monetization products | Annual product is active/available for the test track and matches RevenueCat package mapping | Product screenshot with product ID and status | Internal testing |
| RevenueCat Android app | REVENUECAT | Billing operator | RevenueCat dashboard | App exists for package `com.poyrazoncel.korubeni` and is connected to Google Play | RevenueCat app/settings screenshot | Internal testing |
| RevenueCat entitlement `KoruBeni Pro` | REVENUECAT | Billing operator | RevenueCat dashboard | Entitlement identifier is exactly `KoruBeni Pro` | RevenueCat entitlement screenshot | Internal testing |
| RevenueCat current offering | REVENUECAT | Billing operator | RevenueCat dashboard | Current offering exists and contains monthly and annual packages mapped to Play products | Offering/packages screenshot | Internal testing |
| License tester setup | PLAY_CONSOLE | Billing operator | Play Console and tester Google accounts | Test accounts are configured, opted in to the track, and can see the test build | License tester screenshot and opt-in confirmation | Internal testing |
| Billing runtime validation | REVENUECAT | Billing operator | Play test track / Play Billing Lab / physical device | Monthly purchase, annual purchase, restore, cancel/manage, expired/lapsed/paused/account-hold if available, no-offering, and network-failure fallback are verified | Test matrix with account, date, build, screenshots/video, and PASS/FAIL notes | Production |
| API 29 boundary-phone QA | NEEDS_REAL_DEVICE_TEST | QA operator | arm64 telephony-capable API 29 phone | Required rows and repeated deadline/race acceptance pass on the lower support boundary | Candidate-bound matrix, video and redacted timing logs | Production |
| API 36 / 16 KB Pixel QA | NEEDS_REAL_DEVICE_TEST | QA operator | Physical Pixel/AOSP API 36 with 16 KB kernel | Install/launch without compat mode; alarm, reboot, permission and telephony rows pass | Candidate-bound matrix, Bundle Explorer parity, kernel/page-size evidence | Production |
| Samsung + Xiaomi OEM QA | NEEDS_REAL_DEVICE_TEST | QA operator | One UI and HyperOS API 34/35+ phones | Required 100/50/20 repeated deadline/race/Doze/reboot sweeps pass with zero safety violation | Candidate-bound matrix, video and redacted timing logs | Production |
| Dual-SIM + low-memory coverage | NEEDS_REAL_DEVICE_TEST | QA operator | At least one dual-SIM and one low-memory phone across the pool | SIM-selection/no-SIM/ongoing-call and memory-pressure/process-death rows pass | Device specs and candidate-bound matrix evidence | Production |
| Screenshot PII review | NEEDS_OPERATOR_ACTION | Store operator | Local screenshot set and Play Console listing | Every uploaded screenshot contains no real names, phone numbers, emails, addresses, sensitive coordinates, private account data, or accidental profile info; exact signed-candidate version mismatch is resolved/accepted | Repo visual PII review PASS in `docs/qa/phase5-store-assets-evidence-2026-07-18.md`; signed-candidate recapture/exception and actual Play upload evidence remain open | Internal testing and production |
| Feature graphic and final store assets | NEEDS_OPERATOR_ACTION | Store operator | Store asset source and Play Console listing | Play icon is verified as 512x512 PNG, feature graphic is 1024x500, screenshots come from `store/screenshots/android/final/`, and Turkish-only listing copy is used | Dimensions/formats/hashes PASS in `docs/qa/phase5-store-assets-evidence-2026-07-18.md`; owner masked-icon/visual approval and Play listing screenshots remain open | Internal testing and production |
| Closed testing production-access requirement | PLAY_CONSOLE | Play Console operator | Play Console production access screen and closed testing | Operator checks the production access screen. If the account is subject to the personal-account rule, at least 12 testers stay opted in for 14 continuous days and Play unlocks production access | Production-access requirement screenshot, tester count, dates, and unlock evidence if applicable | Production |
| iOS / App Store readiness | NOT_APPLICABLE / FUTURE_SCOPE | Release owner | Separate future iOS epic | Not an Android Play release blocker; future iOS scope would need `ios/`, Info.plist permission strings, iOS IAP, App Store privacy details, account deletion review, TestFlight, and App Review Notes | Future-scope epic only if iOS release is requested | Not an Android gate |
| Pre-launch report review | PLAY_CONSOLE | QA operator | Play Console > Release testing report | Google pre-launch report is reviewed and any stability, performance, accessibility, or policy issue is triaged before production | Report screenshot/export with disposition for each finding | Production |
| Android vitals monitoring plan | PLAY_CONSOLE | Release owner | Play Console > Android vitals after rollout | `store/PRODUCTION_ROLLOUT_RUNBOOK.md` roles, observation cadence and P0/P1 stop criteria are assigned; first release is not falsely treated as staged/rollback-capable | Named owners, decision log, rollout dates, filtered vitals screenshots and incident evidence | Production and post-release |
| CI/release log sensitive-value review | NEEDS_OPERATOR_ACTION | Release operator | GitHub Actions / local build logs / Fastlane logs | Logs contain no dart-define values, signing passwords, keystore material, RevenueCat key values, or service credentials; any sensitive values are masked/redacted | Saved log review note with values redacted | Internal testing and production |
| Review CI logs after real release workflow run for sensitive-value leakage | NEEDS_OPERATOR_ACTION | Release operator | GitHub Actions release workflow logs | Confirm no dart-define values, signing passwords, keystore material, RevenueCat key values, or service credentials are visible | Saved redacted log review note | Internal testing and production |

## Versioning And Build Readiness

| Item | Status | Notes |
| --- | --- | --- |
| Build number increased for each store upload | NEEDS_OPERATOR_ACTION | Use `scripts/bump_version.sh` before operator build/upload. |
| Production AAB command prepared | CODE_DONE | `flutter build appbundle --release --flavor play --target-platform android-arm64 --dart-define=ENV=production --dart-define=REVENUECAT_ANDROID_API_KEY=...` |
| Production AAB output path documented | CODE_DONE | `build/app/outputs/bundle/playRelease/app-play-release.aab` |
| Signed AAB produced | SIGNING | Operator must build with real signing config and secrets. |
| Keystore/secrets committed | CODE_DONE | No secret should be committed; `android/key.properties.example` remains placeholder-only. |

## Store Assets

| Item | Status | Notes |
| --- | --- | --- |
| Store listings source of truth | CODE_DONE | First Play release is Turkish-only. Public listing source is `store/play_store_listing_tr.md`; `store/play_store_listing_en.md` is internal reference only and must not be pasted into Play Console for this release. |
| TR short description | CODE_DONE | `Panik butonu, sahte çağrı, siren. Hesap yok, verileriniz cihazınızda kalır.` |
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
| Privacy URL prepared | CODE_DONE / LIVE_VERIFIED | `https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html`; HTTP/content parity evidence: `docs/qa/phase5-live-legal-url-evidence-2026-07-18.md`. Play Console submission remains open. |
| Terms URL prepared | CODE_DONE / LIVE_VERIFIED | `https://poyrazoncel34-netizen.github.io/guvenlik_app/kullanim_sartlari.html`; both `.html` and extensionless routes match source. Play Console submission and legal-owner approval remain open. |
| Data deletion URL prepared | CODE_DONE / LIVE_VERIFIED | `https://poyrazoncel34-netizen.github.io/guvenlik_app/data_deletion.html`; HTTP/content parity evidence recorded. Play Console submission remains open. |
| Foreground service removal | CODE_DONE | FGS dependency, permissions, service entry and `specialUse` subtype removed; AAB verification remains operator evidence. |
| Exact alarm declaration prepared | CODE_DONE | User-visible safety deadlines/timers; denial blocks long/scheduled arming, while Panic remains foreground/manual-dial only. |
| Battery optimization declaration prepared | CODE_DONE | Optional reliability improvement; user can decline; degraded mode remains supported; OEM/Android settings may still affect behavior. |
| CALL_PHONE reviewer note prepared | CODE_DONE | User-armed Panic/SOS, Check-In, and Safe Walk expiry; unconfirmed Telecom request plus user-tapped `ACTION_DIAL` fallback. |
| Screenshot/privacy reviewer note prepared | CODE_DONE | Global `FLAG_SECURE` is absent; screenshots are possible; the background recent-apps preview is covered by an in-app privacy mask. |
| Health Apps Declaration prepared | CODE_DONE / PLAY_CONSOLE | Actual build has no health feature; submit the declaration as “No health features”. |
| App Access / reviewer instructions prepared | CODE_DONE | No login required for basic access. Pro features unlock via subscription; for review without payment, use Play Console license tester account (https://support.google.com/googleplay/android-developer/answer/6062777). Reviewer path + paywall test steps documented in `docs/play_console_declarations.md` (App Access / Reviewer Notes section). Operator must supply the actual license tester credentials in Play Console App Access form. |

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
- Production RevenueCat `goog_` Android public SDK key present for release build, with no `test_` Test Store, `sk_` server secret, or dummy/CI value. PR/main `NON_RELEASE_SMOKE` artifacts use a distinct `.smoke` application ID and are not release provenance.

Code-side fail-safe remains required: Play release builds must fail if the RevenueCat Android public SDK key is missing/unsafe, if signing material is missing, or if the upload certificate identity is not the pinned fingerprint. No signing password, keystore, or server-side secret may be committed.

## Real-Device QA

Canonical matrix: `store/REAL_DEVICE_QA_MATRIX.md`.

Minimum required evidence before production:

- API 29 arm64 boundary phone: required rows PASS.
- API 36 Pixel/AOSP with a 16 KB kernel: required rows PASS.
- Samsung One UI and Xiaomi/HyperOS API 34/35+: repeated sweeps PASS.
- At least one dual-SIM and one low-memory phone: required rows PASS.

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
- KVKK Article 9 cross-border transfer mechanism for the actual RevenueCat data
  flow reviewed and evidenced by the owner/counsel; privacy disclosure alone is
  not accepted as a lawful-transfer mechanism.
- Content Rating submitted.
- Target Audience submitted.
- Privacy URL submitted.
- Data deletion URL submitted if applicable.
- Uploaded AAB confirmed free of foreground-service permission/service and stale Console draft removed.
- Exact alarm declaration submitted if required.
- Battery optimization declaration submitted if required.
- Billing license-tester matrix passed.
- Real-device QA matrix passed on the full API29/API36/Pixel/Samsung/Xiaomi,
  dual-SIM and low-memory support envelope.
- Play Console production access screen checked; if the account is subject to the personal-account rule, closed testing with 12 opted-in testers for 14 continuous days completed.
- Screenshots reviewed for PII.
- Final store listing reviewed for overclaims.

Until those have external evidence: Production submission is NOT READY.

## Production Rollout / Incident Gate

Canonical procedure: `store/PRODUCTION_ROLLOUT_RUNBOOK.md`.

- The first production release cannot use staged rollout and has no previous
  production version to halt back to. Its closed-test soak and hotfix readiness
  are mandatory compensating controls.
- Later updates use manual 5% → 20% → 50% → 100% progression with explicit hold
  decisions; already-updated devices are never assumed to downgrade on halt.
- Google bad-behavior thresholds are store visibility limits, not an acceptable
  safety error budget. One confirmed critical emergency/security defect stops
  the release regardless of percentage.
- `No data available` is insufficient evidence, not PASS.
