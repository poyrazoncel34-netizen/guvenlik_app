#!/bin/bash
# Reboot + clock lockout matrix (closure audit 2026-10-09, owner decision:
# reboot, wall clock +-1 h/+-1 day, timezone, auto-time cannot remove an
# active lockout). Scripted so the identical run repeats on the release
# candidate. Needs a rooted emulator (adb root), the app onboarded with PIN
# 2468, ANDROID_SERIAL set, and the emulator started with -no-audio.
# usage: lockout_matrix.sh <out.txt> <build label>
set -u
ADB=~/Library/Android/sdk/platform-tools/adb; T=$(dirname "$0"); P=com.poyrazoncel.korubeni
OUT=$1; BUILD=$2
log() { echo "$*" | tee -a "$OUT"; }
probe() { bash "$T/lockout_probe.sh" "$1" | tail -1 | tee -a "$OUT"; }
pyui() { python3 - "$T" "$@" <<'PY'
import sys, time
sys.path.insert(0, sys.argv[1]); import ui
cmd = sys.argv[2]
def band():
    return next((ui.label(n).strip('|') for n in ui.nodes() if 'Kilitli:' in ui.label(n)), 'none')
if cmd == 'wrong':
    for _ in range(int(sys.argv[3])):
        ui.pin('1357', delay=0.1); time.sleep(1.2)
    print('band after wrong PINs:', band())
elif cmd == 'band':
    print(band())
elif cmd == 'wait_unlocked':
    for _ in range(400):
        if band() == 'none': break
        time.sleep(2)
    print('band', band())
PY
}
real_time() { $ADB shell "date @$(date +%s)" >/dev/null; }
reopen_locked() { $ADB shell am force-stop $P; sleep 1; $ADB shell am start -n $P/.MainActivity >/dev/null; sleep 5; }
reboot_dev() {
  $ADB reboot; $ADB wait-for-device
  until [ "$($ADB shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
  $ADB root >/dev/null 2>&1; sleep 3; $ADB wait-for-device
  for st in 0 1 2 3 4 5 8 10; do $ADB shell cmd media_session volume --stream $st --set 0 >/dev/null 2>&1; done
  $ADB shell input keyevent KEYCODE_WAKEUP; $ADB shell wm dismiss-keyguard; sleep 8
}
$ADB root >/dev/null 2>&1; sleep 2
$ADB shell settings put global auto_time 0; $ADB shell cmd alarm set-timezone Europe/Istanbul; real_time
LUT=$($ADB shell dumpsys package $P | grep -o 'lastUpdateTime=[^ ]* [^ ]*' | head -1)
log "lockout matrix $($ADB shell getprop ro.build.version.sdk | tr -d '\r') serial=$ANDROID_SERIAL build=$BUILD $LUT start=$(date +%T)"
reopen_locked; pyui wrong 5 | tee -a "$OUT"
$ADB shell "kill -9 \$(pidof $P)" 2>/dev/null; sleep 1; probe "1 lock -> kill -9 -> reopen"
log "--- escalate to 240 s (failures 6, 7, 8 each after the previous lockout ends)"
for n in 6 7 8; do pyui wait_unlocked >/dev/null; pyui wrong 1 | tee -a "$OUT"; done
log "--- escalated at $(date +%T)"
$ADB shell am force-stop $P; probe "2 lock -> force-stop -> reopen"
$ADB shell "date @$(( $(date +%s) + 3600 ))" >/dev/null; probe "3 lock -> wall +1 h"
$ADB shell "date @$(( $(date +%s) + 90000 ))" >/dev/null; probe "4 lock -> wall +1 day (+25 h total)"
$ADB shell "date @$(( $(date +%s) - 86400 ))" >/dev/null; probe "5 lock -> wall -1 day (from real)"
real_time; $ADB shell cmd alarm set-timezone America/New_York; probe "6 lock -> timezone Europe/Istanbul -> America/New_York"
$ADB shell cmd alarm set-timezone Europe/Istanbul; $ADB shell settings put global auto_time 1; sleep 2; probe "7 lock -> automatic time ON"
$ADB shell settings put global auto_time 0; real_time
log "--- reboots"
reboot_dev; probe "8 lock -> reboot"
reboot_dev; $ADB shell "date @$(( $(date +%s) + 3600 ))" >/dev/null; probe "9 lock -> reboot -> wall +1 h"
reboot_dev; $ADB shell "date @$(( $(date +%s) + 86400 ))" >/dev/null; probe "10 lock -> reboot -> wall +1 day"
reboot_dev; $ADB shell "date @$(( $(date +%s) - 86400 ))" >/dev/null; probe "11 lock -> reboot -> wall -1 day"
real_time; reboot_dev; $ADB shell cmd alarm set-timezone Asia/Tokyo; probe "12 lock -> reboot -> timezone Asia/Tokyo"
$ADB shell cmd alarm set-timezone Europe/Istanbul; reboot_dev; $ADB shell am start -n $P/.MainActivity >/dev/null; sleep 6; $ADB shell "kill -9 \$(pidof $P)" 2>/dev/null; sleep 1; probe "13 lock -> reboot -> open -> kill -9 -> reopen"
reboot_dev; reboot_dev; probe "14 lock -> two reboots in a row"
log "--- 15: let the lockout run out on screen in this boot, then reboot"
$ADB shell am start -n $P/.MainActivity >/dev/null; sleep 3; pyui wait_unlocked | tee -a "$OUT"
reboot_dev; probe "15 lockout ran out on screen (same boot) -> reboot: not restarted; correct PIN opens"
real_time; $ADB shell cmd alarm set-timezone Europe/Istanbul
log "end=$(date +%T)"
