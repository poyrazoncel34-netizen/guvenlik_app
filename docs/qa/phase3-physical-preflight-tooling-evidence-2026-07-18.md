# Phase 3 — Physical Device Preflight Tooling Evidence (2026-07-18)

Scope: prevent a simulator, debug/test-only build, sideloaded APK, stale version
or wrongly signed candidate from being used as physical-device release evidence.
This is tooling evidence only; no physical-device scenario was executed.

## Result

**PASS_TOOLING_ONLY / NEEDS_REAL_DEVICE_TEST**

`scripts/phase3_physical_device_preflight.sh` now requires and verifies:

- an explicitly selected ADB target and a non-emulator kernel property;
- the production package `com.poyrazoncel.korubeni`;
- operator-declared `versionName` and numeric `versionCode`;
- absence of Android `DEBUGGABLE` and `TEST_ONLY` flags;
- Google Play (`com.android.vending`) as installer by default;
- the installed base APK certificate against the Play Console **app-signing**
  SHA-256 fingerprint, not the upload-certificate fingerprint;
- a non-identifying device label while deliberately omitting the ADB serial from
  the generated evidence file.

The script only reads device/build metadata and pulls the installed base APK to
a temporary directory for `apksigner` verification. It never launches the app,
changes permissions, places a call, kills a process, clears data, uninstalls the
package or reboots the device. Its success marker is deliberately
`PASS_PREFLIGHT_ONLY`, which cannot close any scenario row.

## Verification recorded at 2026-07-18 13:57 TRT

| Gate | Result |
| --- | --- |
| `bash -n scripts/phase3_physical_device_preflight.sh` | PASS |
| Missing-input fail-fast check | PASS — rejected before ADB access |
| Focused preflight/matrix/docs contract tests | PASS — 16/16 |
| `flutter analyze --no-pub` | PASS — zero issues |
| Full Flutter regression suite at this phase | PASS — 528/528 (historical; superseded by the Phase 5 ledger) |
| `git diff --check` | PASS before final evidence update |

At the probe time, `adb devices -l` returned no Android target. Therefore this
document proves only that the preflight gate is implemented and regression
tested. It does not prove telephony, SIM behavior, Doze, reboot, OEM battery
policy, permissions, notification visibility or billing on hardware.

Canonical execution instructions and scenario acceptance criteria remain in
`store/REAL_DEVICE_QA_MATRIX.md`.
