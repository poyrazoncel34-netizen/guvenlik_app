#!/usr/bin/env python3
"""Per-fix runtime probes on the release candidate (closure audit 2026-10-10).

usage: ANDROID_SERIAL=<serial> rc_fix_probes.py <out.md> <build label>

Needs: the app installed + onboarded (PIN 2468, contact 05551234567), the test
Pro anchor, a rooted emulator started with -no-audio. Every probe records what
the screen and the native session store actually showed; the emergency call
goes only to the emulator-controlled number.

  P1 Safe Walk intro (A-03 follow-up)     P5 Y-11: exact alarm only -> own toggle
  P2 Help FAQ (Y-09)                      P6 Y-02: accepted request + quiet link
  P3 Y-11c limited-protection heading     P7 Y-14: revoke during Check-In -> notice
  P4 Y-11b both denied -> refusal + dialer P8 A-03: warning fails -> timeline reason
  P9 force-stop during an armed Check-In -> reopen restores its alarms (API 29-34 defect)
"""
import os, re, subprocess, sys, time
_out, _label = sys.argv[1], sys.argv[2]
sys.argv = [sys.argv[0], 'x.apk', 'com.poyrazoncel.korubeni', 'probe', '/dev/null']
sys.path.insert(0, os.path.dirname(__file__))
import runtime_matrix as rm
import ui

PKG = rm.PKG
PIN = '2468'
rows = []


def sh(*a, timeout=120):
    return rm.sh(*a, timeout=timeout)


def record(pid, ok, detail):
    rows.append((pid, 'PASS' if ok else 'FAIL', detail.replace('|', '/').replace('\n', ' ')[:300]))
    print(f'{pid}: {"PASS" if ok else "FAIL"} {detail[:160]}', flush=True)


def focus():
    m = re.search(r'mCurrentFocus=Window\{[^ ]+ [^ ]+ ([^}]+)\}', sh('shell', 'dumpsys', 'window', 'displays'))
    return m.group(1) if m else ''


def calls():
    return len(set(re.findall(r'TC@\d+', sh('shell', 'dumpsys', 'telecom'))))


def text():
    return ' / '.join(l for l in rm.labels() if l.strip())


def open_unlocked():
    sh('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP'); sh('shell', 'wm', 'dismiss-keyguard')
    sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(6)
    rm.unlock_if_needed()
    if rm.has('Kapat', tries=1) and rm.has('Hiçbir işlem', tries=1):
        rm.tap('Kapat', exact=True); time.sleep(1.5)
    # The app restores its last route (e.g. the timeline, which has no tab bar).
    # BACK from the app's own home would leave the app: relaunch whenever focus left it.
    for _ in range(4):
        if PKG not in focus():
            sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(4); rm.unlock_if_needed()
        if rm.has('Hoş Geldiniz', tries=2): return True
        if rm.home(): return True
        sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1.5)
    return rm.has('Hoş Geldiniz', tries=2)


def appops_exact(mode):
    sh('shell', 'appops', 'set', '--uid', PKG, 'SCHEDULE_EXACT_ALARM', mode)
    sh('shell', 'appops', 'set', PKG, 'SCHEDULE_EXACT_ALARM', mode)


def panic():
    rm.home(); ui.panic(); time.sleep(2.5)
    if rm.has('Anladım, devam et', tries=1):
        rm.tap('Anladım, devam et'); time.sleep(2); ui.panic(); time.sleep(2.5)


def pin_on_countdown():
    pos = {}
    for n in ui.nodes():
        d = n.get('content-desc') or n.get('text') or ''
        if d in list('0123456789') and '_b' in n: pos.setdefault(d, ui.center(n))
    if all(c in pos for c in PIN):
        sh('shell', ';'.join(f'input tap {pos[c][0]} {pos[c][1]}' for c in PIN)); return True
    return False


def to_home_tile(name):
    rm.home()
    for _ in range(3): sh('shell', 'input', 'swipe', '540', '1700', '540', '700', '400'); time.sleep(0.6)
    rm.tap(name, exact=True); time.sleep(3)


def p1_safe_walk_intro():
    to_home_tile('Güvenli Yürüyüş')
    t = text()
    ok = '60 saniyelik' in t and 'gösterilmeye çalışılır' in t and 'açıkken' not in t
    m = re.search(r'Bir zamanlayıcı[^/]*', t)
    record('P1 Safe Walk intro', ok, m.group(0) if m else t[:200])
    sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1)


def p2_help_faq():
    rm.home(); rm.tap('Ayarlar', exact=True); time.sleep(2)
    for _ in range(4):
        if rm.tap('Yardım & Destek', tries=1): break
        sh('shell', 'input', 'swipe', '540', '1700', '540', '900', '300'); time.sleep(0.8)
    time.sleep(2)
    for _ in range(3):
        if 'Konum pil' in text(): break
        sh('shell', 'input', 'swipe', '540', '1700', '540', '900', '300'); time.sleep(0.8)
    t = text()
    m = re.search(r'S: Konum[^/]*', t)
    record('P2 Help FAQ (Y-09)', 'Konum pil tüketiyor mu?' in t and 'Konum oturumu' not in t, m.group(0) if m else t[:200])
    sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1)


def p3_limited_heading():
    appops_exact('allow'); sh('shell', 'pm', 'revoke', PKG, 'android.permission.CALL_PHONE'); time.sleep(1)
    open_unlocked(); c0 = calls(); panic()
    t = text(); native = rm.state('panic')
    heading = 'Sınırlı koruma — uygulama kapanırsa arama yapılmaz' in t
    pinned = pin_on_countdown(); time.sleep(4)
    record('P3 Y-11c CALL_PHONE refused -> limited heading', heading and native == 'none' and pinned and calls() == c0
           and 'com.android.dialer' not in focus(),
           f'heading={heading} native={native} pin={pinned} calls+={calls() - c0} focus={focus()}')


def p4_both_denied():
    appops_exact('default'); time.sleep(1)
    open_unlocked(); c0 = calls(); panic()
    t = text()
    refusal = 'Arka plan koruması kapalı' in t and 'Arka plan korumasını aç' in t and 'Şimdi Ara' in t
    time.sleep(12)
    no_countdown = not rm.has('saniye kaldı', tries=1)
    rm.tap('Şimdi Ara', exact=True); time.sleep(3)
    f = focus(); dial = 'com.android.dialer' in f and '05551234567' in text()
    record('P4 Y-11b both refused -> exact-alarm refusal; manual call opens dialer only',
           refusal and no_countdown and dial and calls() == c0,
           f'refusal={refusal} no_countdown_12s={no_countdown} dialer={dial} calls+={calls() - c0}')
    sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); sh('shell', 'input', 'keyevent', 'KEYCODE_BACK')
    sh('shell', 'am', 'force-stop', 'com.android.dialer')


def p5_exact_only():
    sh('shell', 'pm', 'grant', PKG, 'android.permission.CALL_PHONE')
    open_unlocked(); panic()
    refusal = rm.has('Arka plan koruması kapalı', tries=2)
    rm.tap('Arka plan korumasını aç', exact=True); time.sleep(3)
    f = focus(); t = text()
    own = 'com.android.settings' in f and ('KoruBeni' in t or 'korubeni' in t.lower())
    record("P5 Y-11 exact alarm refused -> refusal; button opens this app's own toggle",
           refusal and own, f'refusal={refusal} focus={f} page={t[:120]}')
    sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1)
    if rm.has('Kapat', tries=1): rm.tap('Kapat', exact=True)


def p6_accepted_request():
    appops_exact('allow'); time.sleep(1)
    open_unlocked(); c0 = calls(); panic()
    armed = rm.state('panic')
    time.sleep(16)
    native = rm.state('panic')
    sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(4)
    shot = subprocess.run([ui.ADB, 'exec-out', 'screencap', '-p'], capture_output=True).stdout
    open(os.path.join(os.path.dirname(_out), 'p6_accepted_request.png'), 'wb').write(shot)
    c1 = calls()
    sh('shell', 'input', 'tap', '573', '1835'); time.sleep(3)   # quiet link (fixed bottom area)
    f = focus(); c2 = calls()
    record('P6 Y-02 accepted request: one call; quiet link opens dialer, places none',
           armed == 'armed' and native == 'requestSubmittedUnconfirmed' and c1 - c0 == 1 and c2 == c1
           and 'com.android.dialer' in f,
           f'arm={armed} native={native} calls_after_dispatch=+{c1 - c0} calls_after_link=+{c2 - c1} focus={f} (shot p6_accepted_request.png)')
    sh('shell', 'input', 'keyevent', 'KEYCODE_ENDCALL'); sh('shell', 'am', 'force-stop', 'com.android.dialer')
    # The result screen animates, so uiautomator cannot see it: leave it by its
    # home button (bottom centre on 1080x2400), not by label.
    sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(3)
    sh('shell', 'input', 'tap', '540', '2016'); time.sleep(3)


def p7_revoke_during_checkin():
    open_unlocked(); to_home_tile('Kontrol Noktası')
    if not rm.tap('15 dk', exact=True): rm.tap('5 dk', exact=True)
    time.sleep(3); rm.tap('Anladım, devam et'); time.sleep(3)
    armed = rm.state('long')
    appops_exact('default'); time.sleep(2)
    killed = not sh('shell', 'pidof', PKG).strip()
    open_unlocked(); to_home_tile('Kontrol Noktası')
    notice = rm.has('Arka plan koruması kapalı veya doğrulanamıyor', tries=4)
    rm.tap('Arka plan koruması kapalı veya doğrulanamıyor'); time.sleep(3)
    settings = 'com.android.settings' in focus()
    appops_exact('allow'); sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(4)
    gone = not rm.has('Arka plan koruması kapalı veya doğrulanamıyor', tries=2)
    exact = sh('shell', 'dumpsys', 'alarm').count('exactAllowReason=permission')
    rm.tap('İptal Et'); time.sleep(2)
    f = rm.fields()
    if f:
        x, y = ui.center(f[0]); sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(0.5)
        sh('shell', 'input', 'text', PIN); time.sleep(0.5); rm.tap('Doğrula', exact=True); time.sleep(3)
    record('P7 Y-14 revoke during Check-In -> notice -> settings -> re-grant restores exact alarms',
           armed == 'armed' and killed and notice and settings and gone and exact >= 2 and rm.state('long') == 'cancelled',
           f'armed={armed} process_killed={killed} notice={notice} settings={settings} notice_gone={gone} exact_alarms={exact} end={rm.state("long")}')


def p8_warning_fails():
    open_unlocked(); c0 = calls(); to_home_tile('Kontrol Noktası')
    # Check-In offers no 5-minute option (15 dk is the shortest): 15 min + 60 s grace.
    rm.tap('15 dk', exact=True); time.sleep(3); rm.tap('Anladım, devam et'); time.sleep(3)
    armed = rm.state('long')
    sh('shell', 'input', 'keyevent', 'KEYCODE_HOME')
    sh('shell', 'pm', 'revoke', PKG, 'android.permission.POST_NOTIFICATIONS')
    deadline = time.time() + 19 * 60
    while time.time() < deadline and rm.state('long') not in ('requestSubmittedUnconfirmed', 'manualActionRequired', 'failed'):
        time.sleep(10)
    final = rm.state('long')
    session = sh('shell', 'cat', f'/data/user_de/0/{PKG}/shared_prefs/korubeni_emergency_session_v1.xml')
    outcome = re.search(r'session_long_graceWarningOutcome">(\w+)<', session)
    sh('shell', 'pm', 'grant', PKG, 'android.permission.POST_NOTIFICATIONS')
    sh('shell', 'input', 'keyevent', 'KEYCODE_ENDCALL'); time.sleep(2)
    sh('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'korubeni://open/timeline', PKG); time.sleep(5)
    rm.unlock_if_needed(); time.sleep(2)
    reason = 'Son uyarı bildirimi gösterilemedi' in text()
    record('P8 A-03 final warning fails -> single call at the final deadline + timeline reason',
           armed == 'armed' and final == 'requestSubmittedUnconfirmed' and bool(outcome) and outcome.group(1) == 'failed'
           and calls() - c0 == 1 and reason,
           f'armed={armed} final={final} graceWarningOutcome={outcome.group(1) if outcome else None} calls+={calls() - c0} timeline_reason={reason}')


def pending_alarms():
    on, n = False, 0
    for line in sh('shell', 'dumpsys', 'alarm').splitlines():
        if re.search(r'Pending alarm batches|Next alarm clock information', line): on = True
        elif re.search(r'App Alarm history|Past-due|LazyAlarmStore stats|Pending user blocked', line): on = False
        elif on and re.search(r'walarm\*:' + re.escape(PKG) + r'\.EMERGENCY_SESSION_(?:GRACE|DISPATCH)', line): n += 1
    return n


def p9_force_stop_restores_alarms():
    # 2026-10-10, API 29: force-stop deleted an armed Check-In's alarms and reopening restored none.
    open_unlocked(); to_home_tile('Kontrol Noktası')
    if not rm.tap('15 dk', exact=True): rm.tap('5 dk', exact=True)
    time.sleep(3); rm.tap('Anladım, devam et'); time.sleep(3)
    armed, a0 = rm.state('long'), pending_alarms()
    sh('shell', 'am', 'force-stop', PKG); time.sleep(2)
    a1 = pending_alarms()
    sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(12)
    a2, st = pending_alarms(), rm.state('long')
    rm.unlock_if_needed(); to_home_tile('Kontrol Noktası')
    rm.tap('İptal Et'); time.sleep(2)
    f = rm.fields()
    if f:
        x, y = ui.center(f[0]); sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(0.5)
        sh('shell', 'input', 'text', PIN); time.sleep(0.5); rm.tap('Doğrula', exact=True); time.sleep(3)
    record('P9 force-stop during an armed Check-In -> reopen restores its alarms',
           armed == 'armed' and a0 >= 2 and a1 == 0 and a2 == a0 and st == 'armed' and rm.state('long') == 'cancelled',
           f'armed={armed} pending={a0} -> force-stop {a1} -> reopen {a2}; native after reopen={st}; end={rm.state("long")}')


def main():
    lut = re.search(r'lastUpdateTime=(\S+ \S+)', sh('shell', 'dumpsys', 'package', PKG))
    sdk = sh('shell', 'getprop', 'ro.build.version.sdk').strip()
    sh('shell', 'settings', 'put', 'global', 'auto_time', '0')
    for p in ['CALL_PHONE', 'ACCESS_FINE_LOCATION', 'POST_NOTIFICATIONS']:
        sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')
    probes = (p1_safe_walk_intro, p2_help_faq, p3_limited_heading, p4_both_denied, p5_exact_only,
              p6_accepted_request, p7_revoke_during_checkin, p8_warning_fails, p9_force_stop_restores_alarms)
    only = os.environ.get('PROBES')  # e.g. PROBES=p7,p8 re-runs just those
    if only:
        probes = [p for p in probes if p.__name__.split('_')[0] in only.split(',')]
    for probe in probes:
        try:
            probe()
        except Exception as exc:  # a probe that crashes is a FAIL row, never a silent skip
            record(probe.__name__, False, f'probe error: {exc!r}')
    with open(_out, 'a') as f:
        f.write(f'\n## {_label} — API {sdk}, lastUpdateTime {lut.group(1) if lut else "?"}\n| Probe | Result | Observed |\n|---|---|---|\n')
        for r in rows: f.write(f'| {r[0]} | {r[1]} | {r[2]} |\n')


if __name__ == '__main__':
    main()
