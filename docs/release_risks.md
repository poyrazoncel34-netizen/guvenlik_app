# Release Risks

## OpenStreetMap Tiles

The app currently uses `https://tile.openstreetmap.org/{z}/{x}/{y}.png` directly for the in-app map. Attribution is visible and a package user agent is set, but this endpoint is not intended as an enterprise-grade production tile service.

Before a larger production launch, switch to a production-suitable provider such as MapTiler, Stadia, Thunderforest, Mapbox, or a self-hosted tile service with a proper API key and quota policy.

Current mitigation:
- OSM attribution is shown in the map UI.
- `userAgentPackageName` includes a contact channel (`com.poyrazoncel.korubeni; +korubeni.destek@gmail.com`) per OSMF "highly recommended" guidance.
- The app only requests tiles for the map viewport the user actively opens.
- The app must not bulk download, scrape, pre-seed, cache as an offline archive, or package OpenStreetMap public tiles.
- Store/legal copy does not claim enterprise-grade map reliability.

## Manual Play Console Items

- Public privacy and data deletion URLs are prepared; operator must verify hosted pages stay live before release.
- Confirm RevenueCat products, offering IDs, and Google Play subscription products match.
- Complete Play Console content rating and target audience with adult / 18+ intended audience notes.
- Submit Data Safety accurately; do not mark local-only data as developer-collected/shared unless the final build transmits it.
- Copy `docs/play_console_declarations.md` into the corresponding declaration fields.
- Confirm the uploaded AAB has no foreground-service permission/service entry; remove any stale `specialUse` Console draft. Submit exact alarm / battery optimization declarations if Play Console requires them.
- Use screenshot upload path `store/screenshots/android/final/` and complete manual PII review.
- Verify Play icon is 512x512 PNG and feature graphic is 1024x500.

## Runtime And Production Gates

- Real-device QA is not complete. Emulator evidence is not accepted for production readiness.
- Billing is not complete. Monthly purchase, annual purchase, restore, cancel/manage, no-offering, and network-failure fallback must be tested through Play test tracks and license testers.
- Production is DO_NOT_CLAIM_READY until Play Console forms, billing tests, Android 13/14 physical-device QA, screenshot PII review, and closed testing if required are complete with evidence.

## Android 15 / Android 16 / 16 KB Page Size Readiness

### Target API timeline (Play Console)

| Date | Requirement | Source |
| --- | --- | --- |
| 2025-08-31 | New apps + updates must target API 35 (Android 15) | https://support.google.com/googleplay/android-developer/answer/11926878 |
| 2025-11-01 | New apps and new builds (with native libs) must support 16 KB memory page sizes | https://developer.android.com/guide/practices/page-sizes |
| 2026-05-01 | Updates to existing apps (with native libs) must support 16 KB page sizes | Same |
| 2026-08-31 | New apps and updates must target API 36 (Android 16). | https://developer.android.com/google/play/requirements/target-sdk |

### Current build configuration

From [`android/app/build.gradle.kts`](../android/app/build.gradle.kts):

- `compileSdk = 36` (Android 16 — uses the newest build APIs)
- `targetSdk = 36` (Android 16 — meets the 2026 Play target requirement)
- `minSdk = flutter.minSdkVersion` = API 24 (verified in the clean smoke merged manifest)
- `compileOptions.isCoreLibraryDesugaringEnabled = true` (required for `flutter_local_notifications` on lower minSdk)
- `kotlinOptions.jvmTarget = JavaVersion.VERSION_17.toString()` (Java 17 toolchain)
- `productFlavors { play { ... }; smoke { applicationIdSuffix = ".smoke" } }` (Play and non-uploadable CI-smoke distributions)
- ProGuard `release` rules with `isMinifyEnabled = true` and `isShrinkResources = true`

Release artifact gate (also in `build.gradle.kts`): a Play release requires `ENV=production`, a RevenueCat `goog_` Android public SDK key, and release signing; `test_` Test Store, `sk_` server-secret, and placeholder values are rejected. A smoke release requires the distinct `ci_smoke` environment/sentinel and `.smoke` package. Unknown release distributions and debug-signing fallback are rejected.

### Android 15 (API 35) behavior changes — KoruBeni impact

| Change | Effect on KoruBeni | Action |
| --- | --- | --- |
| `BOOT_COMPLETED` cannot start several FGS types (developer.android.com/about/versions/15/behavior-changes-15) | Not applicable: KoruBeni does not start an FGS. Boot restore only re-arms persisted native alarms or handles an already-due active deadline. | Verify on Android 15 physical-device reboot/Doze QA. |
| `dataSync` FGS limited to 6 hours total per day | Not applicable — KoruBeni does not use `dataSync`. | None. |
| TLS 1.0/1.1 disallowed | RevenueCat and OSM endpoints are TLS 1.2+ by default. | None. |
| `PendingIntent.FLAG_IMMUTABLE` required on Android 12+; broadcast PendingIntents must declare mutability | Verified in the typed `AndroidEmergencySessionAlarmScheduler` exact/inexact PendingIntents. | Re-verify against the merged production manifest and physical API 31+ devices. |
| Edge-to-edge enforced for `targetSdk` >= 35 | Flutter handles this via `SystemUiOverlayStyle`; verify nav-bar overlap on real device. | NEEDS_REAL_DEVICE_TEST during QA. |

### Android 16 (API 36) behavior changes — current target

The app already compiles and targets API 36. Current considerations:

- Background work/FGS restrictions do not grant KoruBeni a keepalive path; the app intentionally has no custom FGS and native alarms own persisted safety deadlines.
- `BODY_SENSORS` is migrating to `android.permission.health.*` — KoruBeni does not request sensor permissions.
- Intent redirection hardening — `ACTION_DIAL` flow (used as CALL_PHONE fallback) is a system action; should remain compatible. Verify on real Android 16 device when available.
- Predictive back gesture — Flutter `Navigator` handles this in recent SDKs; no additional code required if Flutter version is current.

Recommendation: keep `targetSdk = 36`; re-run the Android 16 emulator/instrumentation suite and physical-device matrix for every platform/plugin upgrade.

### 16 KB page size readiness

Flutter native-library page-size alignment requires:

- Flutter SDK 3.27+ (re-aligns the bundled engine to 16 KB).
- AGP 8.5.1+ (already inherited via Flutter Gradle plugin).
- NDK r28+ (Flutter bundles this; do not pin an older NDK).
- All third-party native plugins compiled with 16 KB-aligned ELF segments.

KoruBeni's native plugin surface (from [`pubspec.yaml`](../pubspec.yaml)) and 16 KB status snapshot:

| Plugin | Native? | 16 KB note |
| --- | --- | --- |
| `geolocator: ^13.0.2` | Yes | 13.x compiled with 16 KB alignment per upstream. |
| `permission_handler: ^11.3.1` | Yes | 11.x supports 16 KB. |
| `flutter_local_notifications: ^17.2.1` | Yes | 17.x supports 16 KB. |
| `path_provider: ^2.1.4` | Yes | Supported. |
| `audioplayers: ^6.5.1` | Yes | 6.x supports 16 KB. |
| `flutter_map: ^7.0.2` | No (Dart-only canvas rendering) | Not applicable. |
| `purchases_flutter: ^8.10.1` | Yes | RevenueCat Android SDK 8.x supports 16 KB. |
| `flutter_jailbreak_detection: ^1.10.0` | Yes | Verify in Play Console "Memory page size" indicator. |
| `optimize_battery: ^0.0.4` | Likely Dart-only | Low risk. |
| `local_auth` | Not in pubspec (intentionally — biometric forbidden per CLAUDE.md) | N/A. |

### AAB verification checklist (post-upload)

In Play Console after uploading the AAB to an internal/closed track:

1. Open the bundle in "Latest releases and bundles".
2. In the bundle details, look for the "Memory page size" indicator. Expected: **"16 KB compatible"**.
3. If any native lib is flagged as non-compatible, the indicator will name the offending `.so` file.
4. Remediation: run `flutter pub upgrade --major-versions` to pull in the latest 16 KB-aligned plugin versions, then rebuild.

This is an OPERATOR_ACTION because the indicator is only visible post-upload to Play Console.
