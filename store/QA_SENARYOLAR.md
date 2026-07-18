# KoruBeni QA Scenarios

Canonical real-device release matrix: `store/REAL_DEVICE_QA_MATRIX.md`.

This file is a summary only. Production readiness must be based on the matrix rows, actual result, evidence, severity, and PASS/FAIL/BLOCKED/NOT_RUN status.

## Runtime Evidence Rule

- Emulator evidence is not accepted as substitute release evidence.
- adb, device install/run, `flutter run`, `flutter drive`, patrol, and live Play Billing flows were not executed in this audit.
- All runtime QA is NEEDS_REAL_DEVICE_TEST until performed by an operator on physical Android hardware.

## Required Device Coverage

| Device set | Status |
| --- | --- |
| API 29 arm64 boundary phone | NEEDS_REAL_DEVICE_TEST |
| API 36 Pixel/AOSP, 16 KB kernel | NEEDS_REAL_DEVICE_TEST |
| Samsung One UI API 34/35+ | NEEDS_REAL_DEVICE_TEST |
| Xiaomi/HyperOS API 34/35+ | NEEDS_REAL_DEVICE_TEST |
| Dual-SIM + low-memory coverage | NEEDS_REAL_DEVICE_TEST |
| Aggressive OEM battery device such as Samsung/Xiaomi/Oppo | Optional but recommended |

## Required Flow Groups

- Fresh install and first-run legal/PIN flow.
- TR and EN locale review, including native notification copy.
- Notification/location denial, exact-alarm fail-closed arming, post-arm
  revocation backup, and optional battery-exemption paths.
- Safe Walk start/stop/timeout.
- Check-in start/expiry/grace period.
- Emergency dispatch, Panic/SOS permission granted and denied paths, and `ACTION_DIAL` fallback.
- Boot during active session and app killed during active session.
- Siren loudness and volume restore.
- Fake call immediate and delayed.
- Contact picker.
- Map offline/fallback.
- Data export and data deletion.
- Android notification settings showing only canonical safety channels.
- Paywall no-offering fallback, monthly purchase, annual purchase, restore, and cancel/manage subscription.
- Play Console tester opt-in for billing/runtime QA. Closed testing production access is account-dependent and must be checked on the Play Console production access screen; if the personal-account rule applies, track 12 opted-in testers for 14 continuous days.

## Screenshot / Store QA

Canonical screenshot upload path: `store/screenshots/android/final/`.

Before upload, operator must verify:

- no real names
- no real phone numbers
- no real emails
- no precise home/work address
- no sensitive map coordinates
- no private account data
- no accidental personal profile info

Status remains NOT_RUN until evidence is supplied in `store/REAL_DEVICE_QA_MATRIX.md` or an external QA record.
