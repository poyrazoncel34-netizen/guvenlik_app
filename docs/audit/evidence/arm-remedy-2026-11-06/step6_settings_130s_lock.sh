#!/bin/bash
# Step 6: >120 s in Settings during the setup, then back to the app.
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"; export ANDROID_SERIAL=emulator-5560
SP=/private/tmp/claude-501/-Users-poyrazoncel-Projects-guvenlik-app/2781c261-4c72-4de3-948e-64b23b77e2fc/scratchpad
T=/Users/poyrazoncel/Projects/guvenlik_app/docs/audit/evidence/chaos-2026-10-08/tools
sleep 130
echo "BACK at $(date +%T) (left at $(cat $SP/t_left.txt))"
adb shell input keyevent KEYCODE_BACK
sleep 4
echo "--- after return (expect lock, no new prompt)"
python3 $T/ui.py ls | cut -c1-160 | head -14
$SP/shot.sh 05_return_after_130s_lock_first >/dev/null
python3 $T/ui.py pin 2468
sleep 5
echo "--- after unlock (expect the next prompt)"
python3 $T/ui.py ls | cut -c1-200 | head -14
$SP/shot.sh 06_after_unlock_next_prompt >/dev/null
echo DONE
