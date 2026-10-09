#!/bin/bash
# Lockout probe (closure audit 2026-10-09): open the app, report the unlock
# screen's lockout band, then enter the CORRECT PIN once at the keys' on-screen
# positions (read from the dump even while they are disabled) and report
# whether the app opened.
ADB=~/Library/Android/sdk/platform-tools/adb; T=$(dirname "$0"); P=com.poyrazoncel.korubeni
LABEL=$1; PIN=${2:-2468}
$ADB shell am start -n $P/.MainActivity >/dev/null 2>&1; sleep 2
python3 - "$T" "$PIN" "$LABEL" <<'PY'
import sys, time, subprocess
sys.path.insert(0, sys.argv[1]); import ui
pin, label = sys.argv[2], sys.argv[3]
# Cold start after a reboot is slow: wait for the unlock screen (or home).
for _ in range(20):
    ns = ui.nodes()
    if any('Uygulama kilidi' in ui.label(n) or 'Hoş Geldiniz' in ui.label(n) for n in ns): break
    time.sleep(1)
band = next((ui.label(n) for n in ns if 'Kilitli:' in ui.label(n)), 'none')
pos = {}
for n in ns:
    d = n.get('content-desc') or n.get('text') or ''
    if d in list('0123456789') and '_b' in n: pos.setdefault(d, ui.center(n))
if all(c in pos for c in pin):
    ui.sh('shell', ';'.join(f'input tap {pos[c][0]} {pos[c][1]}' for c in pin))
time.sleep(2.5)
home = any('Hoş Geldiniz' in ui.label(n) for n in ui.nodes())
dev = subprocess.run([ui.ADB, 'shell', 'date', '+%T'], capture_output=True, text=True).stdout.strip()
print(f"{label} | band={band.strip('|')} | correct PIN opened app={home} | dev={dev}")
PY
