# RevenueCat / Google Play Billing Release Checklist

Do not perform dashboard actions from this repo audit. Every dashboard, tester, purchase, restore, cancel/manage, or production-key verification item is OPERATOR_ACTION until external evidence is supplied.

## Required Setup

| ID | Item | Status | Evidence |
| --- | --- | --- | --- |
| BILL-01 | Play Console monthly subscription product exists | OPERATOR_ACTION | Not supplied |
| BILL-02 | Play Console annual subscription product exists | OPERATOR_ACTION | Not supplied |
| BILL-03 | RevenueCat Android app configured with package `com.poyrazoncel.korubeni` | OPERATOR_ACTION | Not supplied |
| BILL-04 | RevenueCat entitlement exactly `KoruBeni Pro` | OPERATOR_ACTION | Not supplied |
| BILL-05 | RevenueCat current offering exists | OPERATOR_ACTION | Not supplied |
| BILL-06 | Current offering contains monthly package | OPERATOR_ACTION | Not supplied |
| BILL-07 | Current offering contains annual package | OPERATOR_ACTION | Not supplied |
| BILL-08 | App paywall shows Play products | OPERATOR_ACTION | Requires Play/internal track build and license tester |
| BILL-09 | Production RevenueCat key is not empty in operator release build | OPERATOR_ACTION | Do not commit key |
| BILL-10 | No dummy/CI RevenueCat key is used in release | OPERATOR_ACTION | Verify build defines and artifact provenance |

## Required Billing Tests

| ID | Item | Status | Evidence |
| --- | --- | --- | --- |
| BILL-11 | Monthly purchase tested with license tester | OPERATOR_ACTION | Not tested in repo |
| BILL-12 | Annual purchase tested with license tester | OPERATOR_ACTION | Not tested in repo |
| BILL-13 | Restore tested with same Google account | OPERATOR_ACTION | Not tested in repo |
| BILL-14 | Cancel/manage subscription tested | OPERATOR_ACTION | Not tested in repo |
| BILL-15 | Expired/lapsed/paused behavior tested if available | OPERATOR_ACTION | Not tested in repo |
| BILL-16 | No-offering fallback tested | OPERATOR_ACTION | Requires controlled RevenueCat/Play setup or operator evidence |
| BILL-17 | Network failure fallback tested | OPERATOR_ACTION | Requires real build/runtime evidence |

## Code-Side Safety

| ID | Item | Status | Evidence |
| --- | --- | --- | --- |
| BILL-18 | Release code fails safely if production RevenueCat key is missing | CODE_DONE | `android/app/build.gradle.kts` requires `REVENUECAT_ANDROID_API_KEY`; `lib/core/config/app_environment.dart` validates release config. |
| BILL-19 | No billing secret is committed | CODE_DONE | Secret-like baseline scan found placeholders/env names only; rerun final scan before release. |

## Runtime Evidence Policy

- Emulator purchase flows are not accepted.
- adb/device install/runtime execution was not performed in this audit.
- Play Billing must be validated through Play internal/closed test tracks and license testers before production.
- Production submission remains NOT READY until BILL-01 through BILL-17 are evidenced PASS where applicable.
