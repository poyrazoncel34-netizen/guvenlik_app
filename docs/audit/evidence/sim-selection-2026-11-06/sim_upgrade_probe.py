#!/usr/bin/env python3
"""Upgrade probe: CALL_PHONE-only install -> build with READ_PHONE_STATE.

usage: ANDROID_SERIAL=<serial> sim_upgrade_probe.py <old.apk> <new.apk> <out.md> <shots_dir>
Reuses the chaos-audit helpers (onboarding, offline Pro anchor, grants).
"""
import os, re, sys, time
OLD, NEW, OUT, SHOTS = sys.argv[1:5]
TOOLS = '/Users/poyrazoncel/Projects/guvenlik_app/docs/audit/evidence/chaos-2026-10-08/tools'
sys.argv = [sys.argv[0], 'x.apk', 'com.poyrazoncel.korubeni', 'probe', '/dev/null']
sys.path.insert(0, TOOLS)
import runtime_matrix as rm
import ui

PKG = rm.PKG
rows = []
def sh(*a, timeout=300): return rm.sh(*a, timeout=timeout)
def record(step, ok, detail=''):
    rows.append((step, 'PASS' if ok else 'FAIL', detail.replace('|', '/').replace('\n', ' ')[:260]))
    print(f'{step}: {"PASS" if ok else "FAIL"} {detail[:160]}', flush=True)
def perm(name):
    out = sh('shell', 'dumpsys', 'package', PKG)
    m = re.search(rf'android\.permission\.{name}: granted=(\w+)', out)
    return m.group(1) if m else 'absent'
def lut():
    m = re.search(r'lastUpdateTime=(\S+ \S+)', sh('shell', 'dumpsys', 'package', PKG)); return m.group(1) if m else '?'
def shot(name):
    os.makedirs(SHOTS, exist_ok=True)
    data = __import__('subprocess').run([ui.ADB, 'exec-out', 'screencap', '-p'], capture_output=True).stdout
    open(os.path.join(SHOTS, name), 'wb').write(data)

sh('shell', 'svc', 'power', 'stayon', 'true')
for s in ['0', '1', '2', '3', '4', '5', '8', '10']:
    sh('shell', 'cmd', 'media_session', 'volume', '--stream', s, '--set', '0')
sh('uninstall', PKG)
r = sh('install', OLD)
record('old build installed', 'Success' in r, f'{os.path.basename(OLD)} lastUpdateTime={lut()}')
rm.onboarding()
rm.inject_pro()
pro = sh('shell', 'cat', f'/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml')
record('offline Pro anchor present (test-only, root)', 'revenuecat_prior_verified_pro_hint_v1' in pro)
rm.grant_all()
record('old build: CALL_PHONE granted, READ_PHONE_STATE not declared',
       perm('CALL_PHONE') == 'true' and perm('READ_PHONE_STATE') == 'absent',
       f"CALL_PHONE={perm('CALL_PHONE')} READ_PHONE_STATE={perm('READ_PHONE_STATE')}")
rm.open_app(); time.sleep(4)
record('old build reaches home', rm.home(), ' / '.join(rm.labels()[:5]))

r = sh('install', '-r', NEW)
record('new build installed over old (adb install -r)', 'Success' in r, f'lastUpdateTime={lut()}')
time.sleep(3)
cp, rps = perm('CALL_PHONE'), perm('READ_PHONE_STATE')
record('after upgrade: CALL_PHONE kept, READ_PHONE_STATE declared but not granted',
       cp == 'true' and rps == 'false', f"CALL_PHONE={cp} READ_PHONE_STATE={rps}")

sh('shell', 'am', 'force-stop', PKG)
sh('shell', 'am', 'start', '-n', rm.MAIN); time.sleep(6); rm.unlock_if_needed()
seen = rm.has('SIM Seçimi İzni', tries=15)
shot('01_disclosure.png')
record('first start after upgrade shows the SIM disclosure', seen, ' / '.join(rm.labels()[:6]))
if seen:
    rm.tap('Kabul Et', clickable=True); time.sleep(3)
    os_dialog = any(('Allow' in l or 'ALLOW' in l or 'İzin ver' in l) for l in rm.labels())
    shot('02_after_accept.png')
    if os_dialog:
        rm.tap('Allow', exact=True) or rm.tap('ALLOW', exact=True) or rm.tap('İzin ver'); time.sleep(2)
    record('after accept: READ_PHONE_STATE granted',
           perm('READ_PHONE_STATE') == 'true',
           f"OS dialog shown={os_dialog}; READ_PHONE_STATE={perm('READ_PHONE_STATE')} CALL_PHONE={perm('CALL_PHONE')}")

sh('shell', 'am', 'force-stop', PKG)
sh('shell', 'am', 'start', '-n', rm.MAIN); time.sleep(6); rm.unlock_if_needed()
again = rm.has('SIM Seçimi İzni', tries=6)
record('second start: not asked again', not again, ' / '.join(rm.labels()[:5]))

prefs = sh('shell', 'cat', f'/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml')
record('offer flag persisted', 'pref_sim_selection_offered' in prefs)
fp = sh('shell', 'getprop', 'ro.build.fingerprint').strip()
dens = sh('shell', 'wm', 'density').strip().replace('\n', ' ')
with open(OUT, 'w') as f:
    f.write(f'device: {os.environ.get("ANDROID_SERIAL")} fingerprint={fp} {dens}\n\n')
    f.write('| step | result | detail |\n|---|---|---|\n')
    for s, r_, d in rows: f.write(f'| {s} | {r_} | {d} |\n')
print('FAILS', sum(1 for r_ in rows if r_[1] == 'FAIL'))
