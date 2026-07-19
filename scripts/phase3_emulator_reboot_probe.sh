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
EVIDENCE_OUTPUT="${PHASE3_EVIDENCE_OUTPUT:-$PROJECT_ROOT/build/release-evidence/phase3-emulator-reboot.json}"
EVIDENCE_WRITER="$PROJECT_ROOT/scripts/write_phase3_emulator_evidence.py"
# PackageManager batches package-restriction writes (including FLAG_STOPPED).
# Give the delayed write time to run before a hard reboot, then flush it.
PACKAGE_STATE_FLUSH_SECONDS=12

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -n "$DEVICE_SERIAL" ] || fail "set ANDROID_SERIAL to a dedicated ephemeral emulator"
[ "${PHASE3_CONFIRM_EPHEMERAL_AVD:-}" = "1" ] || \
  fail "set PHASE3_CONFIRM_EPHEMERAL_AVD=1; this probe uninstalls KoruBeni from the selected emulator"
[ -x "$ADB_BIN" ] || fail "adb not executable: $ADB_BIN"
[ -f "$EVIDENCE_WRITER" ] || fail "evidence writer missing: $EVIDENCE_WRITER"

cd "$PROJECT_ROOT"
SOURCE_STATUS="$(git status --porcelain --untracked-files=all)"
[ -z "$SOURCE_STATUS" ] || fail "source tree must be clean before running candidate evidence"
GIT_COMMIT="$(git rev-parse HEAD)"
GIT_TREE="$(git rev-parse 'HEAD^{tree}')"
STARTED_AT_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

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
APP_APK_SHA256="$(shasum -a 256 "$APP_APK" | awk '{print $1}')"
TEST_APK_SHA256="$(shasum -a 256 "$TEST_APK" | awk '{print $1}')"

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

make_boot_eligible_after_instrumentation() {
  # AndroidJUnitRunner force-stops its target. Re-launching the real Activity
  # is the portable API 29-36, user-equivalent way to clear FLAG_STOPPED;
  # API 34 and below do not expose API 36's shell-only unstop command.
  "$ADB_BIN" -s "$DEVICE_SERIAL" shell am start -W \
    -n "$APP_PACKAGE/.MainActivity" >/dev/null
  "$ADB_BIN" -s "$DEVICE_SERIAL" shell input keyevent KEYCODE_HOME >/dev/null

  local package_state
  package_state="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell dumpsys package "$APP_PACKAGE")"
  [[ "$package_state" == *"stopped=false"* ]] || \
    fail "target package remained stopped after instrumentation"
  [[ "$package_state" == *"notLaunched=false"* ]] || \
    fail "target package is not BOOT_COMPLETED eligible"

  # wait-for-handler alone can overtake PackageManager's delayed restrictions
  # write. Waiting past that delay avoids a test-only reboot race seen on the
  # API 36 16 KB image; a real armed app is already running and not stopped.
  sleep "$PACKAGE_STATE_FLUSH_SECONDS"
  "$ADB_BIN" -s "$DEVICE_SERIAL" shell cmd package wait-for-handler \
    --timeout 10000
  "$ADB_BIN" -s "$DEVICE_SERIAL" shell sync
}

read_avd_name() {
  local property_name
  property_name="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.boot.qemu.avd_name | tr -d '\r')"
  if [ -n "$property_name" ]; then
    printf '%s\n' "$property_name"
    return
  fi
  # API 29 does not publish ro.boot.qemu.avd_name. The emulator console is
  # authoritative for the selected AVD and returns its name on the first line.
  "$ADB_BIN" -s "$DEVICE_SERIAL" emu avd name | tr -d '\r' | sed -n '1p'
}

# A freshly installed package starts FLAG_STOPPED. Launching the real activity
# once is an explicit user-equivalent start and makes BOOT_COMPLETED eligibility
# testable; the probe then clears/arms only its own native prefs.
"$ADB_BIN" -s "$DEVICE_SERIAL" shell am start -W \
  -n "$APP_PACKAGE/.MainActivity" >/dev/null
run_probe arm armTypedSessionForRealReboot

make_boot_eligible_after_instrumentation

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

cleanup
trap - EXIT
"$ADB_BIN" -s "$DEVICE_SERIAL" shell pm path "$TEST_PACKAGE" 2>&1 | \
  grep -q '^package:' && fail "test package cleanup failed"
"$ADB_BIN" -s "$DEVICE_SERIAL" shell pm path "$APP_PACKAGE" 2>&1 | \
  grep -q '^package:' && fail "app package cleanup failed"

AVD_NAME="$(read_avd_name)"
[ -n "$AVD_NAME" ] || fail "emulator AVD name is unavailable"
API_LEVEL="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')"
ANDROID_RELEASE="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.build.version.release | tr -d '\r')"
ABI="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.product.cpu.abi | tr -d '\r')"
MANUFACTURER="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.product.manufacturer | tr -d '\r')"
MODEL="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.product.model | tr -d '\r')"
BUILD_FINGERPRINT="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.build.fingerprint | tr -d '\r')"
PAGE_SIZE_BYTES="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getconf PAGESIZE | tr -d '\r')"
FINISHED_AT_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

python3 "$EVIDENCE_WRITER" \
  --output "$EVIDENCE_OUTPUT" \
  --git-commit "$GIT_COMMIT" \
  --git-tree "$GIT_TREE" \
  --app-apk-sha256 "$APP_APK_SHA256" \
  --test-apk-sha256 "$TEST_APK_SHA256" \
  --serial "$DEVICE_SERIAL" \
  --avd-name "$AVD_NAME" \
  --api-level "$API_LEVEL" \
  --android-release "$ANDROID_RELEASE" \
  --abi "$ABI" \
  --manufacturer "$MANUFACTURER" \
  --model "$MODEL" \
  --build-fingerprint "$BUILD_FINGERPRINT" \
  --page-size-bytes "$PAGE_SIZE_BYTES" \
  --started-at-utc "$STARTED_AT_UTC" \
  --finished-at-utc "$FINISHED_AT_UTC"

printf 'PASS: real emulator reboot delivered BOOT_COMPLETED and restored typed safety state.\n'
printf 'EVIDENCE: %s\n' "$EVIDENCE_OUTPUT"
