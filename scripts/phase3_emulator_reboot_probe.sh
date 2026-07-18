#!/usr/bin/env bash
# Real BOOT_COMPLETED restoration probe for an EPHEMERAL Android emulator.
# A non-contact all-zero parser target is persisted only on an explicitly
# confirmed ephemeral emulator; cleanup uninstalls both packages on every exit.

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB_BIN="${ADB_BIN:-/Users/poyrazoncel/Library/Android/sdk/platform-tools/adb}"
DEVICE_SERIAL="${ANDROID_SERIAL:-}"
APP_PACKAGE="com.poyrazoncel.korubeni"
TEST_PACKAGE="com.poyrazoncel.korubeni.test"
RUNNER="$TEST_PACKAGE/androidx.test.runner.AndroidJUnitRunner"
PROBE_CLASS="com.poyrazoncel.korubeni.emergency.Phase3RebootProbeTest"
APP_APK="$PROJECT_ROOT/build/app/outputs/apk/play/debug/app-play-debug.apk"
TEST_APK="$PROJECT_ROOT/build/app/outputs/apk/androidTest/play/debug/app-play-debug-androidTest.apk"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -n "$DEVICE_SERIAL" ] || fail "set ANDROID_SERIAL to a dedicated ephemeral emulator"
[ "${PHASE3_CONFIRM_EPHEMERAL_AVD:-}" = "1" ] || \
  fail "set PHASE3_CONFIRM_EPHEMERAL_AVD=1; this probe uninstalls KoruBeni from the selected emulator"
[ -x "$ADB_BIN" ] || fail "adb not executable: $ADB_BIN"

"$ADB_BIN" -s "$DEVICE_SERIAL" wait-for-device
QEMU_FLAG="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.kernel.qemu | tr -d '\r')"
[ "$QEMU_FLAG" = "1" ] || fail "refusing non-emulator device: $DEVICE_SERIAL"

cleanup() {
  "$ADB_BIN" -s "$DEVICE_SERIAL" shell cmd deviceidle unforce >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$DEVICE_SERIAL" uninstall "$TEST_PACKAGE" >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$DEVICE_SERIAL" uninstall "$APP_PACKAGE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "$PROJECT_ROOT/android"
./gradlew app:assemblePlayDebug app:assemblePlayDebugAndroidTest --console=plain
[ -f "$APP_APK" ] || fail "target APK missing: $APP_APK"
[ -f "$TEST_APK" ] || fail "test APK missing: $TEST_APK"

"$ADB_BIN" -s "$DEVICE_SERIAL" install -r -t "$APP_APK"
"$ADB_BIN" -s "$DEVICE_SERIAL" install -r -t "$TEST_APK"

run_probe() {
  local mode="$1"
  local method="$2"
  local output
  output="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell am instrument -w \
    -e phase3Probe "$mode" \
    -e class "$PROBE_CLASS#$method" \
    "$RUNNER" 2>&1)"
  printf '%s\n' "$output"
  [[ "$output" == *"OK (1 test)"* ]] || fail "$mode instrumentation probe failed"
}

# A freshly installed package starts FLAG_STOPPED. Launching the real activity
# once is an explicit user-equivalent start and makes BOOT_COMPLETED eligibility
# testable; the probe then clears/arms only its own native prefs.
"$ADB_BIN" -s "$DEVICE_SERIAL" shell am start -W \
  -n "$APP_PACKAGE/.MainActivity" >/dev/null
run_probe arm armTypedSessionForRealReboot

# AndroidJUnitRunner force-stops its target when instrumentation finishes. A
# stopped package cannot receive BOOT_COMPLETED, so remove only that package
# state without launching app code or changing the armed native preferences.
"$ADB_BIN" -s "$DEVICE_SERIAL" shell cmd package unstop \
  --user current "$APP_PACKAGE"
"$ADB_BIN" -s "$DEVICE_SERIAL" shell cmd package wait-for-handler \
  --timeout 10000

"$ADB_BIN" -s "$DEVICE_SERIAL" reboot
"$ADB_BIN" -s "$DEVICE_SERIAL" wait-for-device

BOOT_COMPLETED=""
for _ in $(seq 1 90); do
  BOOT_COMPLETED="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop sys.boot_completed | tr -d '\r')"
  [ "$BOOT_COMPLETED" = "1" ] && break
  sleep 2
done
[ "$BOOT_COMPLETED" = "1" ] || fail "emulator did not finish boot within 180 seconds"

"$ADB_BIN" -s "$DEVICE_SERIAL" shell input keyevent 82 >/dev/null 2>&1 || true
"$ADB_BIN" -s "$DEVICE_SERIAL" shell am wait-for-broadcast-idle

run_probe verify verifyManifestBootReceiverRestoredTypedSession

printf 'PASS: real emulator reboot delivered BOOT_COMPLETED and restored typed safety state.\n'
