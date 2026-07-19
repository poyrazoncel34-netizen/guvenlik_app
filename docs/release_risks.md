# Release Risks

## OpenStreetMap Tiles

The default map template is
`https://tile.openstreetmap.org/{z}/{x}/{y}.png`. Attribution and a stable
package/contact User-Agent are present. The exact public OSM endpoint is routed
through an app-private persistent HTTP cache that honors
`Cache-Control`/`Age`/`Expires`/`ETag`/`Last-Modified`, falls back to seven days
when no usable lifetime is supplied, and is bounded to 128 MiB. Expired,
orphaned, oversized, or body/metadata-mismatched entries are removed; concurrent
requests for one tile are coalesced. The cache never prefetches.

**Release status: `OSM_TILE_LOCAL_CONTROLS_PASS`,
`NETWORK_CAPTURE_AND_COUNSEL_UNVERIFIED`.** Repository behavior tests close the
missing-local-cache implementation gap. They do not prove the exact AAB's live
request headers, provider-side retention, availability, or KVKK Article 9
mechanism. A non-default `MAP_TILE_URL_TEMPLATE` deliberately bypasses this
OSM-specific cache and requires a candidate-bound provider contract, cache, and
network-capture review before release.

Current mitigation:
- OSM attribution is shown in the map UI.
- `userAgentPackageName` includes a contact channel (`com.poyrazoncel.korubeni; +korubeni.destek@gmail.com`) per OSMF "highly recommended" guidance.
- The app only requests tiles for the map viewport the user actively opens.
- The app must not bulk download, scrape, pre-seed, cache as an offline archive, or package OpenStreetMap public tiles.
- Provider HTTP lifetimes are honored; absent usable directives, cached tiles
  remain reusable for seven days. Local app-data reset removes the cache.
- Store/legal copy does not claim enterprise-grade map reliability.

These repository-local controls do not substitute for candidate network capture
or counsel review. Source:
https://operations.osmfoundation.org/policies/tiles/

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
- Production is DO_NOT_CLAIM_READY until Play Console forms, billing tests, the declared API 29–36 physical-device/OEM matrix, screenshot PII review, and the mandatory KoruBeni 12-tester/14-day closed soak are complete for one immutable AAB.

## Android 15 / Android 16 / 16 KB Page Size Readiness

### Target API timeline (Play Console)

| Date | Requirement | Source |
| --- | --- | --- |
| 31 August 2025 | New apps + updates must target API 35 (Android 15) | https://support.google.com/googleplay/android-developer/answer/11926878 |
| 1 November 2025 | New apps and updates submitted to Play and targeting Android 15+ must support 16 KB page sizes | https://developer.android.com/guide/practices/page-sizes |
| 31 August 2026 | New apps and updates must target API 36 (Android 16); Play documents an extension path to 1 November 2026 | https://support.google.com/googleplay/android-developer/answer/11926878 |

### Current build configuration

From [`android/app/build.gradle.kts`](../android/app/build.gradle.kts):

- `compileSdk = 36` (Android 16 — uses the newest build APIs)
- `targetSdk = 36` (Android 16 — meets the 2026 Play target requirement)
- `minSdk = 29` (the locked first-release support floor; verified by build config and merged-manifest audit)
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

Android's current primary guidance recommends AGP 8.5.1 or newer and NDK r28
or newer so newly compiled libraries receive compatible packaging/alignment by
default. That does **not** prove prebuilt SDK libraries are compatible; every
ELF in the exact candidate must still be inspected.

Current local evidence is deliberately narrower:

- `verify_release.sh` built a `NON_RELEASE_SMOKE` AAB and inspected every
  64-bit native library's `PT_LOAD` alignment.
- Result for that smoke artifact: **10/10** libraries passed (five arm64-v8a,
  five x86_64).
- The smoke application id ends in `.smoke`, includes x86_64, and is not
  uploadable to the production Play app. It is **not production-candidate
  evidence**.
- The production gate remains open until the exact arm64 Play AAB reports
  `PAGE_ALIGNMENT_16K`, generated APKs pass `zipalign -c -P 16`, the Play Bundle
  Explorer reports 16 KB compatibility, and a real 16 KB-kernel device runs
  with compatibility mode disabled.

### AAB verification checklist (post-upload)

In Play Console after uploading the AAB to an internal/closed track:

1. Open the bundle in "Latest releases and bundles".
2. In the bundle details, look for the "Memory page size" indicator. Expected: **"16 KB compatible"**.
3. If any native lib is flagged as non-compatible, the indicator will name the offending `.so` file.
4. If a library is flagged, identify its owning SDK, update or rebuild that
   dependency in isolation, then invalidate and repeat build/security/OEM
   evidence. Do not bulk-upgrade the graph inside an active candidate.

This is an OPERATOR_ACTION because the indicator is only visible post-upload to Play Console.
