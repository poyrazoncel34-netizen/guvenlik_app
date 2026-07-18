# Phase 4 — Local Release Engineering Evidence (2026-07-17)

Scope: repo, local Android toolchain, and a deliberately non-uploadable smoke
bundle. This is **not** Play Console, RevenueCat-dashboard, billing-sandbox, or
physical-device evidence.

## Verified locally

| Gate | Result | Evidence |
| --- | --- | --- |
| Flutter static analysis | PASS | `flutter analyze`: no issues |
| Flutter regression suite | PASS | Clean artifact run after the Phase 5 gates and RevenueCat 10.4.2 update: 524/524 |
| Release-mode smoke bundle | PASS | `app-smoke-release.aab`, R8/resource shrinking, application ID `com.poyrazoncel.korubeni.smoke` |
| Distribution isolation | PASS | CI/smoke application ID has `.smoke` suffix; RevenueCat is disabled under exact `ENV=ci_smoke` + sentinel contract |
| AAB signing | PASS | `jarsigner -verify`: `jar verified.` |
| Native ABI contract | PASS | Clean bundle contains only `arm64-v8a` and `x86_64`; build/workflow gates reject 32-bit ABI entries |
| 16 KB page size | PASS_LOCAL | 10/10 bundled 64-bit native libraries have PT_LOAD alignment >= `0x4000` |
| Android release lint | PASS | `app:lintSmokeRelease` |
| Android host unit tests | PASS | `app:testPlayDebugUnitTest` |
| Instrumentation APK compilation | PASS | `app:assemblePlayDebugAndroidTest` |
| Unsafe Play environment | EXPECTED_REJECTION | `bundlePlayRelease` with `ENV=dev` fails during Gradle configuration |
| RevenueCat server secret | EXPECTED_REJECTION | `bundlePlayRelease` with an `sk_` value fails during Gradle configuration |
| Invalid smoke sentinel | EXPECTED_REJECTION | `bundleSmokeRelease` with any other value fails during Gradle configuration |

Smoke artifact snapshot SHA-256:

```text
72d7fd11d66a5720a8976f2e5b10d4d0d8b1b23bfb2800a067baf3a113e9884e
```

The hash is only evidence for that local smoke build. It is not the production
AAB hash and must never be uploaded as the KoruBeni Play artifact.

## Release-chain hardening implemented

- Normal CI no longer builds the real Play application ID. It uses `.smoke`,
  temporary signing, a fixed non-release sentinel, and disabled billing.
- Play releases require `ENV=production`, a `goog_` RevenueCat Android public
  SDK key, and release signing. `test_` Test Store keys,
  placeholder/dummy/smoke values, and `sk_` server secrets are rejected in
  Gradle and Dart.
- Release tag parsing is strict numeric `vMAJOR.MINOR.PATCH` and rejects
  version-code collisions/out-of-range values.
- The release workflow pins the upload certificate with
  `EXPECTED_UPLOAD_CERT_SHA256`, then verifies AAB archive integrity, JAR
  signature, ABI set, 16 KB alignment, lint/native tests, SHA-256, and a
  provenance record.
- Before dependency resolution, the tagged workflow now rejects every tracked,
  staged, or untracked source drift and binds the annotated tag, exact commit,
  Git tree, and later the AAB SHA-256 into hashed provenance evidence. The
  current development worktree intentionally fails this production check; a
  local smoke AAB cannot acquire production provenance.
- Battery-optimization exemption handling has one native authority. The old
  Doze channel and `optimize_battery` plugin were removed; direct request and
  generic settings are distinct actions, and the UI re-reads actual state on
  resume instead of treating intent launch as a grant.
- The local production script no longer converts build or 16 KB failures into
  warnings.
- Runtime entitlement renew/lapse changes are observed through RevenueCat's
  `CustomerInfoUpdateListener` while the app remains open.
- Debug and release variants are restricted to the same 64-bit ABI contract.
  Release lint and playDebug host/instrumentation tasks run in separate Gradle
  processes so Flutter's shared native-assets directory cannot create a
  cross-variant snapshot race.
- RevenueCat's optional Amazon store adapter/Appstore SDK are excluded from all
  variants because the product scope is Google Play only. RevenueCat's hybrid
  manifest still contributes an Amazon proxy activity, so the Play source
  manifest removes that exact component with a narrow `MissingClass` lint
  suppression on the removal marker. The merged smoke manifest contains no
  Amazon component. Google Play Billing 8's own DataTransport components remain
  part of the billing SDK and are covered by the existing Billing/RevenueCat
  Data Safety disclosure.
- `purchases_flutter` and `purchases_ui_flutter` were advanced together from
  10.3.0 to 10.4.2 before production signing/billing qualification. The clean
  artifact gate above therefore exercises RevenueCat Android 10.14.0 rather
  than relying on the older 10.9.1 transitive runtime.
- `USE_FULL_SCREEN_INTENT` was removed because KoruBeni is neither an alarm
  clock nor an incoming-call app and there is no explicit user-consent flow for
  that special access. Urgent notifications degrade to heads-up behavior.

## External gates still not run

The following remain `NOT_RUN` and block a production-ready verdict:

- Decode and verify the real GitHub keystore against the owner-pinned upload
  certificate, then run the tagged workflow.
- Upload the signed Play AAB and confirm Play App Bundle Explorer reports 16 KB
  compatibility and the expected merged permissions/components.
- Configure Play monthly/annual base plans, RevenueCat service credentials,
  entitlement `KoruBeni Pro`, current offering, and package mapping.
- Run monthly/annual purchase, restore, cancellation, renewal, lapse/expiry,
  no-offering, and offline/error paths with a license tester on a physical
  device. The first release must not enable a trial/intro offer while the
  current paywall cannot disclose its exact offer phases.
- Complete required Play App Content forms, pre-launch report review, closed
  testing requirements (if the account is subject to them), and the physical
  OEM/telephony matrix.

## Primary-source policy anchors

- Play target API requirement: <https://developer.android.com/google/play/requirements/target-sdk>
- Android exact-alarm guidance: <https://developer.android.com/develop/background-work/services/alarms>
- Android Doze/battery-exemption acceptable cases: <https://developer.android.com/training/monitoring-device-state/doze-standby>
- RevenueCat public versus secret keys: <https://www.revenuecat.com/docs/projects/authentication>
- RevenueCat Play credentials: <https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials>
- RevenueCat Google Play sandbox: <https://www.revenuecat.com/docs/test-and-launch/sandbox/google-play-store>
- Play full-screen-intent policy: <https://support.google.com/googleplay/android-developer/answer/13392821>
