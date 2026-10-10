#!/bin/bash
# OD-1 device probe runner. usage: od1_device_probe.sh <worktree> <label> <out>
set -u
export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$PATH"
W="$1"; LABEL="$2"; OUT="$3"
PKG=com.poyrazoncel.korubeni
APK="$W/build/app/outputs/flutter-apk/app-play-debug.apk"
TAPK="$W/build/app/outputs/apk/androidTest/play/debug/app-play-debug-androidTest.apk"
RUNNER="$PKG.test/androidx.test.runner.AndroidJUnitRunner"

prep() {
  adb root >/dev/null 2>&1; sleep 1; adb wait-for-device
  for st in 0 1 2 3 4 5 8 10; do adb shell cmd media_session volume --stream $st --set 0 >/dev/null 2>&1; done
  adb shell svc power stayon true >/dev/null 2>&1
  adb shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
  adb shell wm dismiss-keyguard >/dev/null 2>&1
}
grant_all() {
  for p in CALL_PHONE POST_NOTIFICATIONS; do adb shell pm grant $PKG android.permission.$p >/dev/null 2>&1; done
  adb shell appops set --uid $PKG SCHEDULE_EXACT_ALARM allow >/dev/null 2>&1
  adb shell appops set $PKG SCHEDULE_EXACT_ALARM allow >/dev/null 2>&1
}
telecom_calls() { adb shell dumpsys telecom 2>/dev/null | tr -d '\r' | /usr/bin/grep -oE 'TC@[0-9]+' | sort -u | wc -l | tr -d ' '; }
clear_telecom() { adb shell cmd telecom cleanup-stuck-calls >/dev/null 2>&1; adb shell pkill -f com.android.phone >/dev/null 2>&1; sleep 2; }

prep
adb uninstall $PKG >/dev/null 2>&1; adb uninstall $PKG.test >/dev/null 2>&1
adb install -r -t "$APK" >/dev/null 2>&1 || { echo "install app FAILED"; exit 1; }
adb install -r -t "$TAPK" >/dev/null 2>&1 || { echo "install test FAILED"; exit 1; }
grant_all
# One launch so the alert notification channels exist at HIGH importance.
adb shell am start -n $PKG/.MainActivity >/dev/null 2>&1; sleep 7
adb shell am force-stop $PKG >/dev/null 2>&1

{
  echo "# OD-1 DEVICE PROBE -- $LABEL"
  echo "# API $(adb shell getprop ro.build.version.sdk | tr -d '\r')  serial=$ANDROID_SERIAL  density=$(adb shell wm density | tr -d '\r')"
  echo "# source HEAD $(git -C "$W" rev-parse HEAD)"
  echo "# app  apk sha256 $(shasum -a 256 "$APK" | cut -c1-16)"
  echo "# test apk sha256 $(shasum -a 256 "$TAPK" | cut -c1-16)"
  echo "# installed $(adb shell "dumpsys package $PKG | grep -o 'lastUpdateTime=[^ ]* [^ ]*' | head -1" | tr -d '\r')"
  echo "# emulator-controlled number only: 05551234567 (emulator modem); no third party dialled"
  echo
  for mode in parity alarm alarm-control overdue control claimed claimed-control wall-forward wall-forward-boot wall-back; do
    clear_telecom
    before=$(telecom_calls)
    adb logcat -c
    adb shell am force-stop $PKG >/dev/null 2>&1
    # Clear only the session slot, never the whole app: pm clear revokes the
    # permissions this probe needs and would turn every outcome into FAILED.
    adb shell run-as $PKG rm -f /data/user_de/0/$PKG/shared_prefs/korubeni_emergency_session_v1.xml >/dev/null 2>&1
    adb shell "rm -f /data/user_de/0/$PKG/shared_prefs/korubeni_emergency_session_v1.xml" >/dev/null 2>&1
    echo "===== mode=$mode (telecom before=$before) ====="
    adb shell am instrument -w \
      -e overdueProbe "$mode" -e overdueProbeTarget 05551234567 -e overdueProbeAllowReplace 1 \
      -e class com.poyrazoncel.korubeni.emergency.OverdueSessionProbeTest \
      "$RUNNER" 2>&1 | tr -d '\r' | /usr/bin/grep -vE "^$"
    sleep 2
    after=$(telecom_calls)
    echo "telecom after=$after delta=$((after-before))"
    adb logcat -d -s OverdueProbe:I 2>&1 | tr -d '\r' | /usr/bin/grep "OverdueProbe" | sed 's/^/  /'
    echo
  done
  echo "# done $(date '+%F %T')"
} > "$OUT" 2>&1
echo "wrote $OUT"
