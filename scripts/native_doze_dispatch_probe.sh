#!/usr/bin/env bash
# Native Doze dispatch probe.
#
# Arms a real PANIC session through the production native kernel, turns the
# screen off, unplugs power, forces deep Doze, and records whether the alarm
# fired and the kernel reached Telecom. Flutter, billing and entitlement are
# not involved, so this runs on a build without a RevenueCat key.
#
# Scope (read before citing a PASS): the instrumentation keeps the app process
# alive for the whole wait. A PASS proves AlarmManager delivery under forced
# deep Doze plus native dispatch. It does NOT prove delivery after the process
# was killed, and on an emulator it says nothing about OEM battery managers.
#
# Emulator:  NATIVE_DOZE_CONFIRM_EMULATOR=1; target defaults to the non-contact
#            all-zero parser target.
# Physical:  NATIVE_DOZE_CONFIRM_PHYSICAL=1 and NATIVE_DOZE_TARGET=<a phone YOU
#            control>. A REAL CALL IS PLACED. The number is never written to
#            the evidence files.

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB_BIN="${ADB_BIN:-$HOME/Library/Android/sdk/platform-tools/adb}"
DEVICE_SERIAL="${ANDROID_SERIAL:-}"
APP_PACKAGE="com.poyrazoncel.korubeni"
TEST_PACKAGE="com.poyrazoncel.korubeni.test"
RUNNER="$TEST_PACKAGE/androidx.test.runner.AndroidJUnitRunner"
PROBE_CLASS="com.poyrazoncel.korubeni.emergency.NativeDozeDispatchProbeTest"
APP_APK="$PROJECT_ROOT/build/app/outputs/apk/play/debug/app-play-debug.apk"
TEST_APK="$PROJECT_ROOT/build/app/outputs/apk/androidTest/play/debug/app-play-debug-androidTest.apk"
DELAY_SECONDS="${NATIVE_DOZE_DELAY_SECONDS:-90}"
OUT_ROOT="${NATIVE_DOZE_EVIDENCE_DIR:-$PROJECT_ROOT/build/qa/native-doze}"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

dev() {
  "$ADB_BIN" -s "$DEVICE_SERIAL" "$@"
}

prop() {
  dev shell getprop "$1" | tr -d '\r'
}

[ -n "$DEVICE_SERIAL" ] || fail "set ANDROID_SERIAL to exactly one device"
[ -x "$ADB_BIN" ] || fail "adb not executable: $ADB_BIN"
[[ "$DELAY_SECONDS" =~ ^[0-9]+$ ]] && [ "$DELAY_SECONDS" -ge 30 ] && [ "$DELAY_SECONDS" -le 600 ] || \
  fail "NATIVE_DOZE_DELAY_SECONDS must be 30..600"

cd "$PROJECT_ROOT"
[ -z "$(git status --porcelain --untracked-files=all)" ] || \
  fail "source tree must be clean so the evidence names exactly one commit"
GIT_COMMIT="$(git rev-parse HEAD)"
STARTED_AT_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

dev wait-for-device
if [ "$(prop ro.kernel.qemu)" = "1" ]; then
  DEVICE_KIND="emulator"
  [ "${NATIVE_DOZE_CONFIRM_EMULATOR:-}" = "1" ] || \
    fail "set NATIVE_DOZE_CONFIRM_EMULATOR=1; this grants CALL_PHONE and exact alarms to KoruBeni on the emulator and places a call to the all-zero target"
  TARGET="${NATIVE_DOZE_TARGET:-0000000}"
else
  DEVICE_KIND="physical"
  [ "${NATIVE_DOZE_CONFIRM_PHYSICAL:-}" = "1" ] || \
    fail "set NATIVE_DOZE_CONFIRM_PHYSICAL=1; a REAL call is placed on this phone"
  TARGET="${NATIVE_DOZE_TARGET:-}"
  [ -n "$TARGET" ] || fail "physical device: set NATIVE_DOZE_TARGET to a phone you control"
  if [[ "$TARGET" =~ ^0+$ ]]; then
    fail "physical device: the all-zero target would reach a real carrier"
  fi
fi
# The target is interpolated into a device shell command: digits only.
[[ "$TARGET" =~ ^\+?[0-9]{3,20}$ ]] || fail "NATIVE_DOZE_TARGET must be 3-20 digits with an optional leading +"
if [[ "$TARGET" =~ ^0+$ ]]; then TARGET_KIND="all-zero"; else TARGET_KIND="explicit (redacted)"; fi

STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
OUT_DIR="$OUT_ROOT/$STAMP"
mkdir -p "$OUT_DIR"

INSTRUMENT_PID=""
TEST_INSTALLED=0
PROBE_COMPLETED=0
cleanup() {
  if [ -n "$INSTRUMENT_PID" ]; then kill "$INSTRUMENT_PID" >/dev/null 2>&1 || true; fi
  dev shell cmd deviceidle unforce >/dev/null 2>&1 || true
  dev shell dumpsys battery reset >/dev/null 2>&1 || true
  dev shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  dev shell input keyevent KEYCODE_ENDCALL >/dev/null 2>&1 || true
  if [ "$TEST_INSTALLED" = "1" ] && [ "$PROBE_COMPLETED" != "1" ]; then
    # Cancels a NOT-YET-DUE probe session left by an interrupted run. It cannot stop an
    # OVERDUE one: starting instrumentation un-stops the app, Android 15+ then delivers
    # LOCKED_BOOT_COMPLETED and reconcile dispatches it before this cancel runs
    # (observed on API 37, docs/audit/device-verification-2026-09-13-force-stop.md).
    dev shell am instrument -w -e nativeDozeProbe cancel \
      -e class "$PROBE_CLASS#cancelLeftoverProbeSession" "$RUNNER" \
      > "$OUT_DIR/cleanup-cancel.txt" 2>&1 || true
  fi
  dev uninstall "$TEST_PACKAGE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Always rebuild: evidence must come from a build of this exact commit (CERT2-05).
(cd android && ./gradlew app:assemblePlayDebug app:assemblePlayDebugAndroidTest --console=plain) \
  > "$OUT_DIR/gradle.log" 2>&1 || fail "gradle build failed; see $OUT_DIR/gradle.log"
[ -f "$APP_APK" ] || fail "app APK missing: $APP_APK"
[ -f "$TEST_APK" ] || fail "test APK missing: $TEST_APK"

dev install -r -t "$APP_APK" > "$OUT_DIR/install-app.txt" 2>&1 || \
  fail "app install failed ($(grep -m1 -oE 'INSTALL_FAILED_[A-Z_]+|not enough space|signatures do not match' "$OUT_DIR/install-app.txt" || echo 'see log')); nothing is uninstalled automatically; see $OUT_DIR/install-app.txt"
dev install -r -t "$TEST_APK" > "$OUT_DIR/install-test.txt" 2>&1 || fail "test APK install failed"
TEST_INSTALLED=1

API_LEVEL="$(prop ro.build.version.sdk)"
dev shell pm grant "$APP_PACKAGE" android.permission.CALL_PHONE
if [ "$API_LEVEL" -ge 33 ]; then dev shell pm grant "$APP_PACKAGE" android.permission.POST_NOTIFICATIONS; fi
if [ "$API_LEVEL" -ge 31 ]; then dev shell appops set "$APP_PACKAGE" SCHEDULE_EXACT_ALARM allow; fi

LAST_UPDATE="$(dev shell dumpsys package "$APP_PACKAGE" | grep -m1 'lastUpdateTime' | tr -d '\r' | sed 's/^ *//')"
WHITELISTED="$(dev shell cmd deviceidle whitelist | grep -c "$APP_PACKAGE" || true)"
dev shell cmd deviceidle unforce >/dev/null 2>&1 || true
dev logcat -c

dev shell am instrument -w \
  -e nativeDozeProbe run \
  -e nativeDozeTarget "$TARGET" \
  -e nativeDozeDelaySeconds "$DELAY_SECONDS" \
  -e class "$PROBE_CLASS#armWaitForDozeAndRecordDispatch" \
  "$RUNNER" > "$OUT_DIR/instrument.txt" 2>&1 &
INSTRUMENT_PID=$!

ARMED=0
for _ in $(seq 1 60); do
  if dev logcat -d -s NativeDozeProbe:I | grep -q "ARMED"; then ARMED=1; break; fi
  kill -0 "$INSTRUMENT_PID" >/dev/null 2>&1 || break
  sleep 1
done
[ "$ARMED" = "1" ] || fail "probe did not arm; see $OUT_DIR/instrument.txt"
ARMED_AT_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

dev shell dumpsys battery unplug
dev shell input keyevent KEYCODE_SLEEP
sleep 2
dev shell cmd deviceidle force-idle > "$OUT_DIR/force-idle.txt" 2>&1
DEEP_AFTER_FORCE="$(dev shell cmd deviceidle get deep | tr -d '\r')"
WAKEFULNESS="$(dev shell dumpsys power | grep -m1 'mWakefulness=' | tr -d '\r' | sed 's/^ *//')"
[ "$DEEP_AFTER_FORCE" = "IDLE" ] || fail "device did not enter deep idle (state=$DEEP_AFTER_FORCE)"

MAX_SAMPLES=$(( (DELAY_SECONDS + 300) / 5 ))
SAMPLES=0
while kill -0 "$INSTRUMENT_PID" >/dev/null 2>&1; do
  printf '%s deep=%s\n' "$(date -u '+%H:%M:%S')" "$(dev shell cmd deviceidle get deep | tr -d '\r')" \
    >> "$OUT_DIR/deep-idle-samples.txt"
  SAMPLES=$((SAMPLES + 1))
  [ "$SAMPLES" -le "$MAX_SAMPLES" ] || fail "probe exceeded its time budget"
  sleep 5
done
wait "$INSTRUMENT_PID" || true
INSTRUMENT_PID=""

dev logcat -d -s NativeDozeProbe:I > "$OUT_DIR/probe-logcat.txt" 2>&1 || true
RESULT_LINE="$(grep -m1 'RESULT ' "$OUT_DIR/probe-logcat.txt" | sed 's/.*RESULT /RESULT /' || true)"
[ -n "$RESULT_LINE" ] || fail "no RESULT line (arm refused or probe skipped); see $OUT_DIR/instrument.txt"
grep -q "OK (1 test)" "$OUT_DIR/instrument.txt" || fail "probe assertion failed: $RESULT_LINE"
PROBE_COMPLETED=1

{
  echo "probe=native-doze-dispatch"
  echo "commit=$GIT_COMMIT"
  echo "started_at_utc=$STARTED_AT_UTC"
  echo "armed_at_utc=$ARMED_AT_UTC"
  echo "finished_at_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "device_kind=$DEVICE_KIND"
  echo "avd_name=$(prop ro.boot.qemu.avd_name)"
  echo "manufacturer=$(prop ro.product.manufacturer)"
  echo "model=$(prop ro.product.model)"
  echo "api_level=$API_LEVEL"
  echo "build_fingerprint=$(prop ro.build.fingerprint)"
  echo "density=$(dev shell wm density | tr -d '\r' | tr '\n' ' ')"
  echo "app_apk_sha256=$(shasum -a 256 "$APP_APK" | awk '{print $1}')"
  echo "test_apk_sha256=$(shasum -a 256 "$TEST_APK" | awk '{print $1}')"
  echo "installed_$LAST_UPDATE"
  echo "battery_optimization_whitelisted=$WHITELISTED"
  echo "delay_seconds=$DELAY_SECONDS"
  echo "target_kind=$TARGET_KIND"
  echo "deep_idle_after_force=$DEEP_AFTER_FORCE"
  echo "wakefulness_after_sleep=$WAKEFULNESS"
  echo "deep_idle_samples=$(wc -l < "$OUT_DIR/deep-idle-samples.txt" | tr -d ' ')"
  echo "deep_idle_samples_not_idle=$(grep -vc 'deep=IDLE' "$OUT_DIR/deep-idle-samples.txt" || true)"
  echo "$RESULT_LINE"
} > "$OUT_DIR/evidence.txt"

printf 'PASS: native alarm fired under forced deep Doze and the kernel attempted the call.\n'
printf '%s\n' "$RESULT_LINE"
printf 'EVIDENCE: %s\n' "$OUT_DIR/evidence.txt"
