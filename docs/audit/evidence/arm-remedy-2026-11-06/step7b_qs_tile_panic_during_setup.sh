#!/bin/bash
# Step 7 (rerun): QS tile panic while the setup has the user in Settings.
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"; export ANDROID_SERIAL=emulator-5560
SP=/private/tmp/claude-501/-Users-poyrazoncel-Projects-guvenlik-app/2781c261-4c72-4de3-948e-64b23b77e2fc/scratchpad
T=/Users/poyrazoncel/Projects/guvenlik_app/docs/audit/evidence/chaos-2026-10-08/tools
P=com.poyrazoncel.korubeni
adb logcat -c
adb shell am start -n $P/.MainActivity >/dev/null
for i in $(seq 1 15); do python3 $T/ui.py ls 2>/dev/null | grep -q "Giriş yapmak" && break; sleep 1; done
python3 $T/ui.py pin 2468
for i in $(seq 1 12); do python3 $T/ui.py ls 2>/dev/null | grep -q "Ayarlara Git" && break; sleep 1; done
echo "PROMPT-1 $(date +%T): $(python3 $T/ui.py ls | grep -o -E 'Bildirim izni kapalı' | head -1)"
python3 $T/ui.py tapx "Ayarlara Git"; sleep 2
echo "IN-SETTINGS $(date +%T) $(adb shell dumpsys activity activities | grep -m1 topResumedActivity | sed 's/.*u0 //')"
adb shell cmd statusbar expand-settings; sleep 2
python3 - <<'PY'
import sys, time
sys.path.insert(0, '/Users/poyrazoncel/Projects/guvenlik_app/docs/audit/evidence/chaos-2026-10-08/tools')
import ui
n = ui.find('KoruBeni panik')
print('TILE-NODE', n.get('_b') if n else None, repr(ui.label(n))[:80] if n else '')
if n:
    x, y = ui.center(n); ui.sh('shell', 'input', 'tap', str(x), str(y)); print('TILE-TAP', time.strftime('%H:%M:%S'))
PY
sleep 2.5
$SP/shot.sh 16_tile_panic_countdown_no_prompt >/dev/null; echo "SHOT-16 $(date +%T)"
python3 $T/live_pin.py 2468
sleep 5
echo "--- 5 s after PIN at $(date +%T)"
python3 $T/ui.py ls | cut -c1-150 | grep -v -E "^'\|KoruBeni güvenlik" | head -10
$SP/shot.sh 17_after_pin_cancel >/dev/null
echo "PREF $(adb shell "run-as $P grep -c readiness_setup shared_prefs/FlutterSharedPreferences.xml")"
echo "CALLS $(adb shell dumpsys telecom | grep -c 'Call id=')"
adb logcat -d -v time | grep -E "START u0|act=android.intent.action.(CALL|DIAL)|E/flutter|FATAL" | grep -v uiautomator | cut -c1-170 | head -8
echo DONE
