#!/usr/bin/env python3
"""Runtime matrix on the REAL app (closure audit 2026-10-09).

usage: ANDROID_SERIAL=<serial> runtime_matrix.py <apk> <package> <label> <out.md> [--release]

Clean install -> onboarding -> permissions -> home -> panic + PIN cancel ->
Check-In start + PIN cancel -> Safe Walk start + PIN cancel -> widget quick
panic + cancel -> Quick Settings tile panic + cancel -> deep link -> map ->
timeline -> process kill + reopen. Every step records PASS/FAIL with what the
screen showed; the native session store is read after every safety step.
Pro is a TEST-ONLY offline anchor written as root (never a commerce proof).
"""
import os, re, subprocess, sys, time
sys.path.insert(0, os.path.dirname(__file__)); import ui
# Fixed key (PanicLaunch.kt), NOT applicationId-based: the smoke build's
# '<pkg>.smoke.extra...' was refused (fail-closed) and looked like a failure.
PANIC_SOURCE_EXTRA = 'com.poyrazoncel.korubeni.extra.PANIC_SOURCE'

APK, PKG, LABEL, OUT = sys.argv[1:5]
RELEASE = '--release' in sys.argv
MAIN = f'{PKG}/com.poyrazoncel.korubeni.MainActivity'
SESSION = f'/data/user_de/0/{PKG}/shared_prefs/korubeni_emergency_session_v1.xml'
PIN = '2468'
rows = []

def sh(*a, timeout=120):
    return subprocess.run([ui.ADB, *a], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout).stdout

def labels(): return [ui.label(n) for n in ui.nodes()]
def has(text, tries=10, wait=1.0):
    for _ in range(tries):
        if any(text in l for l in labels()): return True
        time.sleep(wait)
    return False
def tap(text, exact=False, clickable=False, tries=6):
    for _ in range(tries):
        if ui.tap(text, exact=exact, clickable=clickable): return True
        time.sleep(1)
    return False
def state(slot):
    m = re.search(rf'name="session_{slot}_lifecycleState">(\w+)<', sh('shell', 'cat', SESSION))
    return m.group(1) if m else 'none'
def record(step, ok, detail=''):
    rows.append((step, 'PASS' if ok else 'FAIL', detail.replace('|', '/').replace('\n', ' ')[:220]))
    print(f'{step}: {"PASS" if ok else "FAIL"} {detail[:120]}', flush=True)
def unlock_if_needed():
    if has('Uygulama kilidi', tries=3):
        ui.pin(PIN); time.sleep(3)
def fields(): return [n for n in ui.nodes() if 'EditText' in n.get('class', '')]
def type_into(idx, text):
    f = fields(); x, y = ui.center(f[idx]); sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(0.5)
    sh('shell', 'input', 'text', text); time.sleep(0.4)

def onboarding():
    sh('shell', 'am', 'start', '-n', MAIN); time.sleep(7)
    if not has('Kurulum ve Onay', tries=10): return record('onboarding: consent screen', False, ' / '.join(labels()[:4]))
    age = ui.find('18 yaşından büyüğüm')
    if age: x1, y1, x2, y2 = age['_b']; sh('shell', 'input', 'tap', str(x2 - 120), str((y1 + y2) // 2))
    for _ in range(5):
        for n in ui.nodes():
            if n.get('checkable') == 'true' and n.get('checked') != 'true' and '_b' in n:
                x, y = ui.center(n)
                if 200 < y < 2050: sh('shell', 'input', 'tap', str(x), str(y))
        sh('shell', 'input', 'swipe', '540', '1600', '540', '800', '400'); time.sleep(0.8)
    tap('Devam Et ve Kurulumu'); time.sleep(3)
    tap('Atla', exact=True); time.sleep(3)
    # OD-2 (2026-10-11): 'Atla' now lands on the "Arka Plan Koruması" step,
    # which sits one page before the contact gate, so reaching the gate takes
    # one more 'Ileri'. The step is skipped WITHOUT granting the access on
    # purpose: a shared setup helper must leave the device in the ordinary
    # state, and probes that care about exact alarms set that bit themselves.
    if has('Arka Plan Koruması', tries=4):
        tap('İleri', exact=True); time.sleep(3)
    ok = has('Acil kişinizi ekleyin')
    record('onboarding: consent + carousel', ok)
    type_into(0, 'Annem'); f = fields(); type_into(1, '05551234567'); sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(0.8)
    tap('Kişiyi kaydet'); time.sleep(2); tap('beyan ederim', clickable=True); time.sleep(0.8); tap('Ekle', exact=True); time.sleep(2)
    record('onboarding: emergency contact + contact consent', has('birincil acil kişiniz'))
    tap('Başla', exact=True); time.sleep(3); ui.pin(PIN); time.sleep(1.8); ui.pin(PIN); time.sleep(3)
    if has('Bildirim izni', tries=3):
        tap('Kabul Et', clickable=True); time.sleep(2); tap('ALLOW', exact=True) or tap('Allow', exact=True); time.sleep(2)
    if has('Şimdilik Atla', tries=4): tap('Şimdilik Atla'); time.sleep(3)
    record('onboarding: PIN + notification + battery step -> home', has('Hoş Geldiniz'))

def inject_pro():
    sh('shell', 'am', 'force-stop', PKG)
    f = f'/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml'
    owner = sh('shell', 'stat', '-c', '%U:%G', f).strip()
    xml = sh('shell', 'cat', f)
    now = int(time.time() * 1000) - 60000
    xml = re.sub(r'\s*<(boolean|long) name="flutter\.revenuecat_(prior_verified_pro_hint|last_verified_pro_at)_v1"[^>]*/>', '', xml)
    xml = xml.replace('</map>', f'    <boolean name="flutter.revenuecat_prior_verified_pro_hint_v1" value="true" />\n    <long name="flutter.revenuecat_last_verified_pro_at_v1" value="{now}" />\n</map>')
    tmp = '/tmp/fsp_matrix.xml'; open(tmp, 'w').write(xml)
    sh('push', tmp, '/data/local/tmp/fsp.xml')
    sh('shell', f'cat /data/local/tmp/fsp.xml > {f} && chown {owner} {f} && restorecon {f} && rm /data/local/tmp/fsp.xml')

def grant_all():
    for p in ['CALL_PHONE', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'POST_NOTIFICATIONS']:
        sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')
    sh('shell', 'appops', 'set', '--uid', PKG, 'SCHEDULE_EXACT_ALARM', 'allow')
    sh('shell', 'appops', 'set', PKG, 'SCHEDULE_EXACT_ALARM', 'allow')

def open_app():
    sh('shell', 'am', 'start', '-n', MAIN); time.sleep(6); unlock_if_needed()

def home():
    for _ in range(3):
        if has('Hoş Geldiniz', tries=2): return True
        tap('Ana Sayfa', exact=True); time.sleep(2)
    return has('Hoş Geldiniz', tries=2)

def cancel_countdown(slot, step):
    t0 = time.time(); ok_seen = False
    for _ in range(12):
        ns = ui.nodes()
        if any('saniye' in ui.label(n) for n in ns):
            ok_seen = True
            pos = {}
            for n in ns:
                d = n.get('content-desc') or n.get('text') or ''
                if d in list('0123456789') and '_b' in n: pos.setdefault(d, ui.center(n))
            if all(c in pos for c in PIN):
                sh('shell', ';'.join(f'input tap {pos[c][0]} {pos[c][1]}' for c in PIN)); break
        if any('Anladım' in ui.label(n) for n in ns): tap('Anladım, devam et')
        time.sleep(0.3)
    time.sleep(8)
    st = state(slot)
    record(step, ok_seen and st == 'cancelled', f'countdown seen={ok_seen}; native {slot}={st}; {time.time()-t0:.1f}s')

def panic_cancel():
    home()
    sh('shell', 'logcat', '-c')
    ui.panic(); time.sleep(0.8)
    if has('Anladım, devam et', tries=2):  # first-use notice
        tap('Anladım, devam et'); time.sleep(2); ui.panic(); time.sleep(0.8)
    cancel_countdown('panic', 'panic -> countdown -> PIN cancel')

def timer(screen, slot, step):
    home()
    for _ in range(3): sh('shell', 'input', 'swipe', '540', '1700', '540', '700', '400'); time.sleep(0.6)
    tap(screen, exact=True); time.sleep(3)
    if not tap('15 dk', exact=True): tap('5 dk', exact=True)
    time.sleep(3)
    # Safe Walk only selects the duration; the walk starts on its own button.
    if has('Yürüyüşe Başla', tries=2): tap('Yürüyüşe Başla', exact=True); time.sleep(3)
    if has('Bildirim izni gerekli', tries=2): tap('Kabul Et', clickable=True); time.sleep(2)
    tap('Anladım, devam et'); time.sleep(3)
    started = state(slot) == 'armed'
    tap('İptal Et'); time.sleep(2)
    f = fields()
    if f:
        x, y = ui.center(f[0]); sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(0.5); sh('shell', 'input', 'text', PIN); time.sleep(0.5)
        tap('Doğrula', exact=True); time.sleep(3)
    record(step, started and state(slot) == 'cancelled', f'armed={started}; native {slot}={state(slot)}')
    sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1)

def quick(kind):
    sh('shell', 'input', 'keyevent', 'KEYCODE_HOME'); time.sleep(1)
    if kind == 'widget':
        sh('shell', 'am', 'start', '-n', f'{PKG}/com.poyrazoncel.korubeni.quickaccess.QuickPanicTrampolineActivity', '--es', PANIC_SOURCE_EXTRA, 'widget')
    else:
        comp = f'{PKG}/com.poyrazoncel.korubeni.quickaccess.PanicTileService'
        sh('shell', 'cmd', 'statusbar', 'add-tile', comp); time.sleep(1)
        sh('shell', 'cmd', 'statusbar', 'click-tile', comp)
    time.sleep(2)
    cancel_countdown('panic', f'{kind} quick panic -> countdown -> PIN cancel')

def link_map_timeline():
    sh('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'korubeni://open/settings', PKG); time.sleep(4); unlock_if_needed()
    record('deep link korubeni://open/settings', has('Ayarlar', tries=5))
    home(); tap('Harita', exact=True); time.sleep(5)
    if has('Konum Oturumu', tries=1) or has('Harita ve Konum', tries=1): tap('Anladım', clickable=True); time.sleep(2)
    record('map tab opens', has('Harita', tries=4), ' / '.join(l for l in labels() if 'Konum' in l or 'Harita' in l)[:160])
    sh('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'korubeni://open/timeline', PKG); time.sleep(4); unlock_if_needed()
    record('timeline via deep link', has('Zaman Çizelgesi', tries=5))

def kill_reopen():
    pid = sh('shell', 'pidof', PKG).strip()
    if pid: sh('shell', 'kill', '-9', pid)
    time.sleep(1); sh('shell', 'am', 'start', '-n', MAIN); time.sleep(7)
    ok = has('Uygulama kilidi', tries=5)
    unlock_if_needed()
    record('process kill -> reopen -> lock -> PIN -> app', ok and (has('Hoş Geldiniz', tries=3) or has('Zaman Çizelgesi', tries=2)))

def main():
    sh('shell', 'settings', 'put', 'global', 'auto_time', '0'); sh('shell', f'date @{int(time.time())}')
    sh('uninstall', PKG); out = sh('install', APK, timeout=300)
    upd = sh('shell', 'dumpsys', 'package', PKG)
    lut = re.search(r'lastUpdateTime=(\S+ \S+)', upd); flags = re.search(r'pkgFlags=\[([^\]]*)\]', upd)
    sdk = sh('shell', 'getprop', 'ro.build.version.sdk').strip()
    record('clean install', 'Success' in out, f'API {sdk}; lastUpdateTime {lut.group(1) if lut else "?"}; flags [{flags.group(1) if flags else "?"}]')
    sh('logcat', '-c')
    onboarding()
    inject_pro(); grant_all(); open_app()
    record('permissions granted + Pro test anchor -> home', home(), ' / '.join(l for l in labels() if 'Kurulum' in l or 'eksik' in l or 'hazır' in l.lower())[:160])
    panic_cancel()
    timer('Kontrol Noktası', 'long', 'Check-In 15 min -> PIN cancel')
    timer('Güvenli Yürüyüş', 'long', 'Safe Walk -> PIN cancel')
    quick('widget'); open_app()
    quick('tile'); open_app()
    link_map_timeline()
    kill_reopen()
    logs = sh('logcat', '-d', '-v', 'time', timeout=120)
    pids = set(re.findall(r'Start proc (\d+):' + re.escape(PKG), logs))
    bad = []
    lines = logs.splitlines()
    for i, l in enumerate(lines):
        if re.search(r'FATAL EXCEPTION|ANR in ' + re.escape(PKG) + r'|Unhandled Exception|flutter_framework_unhandled|MissingPluginException|PlatformException|SQLiteException|SecurityException', l) and 'EGL Error' not in l:
            m = re.match(r'\S+ \S+ \w/[^(]*\(\s*(\d+)\)', l)
            nxt = lines[i + 1] if i + 1 < len(lines) else ''
            if (m and m.group(1) in pids) or PKG in l or ('FATAL EXCEPTION' in l and PKG in nxt):
                bad.append(l[:180])
    record('logcat review (app processes)', not bad, f'{len(bad)} lines' + ('' if not bad else ': ' + bad[0]))
    with open(OUT, 'a') as f:
        f.write(f'\n## {LABEL}\n| Step | Result | Observed |\n|---|---|---|\n')
        for s, r, d in rows: f.write(f'| {s} | {r} | {d} |\n')
        if bad:
            f.write('\n```\n' + '\n'.join(bad[:30]) + '\n```\n')

if __name__ == '__main__':
    main()
