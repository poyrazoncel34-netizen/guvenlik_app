#!/usr/bin/env bash
# Emulator resource pass for section 41. See
# docs/audit/device-verification-2026-08-14-perf-resources.md for what this
# CAN and CANNOT measure -- battery, thermal and GPU are not among them.
set -u
export PATH=$PATH:$HOME/Library/Android/sdk/platform-tools
PKG=com.poyrazoncel.korubeni
OUT=/private/tmp/claude-501/-Users-poyrazoncel-Desktop-guvenlik-app/811a225e-d965-464a-b403-4858eef174dd/scratchpad/perf
mkdir -p $OUT
echo "== install profile build =="
adb install -r -d build/app/outputs/flutter-apk/app-play-profile.apk 2>&1 | tail -2
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS 2>/dev/null
echo "== cold start =="
adb shell am force-stop $PKG
sleep 2
adb shell am start-activity -W -n $PKG/.MainActivity 2>&1 | tee $OUT/coldstart.txt
sleep 8
echo "== baseline meminfo =="
adb shell dumpsys meminfo $PKG > $OUT/mem_t0.txt 2>&1
echo "== network baseline (uid) =="
APPUID=$(adb shell dumpsys package $PKG | grep -m1 userId= | tr -d '\r' | sed 's/.*userId=//' | awk '{print $1}')
echo "uid=$APPUID" > $OUT/net.txt
adb shell cat /proc/net/xt_qtaguid/stats 2>/dev/null | grep " $APPUID " | head -5 >> $OUT/net.txt
adb shell dumpsys netstats detail 2>/dev/null | grep -A3 "uid=$APPUID" | head -20 >> $OUT/net.txt
echo "== drive: scroll + tab switches =="
for i in 1 2 3 4 5 6 7 8; do
  adb shell input swipe 540 1800 540 500 220
  adb shell input swipe 540 500 540 1800 220
done
adb shell dumpsys SurfaceFlinger --latency-clear >/dev/null 2>&1
for i in 1 2 3 4 5 6; do
  adb shell input swipe 540 1800 540 500 200
  sleep 0.3
done
LAYER=$(adb shell dumpsys SurfaceFlinger --list 2>/dev/null | grep -i "$PKG" | grep -i blast | tail -1 | tr -d '\r')
echo "layer=$LAYER" > $OUT/frames.txt
adb shell dumpsys SurfaceFlinger --latency "$LAYER" >> $OUT/frames.txt 2>&1
echo "== meminfo after interaction =="
adb shell dumpsys meminfo $PKG > $OUT/mem_t1.txt 2>&1
echo "== cpu =="
adb shell top -n 1 -b 2>/dev/null | grep -i korubeni > $OUT/cpu.txt
adb shell dumpsys cpuinfo 2>/dev/null | grep -i korubeni >> $OUT/cpu.txt
echo "== gfxinfo (HWUI half, recorded for completeness) =="
adb shell dumpsys gfxinfo $PKG > $OUT/gfx.txt 2>&1
echo "== battery stats =="
adb shell dumpsys batterystats --charged $PKG 2>/dev/null | head -40 > $OUT/battery.txt
echo "== thermal =="
adb shell dumpsys thermalservice 2>/dev/null | head -20 > $OUT/thermal.txt
echo "== network after =="
adb shell dumpsys netstats detail 2>/dev/null | grep -A3 "uid=$APPUID" | head -20 >> $OUT/net.txt
echo "DONE"
