#!/bin/zsh
# Device-side RC chain for one emulator (closure audit 2026-10-10).
# usage: ANDROID_SERIAL=<serial> rc_device_chain.sh <api29|api35|api36> <artifacts dir> <rc worktree> <evidence dir>
set -u
WHICH=$1; A=$2; W=$3; EV=$4
R=${0:A:h:h:h:h:h:h}; T=${0:A:h}
ADB=~/Library/Android/sdk/platform-tools/adb
cd $R
prep() { $ADB root >/dev/null 2>&1; sleep 2; $ADB wait-for-device; $ADB shell "date @$(date +%s)" >/dev/null
  for st in 0 1 2 3 4 5 8 10; do $ADB shell cmd media_session volume --stream $st --set 0 >/dev/null 2>&1; done
  $ADB shell svc power stayon true; $ADB shell input keyevent KEYCODE_WAKEUP; $ADB shell wm dismiss-keyguard; }
DBG="RC $(git -C $W rev-parse --short HEAD) debug sha256 $(shasum -a 256 $A/rc-play-debug.apk | cut -c1-16)"
SMK="RC $(git -C $W rev-parse --short HEAD) SMOKE RELEASE (R8+AOT) sha256 $(shasum -a 256 $A/rc-smoke-release.apk | cut -c1-16)"
instrument() {
  TA=$W/build/app/outputs/apk/androidTest/play/debug/app-play-debug-androidTest.apk
  until [ -s $EV/verify_release.txt ] && grep -aq "lint + Kotlin unit + instrumentation" $EV/verify_release.txt && [ -f $TA ]; do sleep 20; done
  cp $TA $A/rc-androidTest.apk
  { print "serial=$ANDROID_SERIAL API $($ADB shell getprop ro.build.version.sdk | tr -d '\r') $DBG test=$(shasum -a 256 $A/rc-androidTest.apk | cut -c1-16) $(date '+%F %T')"
    $ADB install -r -t $A/rc-play-debug.apk; $ADB install -r -t $A/rc-androidTest.apk
    $ADB shell am instrument -w com.poyrazoncel.korubeni.test/androidx.test.runner.AndroidJUnitRunner; print "end $(date '+%F %T')"; } > $EV/instrumentation-$WHICH.txt 2>&1
}
prep
case $WHICH in
  api35)
    python3 $T/closure_probe.py setup $A/rc-play-debug.apk > $EV/chaos-setup-api35.txt 2>&1
    print "$DBG API35 KoruBeni_A017_API35 emulator-5554 420dpi -no-audio $($ADB shell dumpsys package com.poyrazoncel.korubeni | grep -o 'lastUpdateTime=[^ ]* [^ ]*' | head -1) seed 20261015, ANR-aware driver" > $EV/human-chaos-rc-api35.meta.txt
    python3 $T/human_chaos.py 20261015 110 $EV/human-chaos-rc-api35.jsonl > $EV/human-chaos-rc-api35.out.txt 2>&1
    prep; instrument ;;
  api36)
    python3 $T/runtime_matrix.py $A/rc-play-debug.apk com.poyrazoncel.korubeni "API 36 KoruBeni_API36 emulator-5558 $DBG" $EV/runtime-matrix-rc.md > $EV/runtime-matrix-api36.out.txt 2>&1
    prep; zsh $T/lockout_matrix.sh $EV/lockout-matrix-api36-rc.txt "$DBG" > $EV/lockout-matrix-api36-rc.out.txt 2>&1
    prep; python3 $T/closure_probe.py setup $A/rc-play-debug.apk > $EV/fix-probes-setup-api36.txt 2>&1
    python3 $T/rc_fix_probes.py $EV/rc-fix-probes.md "$DBG — KoruBeni_API36 emulator-5558, 420 dpi, -no-audio" > $EV/rc-fix-probes-api36.out.txt 2>&1
    prep; instrument ;;
  api29)
    python3 $T/runtime_matrix.py $A/rc-play-debug.apk com.poyrazoncel.korubeni "API 29 KoruBeni_API29 emulator-5556 $DBG" $EV/runtime-matrix-rc-api29.md > $EV/runtime-matrix-api29.out.txt 2>&1
    prep; python3 $T/runtime_matrix.py $A/rc-smoke-release.apk com.poyrazoncel.korubeni.smoke "API 29 emulator-5556 $SMK" $EV/runtime-matrix-rc-smoke-release.md --release > $EV/runtime-matrix-smoke-api29.out.txt 2>&1
    prep; python3 $T/upgrade_probe.py $A/v102-play-debug.apk $A/rc-play-debug.apk $EV/upgrade-v102-to-rc.md "v1.0.2 debug sha256 $(shasum -a 256 $A/v102-play-debug.apk | cut -c1-16) -> $DBG — KoruBeni_API29 emulator-5556, 420 dpi, -no-audio" > $EV/upgrade-v102-to-rc.out.txt 2>&1
    prep; PROBES=p9 python3 $T/rc_fix_probes.py $EV/rc-fix-probes.md "$DBG — KoruBeni_API29 emulator-5556 (P9 on the affected OS)" > $EV/rc-fix-probes-api29.out.txt 2>&1
    prep; instrument ;;
esac
print "chain $WHICH done $(date '+%F %T')" >> $EV/device-chains.txt
