#!/usr/bin/env python3
"""v1.0.2 -> RC upgrade probe with real user data (closure audit 2026-10-10).

usage: ANDROID_SERIAL=<serial> upgrade_probe.py <v102.apk> <rc.apk> <out.md> <label>

debug -> debug (same package, same debug signing key): a release-signed
v1.0.2 -> RC upgrade cannot be built locally -- the Play release gate demands a
real goog_ RevenueCat key (EXTERNAL SYSTEM REQUIRED). Rooted emulator,
-no-audio. v1.0.2 opens Pro only through RevenueCat, so its user data here is
a non-Pro user's: consent, PIN, primary emergency contact, permissions, an
active PIN lockout.
"""
import os, re, subprocess, sys, time
V102, RC, OUT, LABEL = sys.argv[1:5]
sys.argv = [sys.argv[0], 'x.apk', 'com.poyrazoncel.korubeni', 'probe', '/dev/null']
sys.path.insert(0, os.path.dirname(__file__))
import runtime_matrix as rm
import ui

PKG = rm.PKG
rows = []
def sh(*a, timeout=300): return rm.sh(*a, timeout=timeout)
def lut(): m = re.search(r'lastUpdateTime=(\S+ \S+)', sh('shell', 'dumpsys', 'package', PKG)); return m.group(1) if m else '?'
def record(step, ok, detail):
    rows.append((step, 'PASS' if ok else 'FAIL', detail.replace('|', '/').replace('\n', ' ')[:280]))
    print(f'{step}: {"PASS" if ok else "FAIL"} {detail[:150]}', flush=True)
def band(): return next((ui.label(n).strip('|') for n in ui.nodes() if 'Kilitli:' in ui.label(n)), 'none')
def text(): return ' / '.join(l for l in rm.labels() if l.strip())
def alarms():
    # Pending section only: API 29 'Pending alarm batches' .. 'App Alarm history'/'Past-due';
    # API 34+ 'Next alarm clock information' .. 'LazyAlarmStore stats'. The history and
    # top-alarm sections repeat the tags and over-count.
    on, n = False, 0
    for line in sh('shell', 'dumpsys', 'alarm').splitlines():
        if re.search(r'Pending alarm batches|Next alarm clock information', line): on = True
        elif re.search(r'App Alarm history|Past-due|LazyAlarmStore stats|Pending user blocked', line): on = False
        elif on and re.search(r'walarm\*:' + re.escape(PKG) + r'\.EMERGENCY_SESSION_(?:GRACE|DISPATCH)', line): n += 1
    return n
def reboot():
    sh('reboot'); sh('wait-for-device')
    while sh('shell', 'getprop', 'sys.boot_completed').strip() != '1': time.sleep(2)
    sh('root'); time.sleep(4); sh('wait-for-device')
    for st in (0, 1, 2, 3, 4, 5, 8, 10): sh('shell', 'cmd', 'media_session', 'volume', '--stream', str(st), '--set', '0')
    sh('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP'); sh('shell', 'wm', 'dismiss-keyguard'); time.sleep(8)

def root_warning():
    # v1.0.2 shows a "Güvenlik Uyarısı" dialog on a rooted device (this emulator).
    if rm.has('Güvenlik Uyarısı', tries=1):
        rm.tap('Devam Et', exact=True); time.sleep(2)

def wait_for(label, tries=15):
    for _ in range(tries):
        root_warning()
        if rm.has(label, tries=1): return True
        time.sleep(1.5)
    return False

def consent():
    age = ui.find('18 yaşından büyüğüm')
    if age: x1, y1, x2, y2 = age['_b']; sh('shell', 'input', 'tap', str(x2 - 120), str((y1 + y2) // 2))
    for _ in range(5):
        for n in ui.nodes():
            if n.get('checkable') == 'true' and n.get('checked') != 'true' and '_b' in n:
                x, y = ui.center(n)
                if 200 < y < 2050: sh('shell', 'input', 'tap', str(x), str(y))
        sh('shell', 'input', 'swipe', '540', '1600', '540', '800', '400'); time.sleep(0.8)
    rm.tap('Devam Et ve Kurulumu'); time.sleep(4)

def setup_v102():
    sh('uninstall', PKG); out = sh('install', V102)
    sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(8)
    wait_for('Kurulum ve Onay')
    consent(); root_warning()
    if rm.has('Atla', tries=1): rm.tap('Atla', exact=True); time.sleep(2)
    wait_for("PIN'i Belirleyin")
    ui.pin('2468'); time.sleep(1.8); ui.pin('2468'); time.sleep(3)
    for _ in range(6):
        root_warning()
        if rm.has('Hoş Geldiniz', tries=1): break
        if rm.has('Bildirim izni', tries=1):
            rm.tap('Kabul Et', clickable=True); time.sleep(2); rm.tap('ALLOW', exact=True) or rm.tap('Allow', exact=True); time.sleep(2); continue
        for b in ('Şimdilik Atla', 'Atla'):
            if rm.tap(b, exact=True, tries=1): time.sleep(3); break
    rm.grant_all(); rm.open_app(); root_warning(); rm.unlock_if_needed(); root_warning(); rm.home()
    rm.tap('Acil kişi seçilmedi'); time.sleep(3)
    sh('shell', 'input', 'tap', '1011', '201'); time.sleep(2); rm.tap('Tamam', exact=True); time.sleep(1)
    rm.tap('Kişi Ekle', exact=True); time.sleep(3)
    if not rm.fields(): sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(2)
    rm.type_into(0, 'Annem'); rm.type_into(1, '05551234567'); sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1)
    rm.tap('Manuel kaydet', exact=True); time.sleep(2); rm.tap('beyan ederim', clickable=True); time.sleep(1); rm.tap('Ekle', exact=True); time.sleep(2)
    rm.tap('Annem'); time.sleep(2); rm.tap('Acil Kişi Seç', exact=True); time.sleep(2)
    sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(2); rm.home()
    ready = rm.has('Annem • 05551234567', tries=2)
    record('v1.0.2: install + consent + PIN + primary contact', 'Success' in out and ready, f'lastUpdateTime {lut()}; "Acil kişi hazır — Annem • 05551234567"={ready}')

def escalate():
    sh('shell', 'am', 'force-stop', PKG); sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(6)
    wait_for('Uygulama kilidi')
    for _ in range(5): ui.pin('1357', delay=0.1); time.sleep(1.2)
    seen = [band()]
    for _ in range(3):
        for _ in range(200):
            if band() == 'none': break
            time.sleep(2)
        ui.pin('1357', delay=0.1); time.sleep(1.5); seen.append(band())
    record('v1.0.2: wrong PINs escalate the lockout', seen[-1].startswith('Kilitli: 2'), ' -> '.join(seen) + f' at {time.strftime("%T")}')

def upgrade():
    t0 = time.strftime('%T'); out = sh('install', '-r', RC)
    sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(7)
    reconsent = rm.has('Kurulum ve Onay', tries=3)
    terms = re.search(r'Sürüm (\d+\.\d+\.\d+)', text())
    consent()
    b = band(); locked_screen = rm.has('Uygulama kilidi', tries=2)
    ui.pin('2468'); time.sleep(3)
    opened = rm.has('Hoş Geldiniz', tries=1)
    record('upgrade during the 240 s lockout -> re-consent -> lock still active, correct PIN refused',
           'Success' in out and reconsent and locked_screen and b.startswith('Kilitli') and not opened,
           f'install at {t0} lastUpdateTime {lut()}; re-consent={reconsent} terms={terms.group(1) if terms else "?"}; band after consent={b}; correct PIN opened={opened}')
    sh('shell', 'am', 'force-stop', PKG); sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(6)
    b2 = band(); record('force-stop after upgrade keeps the lockout', b2.startswith('Kilitli'), f'band={b2}')
    for _ in range(200):
        if band() == 'none': break
        time.sleep(2)
    ui.pin('2468'); time.sleep(4); rm.home()
    data = rm.has('Annem • 05551234567', tries=3)
    record('lockout runs out -> correct PIN opens; v1.0.2 data intact', data, f'"Acil kişi hazır — Annem • 05551234567"={data} at {time.strftime("%T")}')

def armed_checkin():
    rm.inject_pro(); rm.grant_all(); rm.open_app(); rm.home()
    for _ in range(3): sh('shell', 'input', 'swipe', '540', '1700', '540', '700', '400'); time.sleep(0.6)
    rm.tap('Kontrol Noktası', exact=True); time.sleep(3)
    if not rm.tap('15 dk', exact=True): rm.tap('5 dk', exact=True)
    time.sleep(3)
    if rm.has('Bildirim izni gerekli', tries=1): rm.tap('Kabul Et', clickable=True); time.sleep(2)
    rm.tap('Anladım, devam et'); time.sleep(3)
    a0 = alarms(); record('upgraded app: Check-In 15 min armed', rm.state('long') == 'armed' and a0 >= 2, f'native={rm.state("long")} pending alarms={a0}')
    sh('shell', f'kill -9 $(pidof {PKG})'); time.sleep(2)
    record('kill -9', rm.state('long') == 'armed' and alarms() == a0, f'native={rm.state("long")} alarms={alarms()}')
    sh('shell', 'am', 'force-stop', PKG); time.sleep(1); sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(8)
    record('force-stop -> reopen', rm.state('long') == 'armed' and alarms() >= 2, f'native={rm.state("long")} alarms={alarms()}')
    reboot()
    pid = sh('shell', 'pidof', PKG).strip()
    record('reboot (app not opened): alarms rescheduled by the boot receiver', rm.state('long') == 'armed' and alarms() >= 2,
           f'native={rm.state("long")} alarms={alarms()} boot-receiver pid={pid or "-"}')
    rm.open_app(); rm.home()
    for _ in range(3): sh('shell', 'input', 'swipe', '540', '1700', '540', '700', '400'); time.sleep(0.6)
    rm.tap('Kontrol Noktası', exact=True); time.sleep(3)
    remaining = next((l for l in rm.labels() if re.match(r'\|?\d{1,2}:\d{2}$', l.strip())), '?')
    rm.tap('İptal Et'); time.sleep(2)
    f = rm.fields()
    if f:
        x, y = ui.center(f[0]); sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(0.5)
        sh('shell', 'input', 'text', '2468'); time.sleep(0.5); rm.tap('Doğrula', exact=True); time.sleep(3)
    record('reopen -> remaining shown -> PIN cancel', rm.state('long') == 'cancelled' and alarms() == 0,
           f'remaining={remaining.strip("|")} native={rm.state("long")} alarms={alarms()}')

def main():
    sh('root'); time.sleep(2); sh('shell', 'settings', 'put', 'global', 'auto_time', '0')
    sdk = sh('shell', 'getprop', 'ro.build.version.sdk').strip()
    for step in (setup_v102, escalate, upgrade, armed_checkin):
        try: step()
        except Exception as exc: record(step.__name__, False, f'probe error: {exc!r}')
    with open(OUT, 'a') as f:
        f.write(f'\n## {LABEL} — API {sdk}\n| Step | Result | Observed |\n|---|---|---|\n')
        for r in rows: f.write(f'| {r[0]} | {r[1]} | {r[2]} |\n')

if __name__ == '__main__':
    main()
