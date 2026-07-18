# KoruBeni Release Research Notes

Last updated: 2026-06-27, Europe/Istanbul.

## Decision Frame

Goal: choose the repository/application path to continue, verify the app itself rather than relying on existing Markdown docs, and move the selected path toward Google Play release readiness.

Current decision: continue with `/Users/poyrazoncel/Desktop/guvenlik_app` on branch `main`.

Evidence:
- `pubspec.yaml`, `lib/main.dart`, Android manifest, Gradle config, store assets, and release scripts all describe the same Flutter Android app: KoruBeni.
- `git worktree list` shows only this workspace as an active Git worktree; `.claude/.claire` directories are historical agent/worktree metadata, not alternate publishable roots.
- Play-flavored Android release output already exists under `build/app/outputs/bundle/playRelease/`, indicating the current root is the build authority.

Confidence:
- H1 current root repo is the repo to ship: 0.90.
- H2 another hidden worktree should be selected: 0.05.
- H3 this is not ready for Play and needs a fresh repo split: 0.05.

## Hypothesis Tree

H1: Current root Flutter app should be hardened and shipped to Google Play.
- Supports: Android package `com.poyrazoncel.korubeni`; Play flavor exists; release scripts point to `playRelease`; app includes legal consent, billing, privacy URLs, screenshots, icon assets, tests.
- Weakens: Some manual Play Console gates cannot be completed from code; Billing Client is currently 7.1.1 in the generated manifest.
- Confidence: 0.90.

H2: Publish should use a different repo/worktree.
- Supports: Agent metadata directories exist.
- Weakens: `git worktree list` reports only the current root; no second full app root has release scripts/assets/build output.
- Confidence: 0.05.

H3: App should not be submitted until policy/technical risks are closed.
- Supports: Generated Play release manifest reports `com.google.android.play.billingclient.version=7.1.1`; Google Play Billing Library 8+ becomes required for app updates from 2026-08-31.
- Weakens: Current date is 2026-06-27, so immediate submission may still be possible, but "release-ready" should avoid a near-term compliance cliff.
- Confidence: 0.75.

## Primary Source Checks

Claim A: Google Play release readiness depends on target SDK/current platform policy, not just a successful Flutter build.
- Source 1: Android Developers, Google Play target API level requirements: https://developer.android.com/google/play/requirements/target-sdk
- Source 2: Google Play Developer Policy Center / Play Console Help policy pages: https://support.google.com/googleplay/android-developer/answer/9888170
- Local evidence: `android/app/build.gradle.kts` sets `targetSdk = 35`, `compileSdk = 36`.
- Confidence: 0.80 now; re-check before submission if date is near or after 2026-08-31.

Claim B: Billing/subscriptions must use Google Play Billing and disclose terms clearly.
- Source 1: Android Developers, Google Play Billing: https://developer.android.com/google/play/billing
- Source 2: Play Console Help, subscriptions policy/help: https://support.google.com/googleplay/android-developer/answer/10281818
- Local evidence: app uses RevenueCat + Google Play Billing permission; custom paywall shows price from StoreProduct and restore flow.
- Current gap: generated `playRelease` manifest shows Billing Client `7.1.1`; latest resolvable `purchases_flutter`/`purchases_ui_flutter` is `10.3.0`.
- Confidence: 0.85 that dependency upgrade is needed for durable release readiness.

Claim C: Sensitive permissions and background behavior need Play declarations and narrow in-app rationale.
- Source 1: Android Developers foreground service declaration docs: https://developer.android.com/develop/background-work/services/fgs/declare
- Source 2: Play Console Help, permissions/API policy: https://support.google.com/googleplay/android-developer/answer/9888170
- Local evidence: manifest uses `FOREGROUND_SERVICE_SPECIAL_USE`, `SCHEDULE_EXACT_ALARM`, `CALL_PHONE`, optional battery optimization exemption, no background location, no SMS, no microphone.
- Confidence: 0.75 because Play Console declarations and reviewer notes are operator-side gates.

Claim D: Personal/sensitive user data requires privacy policy and accurate data safety disclosures.
- Source 1: Google Play User Data policy: https://support.google.com/googleplay/android-developer/answer/10144311
- Source 2: Google Play Data safety help: https://support.google.com/googleplay/android-developer/answer/10787469
- Local evidence: app has public legal URLs in `AppConstants`, in-app consent flow, local consent records, privacy/data deletion pages in `store/`.
- Confidence: 0.80; final confidence depends on Play Console form values matching the app behavior.

## Current Findings

1. Repo selection: use current root repo. Confidence 0.90.
2. Distribution channel: Android / Google Play first. Confidence 0.85. iOS is explicitly not configured (`ios: false` icon/splash, Android-only services).
3. Immediate technical blocker: Billing Client 7.1.1 should be upgraded to Billing Library 8+ via RevenueCat dependencies. Confidence 0.85.
4. Policy-sensitive areas: FGS special use, exact alarm, call permission, battery optimization exemption, subscription terms, Data Safety. Confidence 0.75.
5. Manual gates remain outside code: signing key, production secrets, RevenueCat dashboard products/entitlement/current offering, Play Console forms, real-device QA, pre-launch report. Confidence 0.95.

## Self-Critique Log

- Initial risk: over-trusting existing release docs. Mitigation: inspected app code, Android manifest, Gradle config, generated manifest, release scripts, tests, and build artifacts directly.
- Initial risk: equating "build passes" with "release ready". Mitigation: separated code-verifiable gates from operator/Play Console gates.
- New risk found during inspection: Billing Client version. Mitigation: upgrade RevenueCat packages and verify generated manifest after rebuild.
- Remaining uncertainty: official Play policy pages can change. Mitigation: source URLs are recorded; re-run source check before final production submission.

## Next Actions

1. Upgrade RevenueCat Flutter dependencies to latest resolvable versions that bring Billing Library 8+.
2. Refresh lockfile and regenerate/inspect Play release manifest.
3. Run `flutter analyze`, targeted release/policy tests, Android native tests where feasible, and a Play appbundle build if signing/secrets are available.
4. Update this note with verification results and final confidence.
