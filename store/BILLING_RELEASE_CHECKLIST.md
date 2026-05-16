# RevenueCat / Google Play Billing Release Checklist

Status: REVENUECAT / PLAY_CONSOLE / NEEDS_REAL_DEVICE_TEST. This repo does not perform dashboard actions, tester purchases, signed uploads, or RevenueCat setup. Every external item remains `NOT_RUN` until evidence is supplied.

## Setup Gates

| ID | Gate | Item | Status | Evidence |
| --- | --- | --- | --- | --- |
| BILL-01 | PLAY_CONSOLE | Google Play app created for `com.poyrazoncel.korubeni` | NOT_RUN | Not supplied |
| BILL-02 | SIGNING | Signed AAB uploaded to internal/closed test track before Play Billing sandbox test | NOT_RUN | Not supplied |
| BILL-03 | PLAY_CONSOLE | License tester account added in Play Console | NOT_RUN | Not supplied |
| BILL-04 | PLAY_CONSOLE | Test device uses the intended Google account | NOT_RUN | Not supplied |
| BILL-05 | REVENUECAT | RevenueCat Android app configured for package `com.poyrazoncel.korubeni` | NOT_RUN | Not supplied |
| BILL-06 | REVENUECAT | RevenueCat service credentials configured | NOT_RUN | Not supplied |
| BILL-07 | REVENUECAT | Entitlement exactly matches app constant `KoruBeni Pro` (`RevenueCatService.entitlementId`) | NOT_RUN | Not supplied |
| BILL-08 | REVENUECAT | Current offering active | NOT_RUN | Not supplied |
| BILL-09 | REVENUECAT | Monthly package mapped | NOT_RUN | Not supplied |
| BILL-10 | REVENUECAT | Annual package mapped | NOT_RUN | Not supplied |
| BILL-11 | REVENUECAT | Product IDs remain dashboard-defined, not hardcoded in Dart | CODE_DONE | Paywall reads RevenueCat current offering packages |
| BILL-12 | SIGNING | Production RevenueCat Android API key supplied only through secure build env | NOT_RUN | Operator evidence required |

## Runtime Billing Tests

| ID | Gate | Item | Status | Evidence |
| --- | --- | --- | --- | --- |
| BILL-13 | REVENUECAT | Monthly purchase tested with license tester | NOT_RUN | Not supplied |
| BILL-14 | REVENUECAT | Annual purchase tested with license tester | NOT_RUN | Not supplied |
| BILL-15 | REVENUECAT | Restore active purchase tested | NOT_RUN | Not supplied |
| BILL-16 | REVENUECAT | Restore with no active purchase tested | NOT_RUN | Not supplied |
| BILL-17 | REVENUECAT | Cancel/manage subscription tested | NOT_RUN | Not supplied |
| BILL-18 | REVENUECAT | Expired/lapsed entitlement tested | NOT_RUN | Not supplied |
| BILL-19 | REVENUECAT | Renewal/lapse behavior tested in sandbox | NOT_RUN | Not supplied |
| BILL-20 | REVENUECAT | Account hold/paused tested if available | NOT_RUN | Not supplied |
| BILL-21 | REVENUECAT | No-offering fallback tested | NOT_RUN | Requires controlled RevenueCat setup or operator evidence |
| BILL-22 | REVENUECAT | Network failure fallback tested | NOT_RUN | Requires real build/runtime evidence |
| BILL-23 | NEEDS_REAL_DEVICE_TEST | Screenshots/video/evidence saved with PII redacted | NOT_RUN | Not supplied |

## Code-Side Safety

| ID | Gate | Item | Status | Evidence |
| --- | --- | --- | --- | --- |
| BILL-24 | CODE_DONE | Release code fails safely if production RevenueCat key is missing | CODE_DONE | `android/app/build.gradle.kts` and `AppEnvironment` require `REVENUECAT_ANDROID_API_KEY` for release |
| BILL-25 | CODE_DONE | Entitlement name centralized | CODE_DONE | `RevenueCatService.entitlementId` |
| BILL-26 | CODE_DONE | No billing secret committed | CODE_DONE | Final secret scan still required before release |
| BILL-27 | CODE_DONE | CI fallback key clearly non-release | CODE_DONE | PR/smoke workflow labels dummy-key artifacts `NON_RELEASE_SMOKE`; these artifacts must not be uploaded |

## Evidence Policy

- Emulator purchase flows are not accepted.
- Purchase, restore, cancel/manage, renewal/lapse, expired/lapsed, account hold/paused, no-offering, and network-failure evidence must come from Play internal/closed test tracks on real devices.
- Do not claim RevenueCat dashboard setup, Play Billing setup, or license-tester success without screenshots/logs from the relevant external system.
- Production readiness remains `NOT_READY` until every required `PLAY_CONSOLE`, `REVENUECAT`, `SIGNING`, and `NEEDS_REAL_DEVICE_TEST` billing gate has evidence.
