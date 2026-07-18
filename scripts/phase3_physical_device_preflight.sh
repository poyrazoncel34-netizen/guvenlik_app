#!/usr/bin/env bash
# Read-only, call-free preflight for Phase 3 physical-device QA.
# This proves the selected hardware/build identity only. It never marks a
# REAL_DEVICE_QA_MATRIX scenario as passed.

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PACKAGE="com.poyrazoncel.korubeni"
DEVICE_SERIAL="${ANDROID_SERIAL:-}"
DEVICE_LABEL="${PHASE3_DEVICE_LABEL:-}"
EXPECTED_VERSION_NAME="${EXPECTED_VERSION_NAME:-}"
EXPECTED_VERSION_CODE="${EXPECTED_VERSION_CODE:-}"
EXPECTED_CERT_SHA256="${EXPECTED_APP_SIGNING_SHA256:-}"
EVIDENCE_DIR="${PHASE3_EVIDENCE_DIR:-$PROJECT_ROOT/build/qa/phase3-physical}"
ALLOW_NON_PLAY_INSTALL="${PHASE3_ALLOW_NON_PLAY_INSTALL:-0}"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

normalize_digest() {
  printf '%s' "$1" | tr -d '[:space:]:' | tr '[:upper:]' '[:lower:]'
}

single_line() {
  printf '%s' "$1" | tr '\r\n|' '   '
}

resolve_adb() {
  if [ -n "${ADB_BIN:-}" ]; then
    printf '%s' "$ADB_BIN"
    return
  fi
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return
  fi
  local macos_adb="${HOME:-}/Library/Android/sdk/platform-tools/adb"
  [ -x "$macos_adb" ] || fail "adb not found; set ADB_BIN"
  printf '%s' "$macos_adb"
}

resolve_apksigner() {
  if [ -n "${APKSIGNER_BIN:-}" ]; then
    printf '%s' "$APKSIGNER_BIN"
    return
  fi

  local sdk_root candidate
  for sdk_root in \
    "${ANDROID_SDK_ROOT:-}" \
    "${ANDROID_HOME:-}" \
    "${HOME:-}/Library/Android/sdk"; do
    [ -d "$sdk_root/build-tools" ] || continue
    candidate="$(find "$sdk_root/build-tools" -maxdepth 2 -type f \
      -name apksigner | sort | tail -n 1)"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s' "$candidate"
      return
    fi
  done
  fail "apksigner not found; set APKSIGNER_BIN"
}

[ -n "$DEVICE_SERIAL" ] || fail "set ANDROID_SERIAL to one physical Android device"
[ -n "$DEVICE_LABEL" ] || fail "set PHASE3_DEVICE_LABEL (for example PIX-01)"
[[ "$DEVICE_LABEL" =~ ^[A-Za-z0-9._-]+$ ]] || \
  fail "PHASE3_DEVICE_LABEL may contain only letters, digits, dot, underscore and dash"
[ -n "$EXPECTED_VERSION_NAME" ] || fail "set EXPECTED_VERSION_NAME"
[[ "$EXPECTED_VERSION_CODE" =~ ^[0-9]+$ ]] || fail "set numeric EXPECTED_VERSION_CODE"
[ -n "$EXPECTED_CERT_SHA256" ] || fail "set EXPECTED_APP_SIGNING_SHA256 from Play Console"
EXPECTED_CERT_SHA256="$(normalize_digest "$EXPECTED_CERT_SHA256")"
[[ "$EXPECTED_CERT_SHA256" =~ ^[0-9a-f]{64}$ ]] || \
  fail "EXPECTED_APP_SIGNING_SHA256 must be a 64-hex SHA-256 digest"
[ "$ALLOW_NON_PLAY_INSTALL" = "0" ] || [ "$ALLOW_NON_PLAY_INSTALL" = "1" ] || \
  fail "PHASE3_ALLOW_NON_PLAY_INSTALL must be 0 or 1"

ADB_BIN="$(resolve_adb)"
APKSIGNER_BIN="$(resolve_apksigner)"
[ -x "$ADB_BIN" ] || fail "adb not executable: $ADB_BIN"
[ -x "$APKSIGNER_BIN" ] || fail "apksigner not executable: $APKSIGNER_BIN"

"$ADB_BIN" -s "$DEVICE_SERIAL" wait-for-device
[ "$("$ADB_BIN" -s "$DEVICE_SERIAL" get-state | tr -d '\r')" = "device" ] || \
  fail "selected Android target is not ready"

get_prop() {
  "$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop "$1" | tr -d '\r'
}

QEMU_FLAG="$(get_prop ro.kernel.qemu)"
[ "$QEMU_FLAG" != "1" ] || fail "refusing emulator target: $DEVICE_SERIAL"

MANUFACTURER="$(get_prop ro.product.manufacturer)"
MODEL="$(get_prop ro.product.model)"
ANDROID_RELEASE="$(get_prop ro.build.version.release)"
ANDROID_SDK="$(get_prop ro.build.version.sdk)"
SECURITY_PATCH="$(get_prop ro.build.version.security_patch)"
[ -n "$MANUFACTURER" ] || fail "device manufacturer is unavailable"
[ -n "$MODEL" ] || fail "device model is unavailable"
[[ "$ANDROID_SDK" =~ ^[0-9]+$ ]] || fail "device SDK level is unavailable"

PACKAGE_PATHS="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell pm path "$APP_PACKAGE" | tr -d '\r')"
BASE_APK_PATH="$(printf '%s\n' "$PACKAGE_PATHS" | sed -n \
  's/^package:\(.*\/base\.apk\)$/\1/p' | head -n 1)"
[ -n "$BASE_APK_PATH" ] || fail "$APP_PACKAGE is not installed as a release candidate"

PACKAGE_DUMP="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell dumpsys package "$APP_PACKAGE" | tr -d '\r')"
VERSION_NAME="$(printf '%s\n' "$PACKAGE_DUMP" | sed -n \
  's/^[[:space:]]*versionName=//p' | head -n 1)"
VERSION_CODE="$(printf '%s\n' "$PACKAGE_DUMP" | sed -n \
  's/^[[:space:]]*versionCode=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
[ "$VERSION_NAME" = "$EXPECTED_VERSION_NAME" ] || \
  fail "versionName mismatch: expected $EXPECTED_VERSION_NAME, got ${VERSION_NAME:-missing}"
[ "$VERSION_CODE" = "$EXPECTED_VERSION_CODE" ] || \
  fail "versionCode mismatch: expected $EXPECTED_VERSION_CODE, got ${VERSION_CODE:-missing}"

if printf '%s\n' "$PACKAGE_DUMP" | grep -Eq '(^|[[:space:]])(DEBUGGABLE|TEST_ONLY)([[:space:]]|$)'; then
  fail "installed package is debuggable or test-only"
fi

INSTALLER_LINE="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell cmd package list packages \
  -i "$APP_PACKAGE" | tr -d '\r' | head -n 1)"
INSTALLER="$(printf '%s\n' "$INSTALLER_LINE" | sed -n 's/.* installer=//p')"
if [ -z "$INSTALLER" ]; then
  INSTALLER="$(printf '%s\n' "$PACKAGE_DUMP" | sed -n \
    's/^[[:space:]]*installerPackageName=//p' | head -n 1)"
fi
if [ "$ALLOW_NON_PLAY_INSTALL" = "0" ] && [ "$INSTALLER" != "com.android.vending" ]; then
  fail "candidate was not installed by Google Play (installer=${INSTALLER:-missing})"
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/korubeni-phase3-preflight.XXXXXX")"
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

LOCAL_BASE_APK="$TEMP_DIR/base.apk"
"$ADB_BIN" -s "$DEVICE_SERIAL" pull "$BASE_APK_PATH" "$LOCAL_BASE_APK" >/dev/null
CERT_OUTPUT="$("$APKSIGNER_BIN" verify --print-certs "$LOCAL_BASE_APK")"
ACTUAL_CERT_SHA256="$(printf '%s\n' "$CERT_OUTPUT" | sed -n \
  's/^Signer #1 certificate SHA-256 digest: //p' | head -n 1)"
ACTUAL_CERT_SHA256="$(normalize_digest "$ACTUAL_CERT_SHA256")"
[[ "$ACTUAL_CERT_SHA256" =~ ^[0-9a-f]{64}$ ]] || \
  fail "could not read the installed APK signing certificate"
[ "$ACTUAL_CERT_SHA256" = "$EXPECTED_CERT_SHA256" ] || \
  fail "Play app-signing certificate mismatch"

mkdir -p "$EVIDENCE_DIR"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"
SAFE_TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
EVIDENCE_FILE="$EVIDENCE_DIR/${SAFE_TIMESTAMP}-${DEVICE_LABEL}-preflight.md"

cat >"$EVIDENCE_FILE" <<EOF
# Phase 3 Physical Device Preflight

- Result: PASS_PREFLIGHT_ONLY
- Generated at: $(single_line "$GENERATED_AT")
- Device label: $(single_line "$DEVICE_LABEL")
- Device serial: NOT_RECORDED
- Manufacturer: $(single_line "$MANUFACTURER")
- Model: $(single_line "$MODEL")
- Android release / SDK: $(single_line "$ANDROID_RELEASE") / $(single_line "$ANDROID_SDK")
- Security patch: $(single_line "${SECURITY_PATCH:-unknown}")
- Package: $APP_PACKAGE
- Version name / code: $(single_line "$VERSION_NAME") / $(single_line "$VERSION_CODE")
- Installer: $(single_line "${INSTALLER:-unknown}")
- Debuggable or test-only flags: absent
- Play app-signing SHA-256: $ACTUAL_CERT_SHA256
- Mutating actions performed: NONE

This is a read-only build/device identity preflight. It does not launch the app,
change permissions, place a call, kill a process, reboot the device or mark any
REAL_DEVICE_QA_MATRIX scenario as passed. Scenario evidence still requires the
operator-observed expected behavior, redacted screenshots/video and PASS/FAIL
rows for this exact build.
EOF

printf 'PASS_PREFLIGHT_ONLY: physical device and signed candidate identity verified.\n'
printf 'Evidence: %s\n' "$EVIDENCE_FILE"
