# Phase 3 Android Emulator Evidence — 2026-07-17

Status: `PASS_EMULATOR_ONLY`

This record is reproducible engineering evidence, not physical-device or
production-track evidence. The repository baseline was commit `7a5418d` plus
the uncommitted Phase 1–3 changes listed by `git status` at execution time.

## Environment

- Dedicated disposable AVD: `KoruBeni_Phase3_API36`
- Android API: 36 (Android 16)
- Serial used: `emulator-5556`
- Variant: `playDebug`
- Callable test target: none. Reboot/Doze probes deliberately persist an empty
  or non-callable target, so the automated suite cannot place a real call.

## Evidence 1 — instrumentation and forced Doze

Command:

```sh
ANDROID_SERIAL=emulator-5556 ./gradlew app:connectedPlayDebugAndroidTest --console=plain
```

Observed result:

- Gradle: `BUILD SUCCESSFUL`
- Runner discovered the normal emergency-alarm suite plus the two-stage reboot
  probe methods.
- The two reboot probe methods were skipped by design in the ordinary connected
  run because they require an actual reboot between stages.
- All ordinary instrumentation tests passed, including the exact countdown
  backup while the emulator was forced into device idle (Doze).
- The Doze test asserted that the native alarm was delivered and that an empty
  target could not be dialed.

## Evidence 2 — actual reboot and BOOT_COMPLETED restoration

Command:

```sh
ANDROID_SERIAL=emulator-5556 \
PHASE3_CONFIRM_EPHEMERAL_AVD=1 \
bash scripts/phase3_emulator_reboot_probe.sh
```

Observed result:

```text
OK (1 test)
Package com.poyrazoncel.korubeni new stopped state: false
Success
All broadcast queues are idle!
OK (1 test)
PASS: real emulator reboot delivered BOOT_COMPLETED and restored countdown state.
```

What the probe proves:

1. It refuses a non-emulator device and requires an explicit disposable-AVD
   confirmation.
2. It installs the app and test APK, starts the app once to remove the fresh
   install stopped state, and arms only native emergency preferences.
3. Because AndroidJUnitRunner force-stops its target after instrumentation, the
   script explicitly removes that test-harness stopped state.
4. It waits for PackageManager's handler queue so the stopped-state change is
   durable before reboot.
5. It performs a real `adb reboot`, waits for boot and broadcast queues, then
   verifies that the manifest `BOOT_COMPLETED` receiver reconstructed a future
   elapsed-realtime deadline from the persisted wall-clock deadline.
6. It cleans both packages from the disposable emulator on exit.

## What this does not prove

This evidence does **not** close any `NEEDS_REAL_DEVICE_TEST` cell in
`store/REAL_DEVICE_QA_MATRIX.md`. In particular it does not prove:

- a real telephony call reaches a second phone;
- Android background-activity-launch visibility on a physical device;
- Samsung One UI or Xiaomi HyperOS battery/autostart behavior;
- secure lock-screen notification rendering on OEM skins;
- R8 behavior of the signed release delivered by Play internal testing;
- RevenueCat/Google Play purchase, restore, lapse, or license-tester behavior.

Those remain release gates, not paperwork. A green emulator suite can reject a
bad build; it cannot certify the OEM/telephony/billing paths of a good build.
