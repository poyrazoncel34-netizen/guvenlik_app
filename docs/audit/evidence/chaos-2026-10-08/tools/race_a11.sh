#!/bin/bash
# A-11 review race: armed panic -> kill as soon as native is ARMED -> cold start
# via the widget trampoline -> PIN as soon as the countdown keypad is visible.
ADB=~/Library/Android/sdk/platform-tools/adb; T=$(dirname "$0"); P=com.poyrazoncel.korubeni
F=/data/user_de/0/$P/shared_prefs/korubeni_emergency_session_v1.xml
$ADB logcat -c
python3 $T/ui.py panic || exit 1
for i in $(seq 1 40); do $ADB shell cat $F | grep -q '>armed<' && break; sleep 0.1; done
echo "ARMED-SEEN $(date +%T.%N | cut -c1-12) $($ADB shell cat $F | tr '<' '\n' | grep panic_finalDeadlineMs)"
$ADB shell kill -9 $($ADB shell pidof $P); echo "KILLED $(date +%T.%N | cut -c1-12)"
$ADB shell am start -n $P/.quickaccess.QuickPanicTrampolineActivity --es $P.extra.PANIC_SOURCE widget >/dev/null 2>&1
echo "WIDGET $(date +%T.%N | cut -c1-12)"
for i in $(seq 1 40); do
  if python3 $T/pad_visible.py; then echo "PAD $(date +%T.%N | cut -c1-12)"; bash $T/cdpin.sh 2468; break; fi
done
$ADB exec-out screencap -p > $T/../shots/a11r_race_after_pin.png
sleep 9
echo "STATE $($ADB shell cat $F | tr '<' '\n' | grep panic_lifecycleState)"
$ADB logcat -d -v time | grep -iE "act=android.intent.action.(CALL|DIAL)|CREATED, com.poyrazoncel|E/flutter|FATAL" | head -3
