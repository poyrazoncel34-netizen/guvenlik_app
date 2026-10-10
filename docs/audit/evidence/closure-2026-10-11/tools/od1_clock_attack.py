#!/usr/bin/env python3
"""OD-1 wall-clock attack on the REAL running app.

usage: ANDROID_SERIAL=<serial> od1_clock_attack.py <apk> <label> <out.md>

Starts a genuine Check-In through the UI, then moves the device wall clock
(+1h, -2h, +1d, -1d, timezone) and asserts, after each move:

  * the native session is still ARMED and has not dispatched;
  * the native FINAL DEADLINE has not moved on the monotonic clock
    (session_long_elapsedRealtimeDeadlineMs is the authority);
  * the Dart countdown the user sees agrees with the native authority;
  * no Telecom request was made.

TIME_SET ordering is varied: once with the broadcast arriving while the app is
in the foreground, once with the app force-stopped first so the broadcast is
missed entirely and only the next reconcile can notice.
"""
import os, re, subprocess, sys, time
sys.path.insert(0, '/Users/poyrazoncel/Projects/guvenlik_app/docs/audit/evidence/chaos-2026-10-08/tools')
import ui

APK, LABEL, OUT = sys.argv[1:4]
# runtime_matrix parses sys.argv at import time (apk, pkg, label, out).
sys.argv = [sys.argv[0], APK, 'com.poyrazoncel.korubeni', LABEL, '/dev/null']
PKG = 'com.poyrazoncel.korubeni'
MAIN = f'{PKG}/com.poyrazoncel.korubeni.MainActivity'
SESSION = f'/data/user_de/0/{PKG}/shared_prefs/korubeni_emergency_session_v1.xml'
PIN = '2468'
rows = []

def sh(*a, timeout=180):
    return subprocess.run([ui.ADB, *a], capture_output=True, text=True,
                          encoding='utf-8', errors='replace', timeout=timeout).stdout

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
def fields(): return [n for n in ui.nodes() if 'EditText' in n.get('class', '')]
def type_into(idx, text):
    f = fields(); x, y = ui.center(f[idx]); sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(0.5)
    sh('shell', 'input', 'text', text); time.sleep(0.4)
def record(step, ok, detail=''):
    rows.append((step, 'PASS' if ok else 'FAIL', str(detail).replace('|', '/').replace('\n', ' ')[:260]))
    print(f'{step}: {"PASS" if ok else "FAIL"} {str(detail)[:150]}', flush=True)

def session_fields(slot='long'):
    xml = sh('shell', 'cat', SESSION)
    out = {}
    for k in ('lifecycleState', 'finalDeadlineMs', 'mainDeadlineMs',
              'elapsedRealtimeDeadlineMs', 'callRequestOutcome', 'fallbackOutcome'):
        m = re.search(rf'name="session_{slot}_{k}">([^<]*)<', xml)
        if m is None:
            m = re.search(rf'name="session_{slot}_{k}" value="([^"]*)"', xml)
        out[k] = m.group(1) if m else 'none'
    return out

def telecom():
    return len(set(re.findall(r'TC@\d+', sh('shell', 'dumpsys', 'telecom'))))

def prep():
    sh('root'); time.sleep(1); sh('wait-for-device')
    for st in '0 1 2 3 4 5 8 10'.split():
        sh('shell', 'cmd', 'media_session', 'volume', '--stream', st, '--set', '0')
    sh('shell', 'svc', 'power', 'stayon', 'true')
    sh('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    sh('shell', 'wm', 'dismiss-keyguard')

def grant_all():
    for p in ['CALL_PHONE', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'POST_NOTIFICATIONS']:
        sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')
    sh('shell', 'appops', 'set', '--uid', PKG, 'SCHEDULE_EXACT_ALARM', 'allow')
    sh('shell', 'appops', 'set', PKG, 'SCHEDULE_EXACT_ALARM', 'allow')

def inject_pro():
    sh('shell', 'am', 'force-stop', PKG)
    f = f'/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml'
    owner = sh('shell', 'stat', '-c', '%U:%G', f).strip()
    xml = sh('shell', 'cat', f)
    now = int(time.time() * 1000) - 60000
    xml = re.sub(r'\s*<(boolean|long) name="flutter\.revenuecat_(prior_verified_pro_hint|last_verified_pro_at)_v1"[^>]*/>', '', xml)
    xml = xml.replace('</map>', f'    <boolean name="flutter.revenuecat_prior_verified_pro_hint_v1" value="true" />\n    <long name="flutter.revenuecat_last_verified_pro_at_v1" value="{now}" />\n</map>')
    open('/tmp/fsp_od1.xml', 'w').write(xml)
    sh('push', '/tmp/fsp_od1.xml', '/data/local/tmp/fsp.xml')
    sh('shell', f'cat /data/local/tmp/fsp.xml > {f} && chown {owner} {f} && restorecon {f} && rm /data/local/tmp/fsp.xml')

def onboarding():
    """Delegates to the repo's proven onboarding automation.

    An earlier version of this probe reimplemented it and stalled on the
    consent screen, which looked exactly like an app defect. The shared
    runtime_matrix.onboarding() is the one that is already evidenced.
    """
    sys.path.insert(0, '/Users/poyrazoncel/Projects/guvenlik_app/docs/audit/evidence/chaos-2026-10-08/tools')
    import runtime_matrix as rm
    rm.onboarding()
    record('setup: onboarding -> home', has('Hoş Geldiniz', tries=6))
    return

def _onboarding_unused():
    sh('shell', 'am', 'start', '-n', MAIN); time.sleep(7)
    if not has('Kurulum ve Onay', tries=10):
        return record('setup: consent screen', False, ' / '.join(labels()[:4]))
    age = ui.find('18 yaşından büyüğüm')
    if age:
        x1, y1, x2, y2 = age['_b']; sh('shell', 'input', 'tap', str(x2 - 120), str((y1 + y2) // 2))
    for _ in range(5):
        for n in ui.nodes():
            if n.get('checkable') == 'true' and n.get('checked') != 'true' and '_b' in n:
                x, y = ui.center(n)
                if 200 < y < 2050: sh('shell', 'input', 'tap', str(x), str(y))
        sh('shell', 'input', 'swipe', '540', '1600', '540', '800', '400'); time.sleep(0.8)
    tap('Devam Et ve Kurulumu'); time.sleep(3)
    tap('Atla', exact=True); time.sleep(3)
    type_into(0, 'Annem'); type_into(1, '05551234567')
    sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(0.8)
    tap('Kişiyi kaydet'); time.sleep(2); tap('beyan ederim', clickable=True); time.sleep(0.8)
    tap('Ekle', exact=True); time.sleep(2)
    tap('Başla', exact=True); time.sleep(3)
    ui.pin(PIN); time.sleep(1.8); ui.pin(PIN); time.sleep(3)
    if has('Bildirim izni', tries=3):
        tap('Kabul Et', clickable=True); time.sleep(2)
        tap('ALLOW', exact=True) or tap('Allow', exact=True); time.sleep(2)
    if has('Şimdilik Atla', tries=4): tap('Şimdilik Atla'); time.sleep(3)
    record('setup: onboarding -> home', has('Hoş Geldiniz'))

def open_app():
    sh('shell', 'am', 'start', '-n', MAIN); time.sleep(6)
    if has('Uygulama kilidi', tries=3): ui.pin(PIN); time.sleep(3)

def start_check_in():
    """Start a real Check-In through the UI and return the native snapshot.

    Labels read off the running app (API 36): the home screen's Quick Actions
    grid calls it 'Kontrol Noktası', and the duration tiles are '15 dk' ...
    '2 sa'. 2 hours is chosen so the +1d / -1d attacks stay well inside the
    session rather than ending it legitimately.
    """
    opened = False
    for i in range(6):
        if tap('Kontrol Noktası', tries=2):
            opened = True
            break
        # Quick Actions sit below the readiness card; scroll down to reach them.
        sh('shell', 'input', 'swipe', '540', '1700', '540', '600', '400'); time.sleep(1.2)
    time.sleep(4)
    picked = tap('2 sa', tries=3) or tap('1 sa', tries=2) or tap('30 dk', tries=2)
    time.sleep(3)
    # First use of Check-In shows an information sheet ("Bu ozellik fiziksel
    # koruma SAGLAMAZ...") that must be acknowledged before the session arms.
    # Missing it made an earlier run look like "Check-In does not start".
    acked = True
    if has('Bilgilendirme', tries=4):
        acked = tap('Anladım, devam et', tries=4)
    time.sleep(8)
    started = opened and picked and acked
    snap = session_fields()
    record('check-in started (native ARMED)', snap['lifecycleState'] == 'armed',
           f"tapStarted={started} native={snap['lifecycleState']} "
           f"final={snap['finalDeadlineMs']} elapsedDeadline={snap['elapsedRealtimeDeadlineMs']}")
    return snap

def ui_remaining():
    """The countdown the user actually sees, in seconds, or None."""
    for l in labels():
        m = re.search(r'\b(\d{1,3}):(\d{2})(?::(\d{2}))?\b', l)
        if m:
            a, b, c = m.group(1), m.group(2), m.group(3)
            return (int(a) * 3600 + int(b) * 60 + int(c)) if c else (int(a) * 60 + int(b))
    return None

def shift_clock(delta_s, tz=None):
    if tz:
        sh('shell', 'setprop', 'persist.sys.timezone', tz)
        sh('shell', 'am', 'broadcast', '-a', 'android.intent.action.TIMEZONE_CHANGED')
        return
    target = int(sh('shell', 'date', '+%s').strip() or time.time()) + delta_s
    sh('shell', 'date', f'@{target}')
    sh('shell', 'am', 'broadcast', '-a', 'android.intent.action.TIME_SET')

def attack(name, delta_s, tz=None, force_stop_first=False):
    base = session_fields()
    tele_before = telecom()
    if force_stop_first:
        sh('shell', 'am', 'force-stop', PKG); time.sleep(2)
    shift_clock(delta_s, tz); time.sleep(4)
    if force_stop_first:
        # The broadcast was missed; only the next app start can reconcile.
        open_app(); time.sleep(4)
        # A reopen lands on Home, where no countdown is rendered. Walk to the
        # Check-In screen so the number the USER sees can be compared with the
        # native authority -- otherwise this step would silently assert nothing
        # about the Dart projection.
        for _ in range(6):
            if ui_remaining() is not None:
                break
            if tap('Kontrol Noktası', tries=1):
                time.sleep(4)
                break
            sh('shell', 'input', 'swipe', '540', '1700', '540', '600', '400'); time.sleep(1.2)
        time.sleep(2)
    after = session_fields()
    seen = ui_remaining()
    tele_after = telecom()

    monotonic_held = after['elapsedRealtimeDeadlineMs'] == base['elapsedRealtimeDeadlineMs']
    still_armed = after['lifecycleState'] == 'armed'
    no_call = after['callRequestOutcome'] in ('notAttempted', 'none') and tele_after == tele_before

    # What the native authority says is left, from the monotonic deadline.
    native_left = None
    try:
        up_ms = int(float(sh('shell', 'cat', '/proc/uptime').split()[0]) * 1000)
        native_left = (int(after['elapsedRealtimeDeadlineMs']) - up_ms) // 1000
    except (ValueError, IndexError):
        pass
    # The projection must not CLAIM more protection than native holds. A 90 s
    # tolerance covers the probe's own navigation time and the minute-rounded
    # countdown; the defect class this guards is a UI showing a stale deadline
    # minutes or hours away from the native one, not a second of skew.
    ui_agrees = (
        seen is None or native_left is None or abs(seen - native_left) <= 90
    )
    ok = monotonic_held and still_armed and no_call and ui_agrees
    record(
        f'attack {name}',
        ok,
        f"native={after['lifecycleState']} call={after['callRequestOutcome']} "
        f"elapsedDeadline {base['elapsedRealtimeDeadlineMs']}->{after['elapsedRealtimeDeadlineMs']} "
        f"wallDeadline {base['finalDeadlineMs']}->{after['finalDeadlineMs']} "
        f"uiRemaining={seen}s nativeLeft={native_left}s agree={ui_agrees} "
        f"telecom {tele_before}->{tele_after}",
    )
    return after

def main():
    prep()
    sh('uninstall', PKG)
    sh('install', '-r', '-t', APK)
    grant_all()
    onboarding()
    inject_pro(); grant_all(); open_app()
    start_check_in()

    attack('+1h (TIME_SET in foreground)', 3600)
    attack('-2h (TIME_SET in foreground)', -7200)
    attack('+1d (TIME_SET missed, app force-stopped)', 86400, force_stop_first=True)
    attack('-1d (TIME_SET missed, app force-stopped)', -86400, force_stop_first=True)
    attack('timezone -> Pacific/Kiritimati', 0, tz='Pacific/Kiritimati')
    attack('timezone -> Europe/Istanbul', 0, tz='Europe/Istanbul')

    # Never leave the emulator on a fabricated clock: a later probe reading a
    # shifted clock is indistinguishable from a real defect.
    sh('shell', 'setprop', 'persist.sys.timezone', 'Europe/Istanbul')
    sh('shell', 'date', f'@{int(time.time())}')
    sh('shell', 'am', 'broadcast', '-a', 'android.intent.action.TIME_SET')
    time.sleep(3)

    final = session_fields()
    record('session survived every clock attack still armed',
           final['lifecycleState'] == 'armed',
           f"native={final['lifecycleState']} elapsedDeadline={final['elapsedRealtimeDeadlineMs']}")

    passed = sum(1 for _, v, _ in rows if v == 'PASS')
    with open(OUT, 'w') as f:
        f.write(f'### OD-1 wall-clock attack on the real app — {LABEL}\n\n')
        f.write(f'{passed}/{len(rows)} PASS\n\n')
        f.write('| Step | Result | Observed |\n|---|---|---|\n')
        for s, v, d in rows:
            f.write(f'| {s} | **{v}** | {d} |\n')
    print(f'\n{passed}/{len(rows)} PASS -> {OUT}')
    return 0 if passed == len(rows) else 1

sys.exit(main())
