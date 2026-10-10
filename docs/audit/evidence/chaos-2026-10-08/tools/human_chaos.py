#!/usr/bin/env python3
"""Human-like chaos driver on the REAL app UI (closure audit 2026-10-09).

usage: ANDROID_SERIAL=emulator-5556 human_chaos.py <seed> <sequences> <out.jsonl>

Each sequence is 3-12 impatient-user actions on whatever the screen shows:
random taps on live controls (double/triple taps included), back, home+reopen,
process kill+reopen, deep links, widget quick panic, rotation, screen off/on,
airplane mode, permission revoke/grant, clock jumps, swipes, wrong/right PINs.
After every sequence the invariants are checked against logcat and the native
session store. Destructive confirmations (data wipe, PIN change) are never
tapped: they would end the run, not test it.
"""
import json, os, random, re, subprocess, sys, time
sys.path.insert(0, os.path.dirname(__file__)); import ui
# Fixed key (PanicLaunch.kt), NOT applicationId-based: the smoke build's
# '<pkg>.smoke.extra...' was refused (fail-closed) and looked like a failure.
PANIC_SOURCE_EXTRA = 'com.poyrazoncel.korubeni.extra.PANIC_SOURCE'

PKG = 'com.poyrazoncel.korubeni'
SESSION = f'/data/user_de/0/{PKG}/shared_prefs/korubeni_emergency_session_v1.xml'
DENY = re.compile(r'(Temizle|Sil$|Sil\b|Verileri|PIN.?i Değiştir|PIN Değiştir|Şifremi Unuttum|Sıfırla|Hesabı|Abonelik|Satın|Restore|Geri Yükle|Paylaş|Uygulamayı Kaldır)', re.I)
LINKS = ['korubeni://open/timeline', 'korubeni://open/settings', 'korubeni://open/map', 'korubeni://open/checkin', 'korubeni://open/nowhere']
FATAL = re.compile(r'FATAL EXCEPTION|ANR in com\.poyrazoncel|Unhandled Exception|flutter_framework_unhandled|MissingPluginException|E/AndroidRuntime')
NOISE = re.compile(r'EGL Error: Success|egl\.cc')

def sh(*a, timeout=30):
    return subprocess.run([ui.ADB, *a], capture_output=True, text=True, encoding='utf-8',
                          errors='replace', timeout=timeout).stdout

def now(): return time.strftime('%H:%M:%S')

def clickables(ns):
    out = []
    for n in ns:
        if n.get('clickable') != 'true' or '_b' not in n: continue
        x1, y1, x2, y2 = n['_b']
        if x2 - x1 < 20 or y2 - y1 < 20: continue
        lab = ui.label(n)
        if DENY.search(lab): continue
        out.append((lab[:40], ui.center(n)))
    return out

def screen_name(ns):
    for n in ns:
        l = ui.label(n).strip('|')
        if l and 'KoruBeni güvenlik' not in l: return l[:40]
    return '?'

def foreground():
    out = sh('shell', 'dumpsys', 'window', 'displays')
    m = re.search(r'mCurrentFocus=Window\{[^ ]+ [^ ]+ ([\w.]+)', out)
    return m.group(1) if m else ''

def act(rng, log):
    fg = foreground()
    # Never drive another app: a stray tap in Settings or a browser could
    # change the device, not test KoruBeni. Return to the app instead.
    if fg and not fg.startswith(PKG) and fg not in ('com.android.systemui',):
        # The legal "(Web)" links open the emulator's only browser; BACK alone
        # left later sequences driving it. Close it, then return.
        if fg.startswith(('org.chromium.webview_shell', 'com.android.chrome')):
            sh('shell', 'am', 'force-stop', fg.split('/')[0])
        sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(0.4)
        sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); log.append(f'return_from:{fg}')
        time.sleep(1.0); return
    kind = rng.choices(
        ['tap', 'tap', 'tap', 'tap', 'double', 'triple', 'back', 'home_reopen', 'kill_reopen', 'link',
         'widget', 'rotate', 'screen', 'airplane', 'perm', 'clock', 'swipe', 'pin_right', 'pin_wrong'],
        weights=[6, 6, 6, 6, 2, 1, 4, 2, 1, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1])[0]
    ns = ui.nodes()
    if kind in ('tap', 'double', 'triple'):
        cs = clickables(ns)
        if not cs: kind = 'back'
        else:
            lab, (x, y) = rng.choice(cs)
            n = {'tap': 1, 'double': 2, 'triple': 3}[kind]
            sh('shell', ';'.join([f'input tap {x} {y}'] * n))
            log.append(f'{kind}:{lab}'); return
    if kind == 'back': sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); log.append('back')
    elif kind == 'home_reopen':
        sh('shell', 'input', 'keyevent', 'KEYCODE_HOME'); time.sleep(rng.uniform(0.3, 3))
        sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); log.append('home_reopen')
    elif kind == 'kill_reopen':
        pid = sh('shell', 'pidof', PKG).strip()
        if pid: sh('shell', 'kill', '-9', pid)
        time.sleep(rng.uniform(0.2, 1.5)); sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); log.append('kill_reopen')
    elif kind == 'link':
        l = rng.choice(LINKS); sh('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', l, PKG); log.append(f'link:{l}')
    elif kind == 'widget':
        sh('shell', 'am', 'start', '-n', f'{PKG}/.quickaccess.QuickPanicTrampolineActivity', '--es', PANIC_SOURCE_EXTRA, 'widget'); log.append('widget')
    elif kind == 'rotate':
        r = rng.choice(['0', '1', '3']); sh('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0'); sh('shell', 'settings', 'put', 'system', 'user_rotation', r); log.append(f'rotate:{r}')
    elif kind == 'screen':
        sh('shell', 'input', 'keyevent', 'KEYCODE_SLEEP'); time.sleep(rng.uniform(0.5, 4))
        sh('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP'); sh('shell', 'wm', 'dismiss-keyguard'); log.append('screen_off_on')
    elif kind == 'airplane':
        on = rng.choice(['enable', 'disable']); sh('shell', 'cmd', 'connectivity', 'airplane-mode', on); log.append(f'airplane:{on}')
    elif kind == 'perm':
        perm = rng.choice(['android.permission.CALL_PHONE', 'android.permission.ACCESS_FINE_LOCATION', 'android.permission.POST_NOTIFICATIONS'])
        op = rng.choice(['grant', 'grant', 'revoke']); sh('shell', 'pm', op, PKG, perm); log.append(f'perm:{op}:{perm.split(".")[-1]}')
    elif kind == 'clock':
        d = rng.choice([3600, -3600, 86400, -86400]); n = int(sh('shell', 'date', '+%s').strip() or '0')
        sh('shell', f'date @{n + d}'); log.append(f'clock:{d:+d}')
    elif kind == 'swipe':
        y1, y2 = rng.choice([(1700, 600), (600, 1700), (1200, 1100)]); sh('shell', 'input', 'swipe', '540', str(y1), '540', str(y2), str(rng.randint(80, 400))); log.append('swipe')
    elif kind in ('pin_right', 'pin_wrong'):
        ui.pin('2468' if kind == 'pin_right' else '1357', delay=0.05); log.append(kind)
    time.sleep(rng.uniform(0.2, 1.2))

_seen_anr = set()

def anr_check():
    """An ANR dialog or a fresh trace for KoruBeni: classify, dismiss, relaunch.

    The closure RC run (2026-10-10) sat 60+ sequences on an ANR dialog the old
    checker never saw. An ANR whose stack is the emulator GNSS HAL deadlock
    (app main thread in NmeaClient.stop -> unregisterGnssNmeaCallback, while
    system_server holds the NMEA lock inside GnssHal::stopNmea) is recorded as
    'env-gnss-hal-deadlock'; any other ANR is 'app' and fails the sequence.
    """
    labels = [ui.label(n) for n in ui.nodes()]
    dialog = any("isn't responding" in l for l in labels)
    newest = sh('shell', 'ls -t /data/anr/ 2>/dev/null | head -1').strip()
    fresh = bool(newest) and newest not in _seen_anr and newest.startswith('anr_')
    if not dialog and not fresh:
        return None
    kind = 'app'
    if fresh:
        _seen_anr.add(newest)
        subject = sh('shell', f'head -1 /data/anr/{newest}').strip()
        if PKG not in subject:
            fresh = False
        else:
            sig = sh('shell', f"grep -c -E 'NmeaClient.stop|unregisterGnssNmeaCallback|GnssHal::stopNmea' /data/anr/{newest}").strip()
            if sig.isdigit() and int(sig) >= 3:
                kind = 'env-gnss-hal-deadlock'
    if dialog:
        ui.tap('Close app', exact=True)
        time.sleep(1.0)
        sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(4)
    if not dialog and not fresh:
        return None
    return {'kind': kind, 'file': newest if fresh else '', 'dialog': dialog}

def session_states():
    xml = sh('shell', 'cat', SESSION)
    return dict(re.findall(r'name="session_(\w+)_lifecycleState">(\w+)<', xml))

def check(since_calls):
    logs = sh('shell', 'logcat', '-d', '-v', 'time', timeout=60)
    lines = logs.splitlines()
    # Only KoruBeni's own processes count: other apps' crashes are not ours.
    pids = set(re.findall(r'Start proc (\d+):' + re.escape(PKG), logs))
    cur = sh('shell', 'pidof', PKG).strip()
    if cur: pids.update(cur.split())
    def ours(l):
        m = re.match(r'\S+ \S+ \w/[^(]*\(\s*(\d+)\)', l)
        return (m and m.group(1) in pids) or PKG in l
    bad = []
    for i, l in enumerate(lines):
        if not FATAL.search(l) or NOISE.search(l): continue
        if 'FATAL EXCEPTION' in l:
            nxt = lines[i + 1] if i + 1 < len(lines) else ''
            if PKG not in nxt: continue
        elif not ours(l):
            continue
        bad.append(l[:200])
    created = [l for l in logs.splitlines() if 'CREATED, com.poyrazoncel.korubeni' in l]
    times = []
    for l in created:
        m = re.match(r'\d+-\d+ (\d+):(\d+):(\d+)\.(\d+)', l)
        if m: times.append(int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3)) + int(m.group(4)) / 1000)
    dup = any(b - a < 2.0 for a, b in zip(times, times[1:]))
    states = session_states()
    corrupt = [k for k, v in states.items() if v in ('corrupted',)]
    alive = bool(sh('shell', 'pidof', PKG).strip())
    return bad, len(created), dup, states, corrupt, alive

def main():
    seed, count, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    rng = random.Random(seed)
    sh('shell', 'settings', 'put', 'global', 'auto_time', '0')
    with open(out, 'a') as f:
        for i in range(count):
            sh('shell', 'logcat', '-c')
            pre = anr_check()
            ns = ui.nodes(); start = screen_name(ns); log = []
            if pre: log.append(f"anr_before:{pre['kind']}")
            t0 = now()
            for _ in range(rng.randint(3, 12)):
                try: act(rng, log)
                except subprocess.TimeoutExpired: log.append('timeout')
            time.sleep(1.5)
            anr = anr_check()
            try:
                bad, calls, dup, states, corrupt, alive = check(0)
            except subprocess.TimeoutExpired:
                bad, calls, dup, states, corrupt, alive = ['check timeout'], -1, False, {}, [], True
            if not alive:
                sh('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity'); time.sleep(4)
                alive_after = bool(sh('shell', 'pidof', PKG).strip())
            else: alive_after = True
            rec = {'seq': i, 'seed': seed, 'start': t0, 'end': now(), 'start_screen': start, 'actions': log,
                   'fatal': bad, 'telecom_requests': calls, 'duplicate_dispatch_lt2s': dup, 'sessions': states,
                   'corrupt': corrupt, 'relaunch_ok': alive_after, 'end_screen': screen_name(ui.nodes()),
                   'anr': anr}
            rec['ok'] = (not bad and not dup and not corrupt and alive_after
                         and not (anr and anr['kind'] == 'app'))
            f.write(json.dumps(rec, ensure_ascii=False) + '\n'); f.flush()
            print(f"{i:3d} {'OK ' if rec['ok'] else 'BAD'} {t0} {start!r} -> {rec['end_screen']!r} acts={len(log)} calls={calls} fatal={len(bad)} anr={anr['kind'] if anr else '-'}", flush=True)
            # restore a sane baseline every so often so the run keeps exploring
            if i % 10 == 9:
                sh('shell', 'cmd', 'connectivity', 'airplane-mode', 'disable')
                sh('shell', f'date @{int(time.time())}')
                for p in ['CALL_PHONE', 'ACCESS_FINE_LOCATION', 'POST_NOTIFICATIONS']:
                    sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')
                sh('shell', 'settings', 'put', 'system', 'user_rotation', '0')
                sh('shell', 'input', 'keyevent', 'KEYCODE_ENDCALL'); sh('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')

if __name__ == '__main__':
    main()
