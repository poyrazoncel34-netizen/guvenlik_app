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
| Android 13 physical device | NEEDS_REAL_DEVICE_TEST |
| Android 14 physical device | NEEDS_REAL_DEVICE_TEST |
| Android 15 physical device | Optional but recommended |
| Aggressive OEM battery device such as Samsung/Xiaomi/Oppo | Optional but recommended |

## Required Flow Groups

- Fresh install and first-run legal/PIN flow.
- TR and EN locale review, including native notification copy.
- Notification, location, exact alarm, and battery optimization denied/degraded paths.
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
- Closed testing tester opt-in when applicable.

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
