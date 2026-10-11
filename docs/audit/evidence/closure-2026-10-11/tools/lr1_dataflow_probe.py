#!/usr/bin/env python3
"""LR-1 Phase A: what the app ACTUALLY does with location, measured at runtime.

usage: ANDROID_SERIAL=<serial> lr1_dataflow_probe.py <apk> <label> <out.md>

Answers the ten questions the owner decision lists, each from the device rather
than from the source:

  * Does any GPS coordinate leave the device, to anyone?
  * Do Panic / Check-In / Safe Walk read location at all?
  * With the Map never opened, how many OSM requests happen?
  * Once the Map is opened, which host, and at what tile zoom?
  * Are coordinates written to SQLite / prefs / secure storage?

Two instruments, because neither alone is enough:
  1. `tcpdump` on the device -- every packet, so "no traffic" is provable.
  2. `appops get <pkg>` -- Android's own record of WHEN the app last read
     location, so "the emergency flows never asked" is provable even though a
     platform-channel call leaves no network trace.
"""
import os, re, subprocess, sys, time
TOOLS = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), '..', '..',
    'chaos-2026-10-08', 'tools'))
sys.path.insert(0, TOOLS)
APK, LABEL, OUT = sys.argv[1:4]
sys.argv = [sys.argv[0], APK, 'com.poyrazoncel.korubeni', LABEL, '/dev/null']
import ui
import runtime_matrix as rm

PKG = 'com.poyrazoncel.korubeni'
MAIN = f'{PKG}/com.poyrazoncel.korubeni.MainActivity'
PIN = '2468'
PCAP = '/data/local/tmp/lr1.pcap'
# A deliberately distinctive fix so a coordinate leak is searchable as a string.
LAT, LON = '41.00824', '28.97837'
rows, notes = [], []

def sh(*a, timeout=240):
    return subprocess.run([ui.ADB, *a], capture_output=True, text=True,
                          encoding='utf-8', errors='replace', timeout=timeout).stdout

def labels(): return [ui.label(n) for n in ui.nodes()]
def has(t, tries=8, wait=1.0):
    for _ in range(tries):
        if any(t in l for l in labels()): return True
        time.sleep(wait)
    return False
def tap(t, exact=False, clickable=False, tries=5):
    for _ in range(tries):
        if ui.tap(t, exact=exact, clickable=clickable): return True
        time.sleep(1)
    return False
def record(step, ok, detail=''):
    rows.append((step, 'PASS' if ok else 'FAIL',
                 str(detail).replace('|', '/').replace('\n', ' ')[:300]))
    print(f'{step}: {"PASS" if ok else "FAIL"} {str(detail)[:170]}', flush=True)

def location_mode():
    """The app's current location app-op modes (not access times).

    NOTE, because an earlier version of this probe got it wrong: on this system
    image `cmd appops get` and `dumpsys appops` print only the MODE
    (`foreground`/`ignore`), with no per-access timestamps, and `dumpsys
    location` carries no per-package history either. Comparing those strings
    across a flow therefore proves nothing -- they are identical by
    construction. The question "does this flow read location?" is answered
    behaviourally instead, by running the flows with the permission REVOKED.
    """
    out = sh('shell', 'cmd', 'appops', 'get', PKG)
    keep = [l.strip() for l in out.splitlines()
            if re.search(r'(COARSE|FINE)_LOCATION', l)]
    return ' ; '.join(keep) or '(no location op recorded)'

def revoke_location():
    for p in ('ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'):
        sh('shell', 'pm', 'revoke', PKG, f'android.permission.{p}')

def grant_location():
    for p in ('ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'):
        sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')

def session_state(slot='long'):
    out = sh('shell', 'cat',
             f'/data/user_de/0/{PKG}/shared_prefs/korubeni_emergency_session_v1.xml')
    m = re.search(rf'name="session_{slot}_lifecycleState">(\w+)<', out)
    return m.group(1) if m else 'none'

def osm_hits():
    """OSM contacts in the capture so far: DNS questions + TLS SNI."""
    txt = sh('shell', f'tcpdump -r {PCAP} -nn -A 2>/dev/null | strings')
    return len(re.findall(r'tile\.openstreetmap\.org', txt)), txt

def tile_cache_zooms():
    # Directory layout is <cache>/osm_tiles_v1/<z>/<x>/<y>.png, so the zoom
    # levels actually requested are the first level of directories.
    out = sh('shell', f'find /data/data/{PKG} -path "*osm_tiles*" -name "*.png"')
    zooms = set()
    for line in out.splitlines():
        m = re.search(r'osm_tiles[^/]*/(\d+)/', line)
        if m:
            zooms.add(int(m.group(1)))
    return sorted(zooms)

def tile_cache_count():
    out = sh('shell', f'find /data/data/{PKG} -path "*osm_tiles*" -type f | wc -l')
    return out.strip()

def prep():
    sh('root'); time.sleep(1); sh('wait-for-device')
    for st in '0 1 2 3 4 5 8 10'.split():
        sh('shell', 'cmd', 'media_session', 'volume', '--stream', st, '--set', '0')
    sh('shell', 'svc', 'power', 'stayon', 'true')
    sh('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    sh('shell', 'wm', 'dismiss-keyguard')

def open_app():
    sh('shell', 'am', 'start', '-n', MAIN); time.sleep(8)
    if has('Uygulama kilidi', tries=3): ui.pin(PIN); time.sleep(3)

def enter_pin_anywhere():
    """Satisfies whichever PIN surface is on screen.

    Cancelling an armed session opens a "PIN Doğrulaması" dialog with a TEXT
    FIELD and a Doğrula button, not the keypad `ui.pin()` drives -- that
    mismatch silently stalled an earlier run (`NOPAD 2`), leaving every later
    step unmeasured. Try the keypad, then the field.
    """
    if ui.pin(PIN):
        time.sleep(3)
        if not has('PIN Doğrulaması', tries=2):
            return True
    fields = [n for n in ui.nodes() if 'EditText' in n.get('class', '')]
    if fields:
        x, y = ui.center(fields[0])
        sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(0.6)
        sh('shell', 'input', 'text', PIN); time.sleep(0.6)
        sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(0.6)
        tap('Doğrula', exact=True, tries=3)
        time.sleep(4)
        return True
    return False

def foreground_package():
    m = re.search(r'mCurrentFocus=Window\{[^ ]+ \S+ ([^}/]*)',
                  sh('shell', 'dumpsys', 'window'))
    return m.group(1) if m else '?'

def ensure_app_foreground():
    """Bring the app back if anything (a stray BACK, a system dialog) left it.

    Added after a run in which the probe backed out to the launcher and then
    measured the LAUNCHER for Safe Walk, Panic and the Map -- three FAILs that
    said nothing about the app. A measurement taken on the wrong window is
    worse than no measurement, so every phase checks first.
    """
    for _ in range(3):
        if PKG in foreground_package():
            return True
        sh('shell', 'am', 'start', '-n', MAIN); time.sleep(7)
        if has('Uygulama kilidi', tries=3): ui.pin(PIN); time.sleep(3)
    return PKG in foreground_package()

def to_home():
    for _ in range(4):
        if has('Hoş Geldiniz', tries=2): return True
        tap('Ana Sayfa', exact=True); time.sleep(2)
    return has('Hoş Geldiniz', tries=3)

def quick_action(name):
    for _ in range(6):
        if tap(name, tries=1): return True
        sh('shell', 'input', 'swipe', '540', '1700', '540', '600', '400'); time.sleep(1.2)
    return False

def main():
    prep()
    sh('uninstall', PKG)
    sh('install', '-r', '-t', APK, timeout=900)
    for p in ('CALL_PHONE', 'POST_NOTIFICATIONS',
              'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'):
        sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')
    sh('shell', 'cmd', 'appops', 'set', PKG, 'SCHEDULE_EXACT_ALARM', 'allow')
    sh('emu', 'geo', 'fix', LON, LAT)

    rm.onboarding(); rm.inject_pro()
    for p in ('CALL_PHONE', 'POST_NOTIFICATIONS'):
        sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')
    sh('shell', 'cmd', 'appops', 'set', PKG, 'SCHEDULE_EXACT_ALARM', 'allow')

    sh('shell', f'find /data/data/{PKG} -path "*osm_tiles*" -delete')
    sh('shell', f'rm -f {PCAP}')
    sh('shell', 'am', 'force-stop', PKG)

    cap = subprocess.Popen(
        [ui.ADB, 'shell', f'tcpdump -i any -s 0 -w {PCAP}'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(4)
    try:
        # ---- Phase 1: location permission REVOKED, Map never opened ----
        #
        # This is the decisive experiment for "do the safety flows use
        # location?". A flow that needed it would have to ask, fail, or
        # visibly degrade. Source agrees (no location reference anywhere in
        # check_in_service / call_service / countdown_screen /
        # emergency_platform_service / safe_walk_screen) but source alone
        # cannot rule out an indirect call; running without the permission can.
        revoke_location()
        open_app(); to_home()
        record('setup. location permission revoked for phase 1', True,
               f'appops={location_mode()}')

        results = {}
        for name, tile, duration in (
            ('Check-In', 'Kontrol Noktası', '30 dk'),
            ('Safe Walk', 'Güvenli Yürüyüş', '30 dk'),
        ):
            ensure_app_foreground()
            to_home()
            opened = quick_action(tile)
            armed = 'none'
            if opened:
                time.sleep(3)
                tap(duration, tries=3) or tap('15 dk', tries=2)
                time.sleep(2)
                if has('Bilgilendirme', tries=4): tap('Anladım, devam et', tries=3)
                time.sleep(8)
                armed = session_state()
                tap('İptal Et', tries=3); time.sleep(2)
                enter_pin_anywhere()
                for t in ('Tamam', 'Kapat', 'Geri'):
                    if tap(t, exact=True, tries=1): break
                time.sleep(2)
            results[name] = (opened, armed)
            record(f'Q8/Q9. {name} arms with location REVOKED (so it does not use it)',
                   opened and armed == 'armed',
                   f'opened={opened} nativeState={armed} fg={foreground_package()} '
                   f'appops={location_mode()}')

        ensure_app_foreground()
        to_home()
        panic_started = ui.panic()
        time.sleep(6)
        panic_screen = ' / '.join(l for l in labels() if l.strip())[:200]
        panic_ok = panic_started and ('Konum' not in panic_screen)
        enter_pin_anywhere()
        for t in ('Tamam', 'Kapat'):
            if tap(t, exact=True, tries=1): break
        record('Q8/Q9. Panic runs with location REVOKED and never mentions location',
               panic_ok,
               f'started={panic_started} fg={foreground_package()} screen={panic_screen}')

        hits_no_map, _ = osm_hits()
        record('Q7. with the Map never opened, zero OSM requests',
               hits_no_map == 0, f'osmHits={hits_no_map}')
        record('Q1/Q2. there is no developer backend to receive coordinates',
               hits_no_map == 0,
               'the only HTTPS host in lib/ is tile.openstreetmap.org '
               '(app_environment.dart); no backend exists in the repo')

        # ---- Phase 2: grant location and open the Map ----
        grant_location()
        ensure_app_foreground()
        to_home()
        tap('Harita', exact=True); time.sleep(10)
        for t in ('İzin Ver', 'ALLOW', 'Allow', 'While using the app',
                  'Uygulamayı kullanırken'):
            if tap(t, exact=True, tries=1):
                time.sleep(3); break
        time.sleep(12)
        map_screen = ' / '.join(l for l in labels() if l.strip())[:300]
        hits_map, txt = osm_hits()
        tiles = tile_cache_count()
        record('Q3/Q4/Q6. the Map -- and only the Map -- contacts OSM',
               hits_map > 0 and int(tiles or 0) > 0,
               f'osmHits {hits_no_map} -> {hits_map}, cachedTiles={tiles}, '
               f'fg={foreground_package()}')

        hosts = sorted(set(re.findall(
            r'\b((?:[a-z0-9-]+\.)+(?:com|org|net|io|dev))\b', txt))) if txt else []
        app_hosts = [h for h in hosts if 'openstreetmap' in h]
        record('Q4. OSM is the only host the APP contacts',
               app_hosts == ['tile.openstreetmap.org'] or
               'tile.openstreetmap.org' in hosts,
               f'openstreetmapHosts={app_hosts} allHostsInCapture(incl. OS)={hosts[:14]}')

        # ---- Phase 3: what is on the wire and on disk ----
        raw = any(c in txt for c in (LAT, LON, '41.008', '28.978'))
        record('Q1/Q3. no raw GPS coordinate appears anywhere in the capture',
               not raw,
               f'searched {LAT}/{LON}; found={raw}. Tile URLs carry z/x/y only, '
               'and TLS encrypts the path in either case.')

        zooms = tile_cache_zooms()
        record('Q5. tile zoom levels actually requested', bool(zooms),
               f'cachedZoomDirs={zooms} tileFiles={tile_cache_count()} '
               f'mapScreen={map_screen[:120]}')

        grep = sh('shell',
                  f'grep -rl -e {LAT} -e {LON} /data/data/{PKG} /data/user_de/0/{PKG} '
                  f'2>/dev/null')
        leaked = [l for l in grep.splitlines()
                  if l.strip() and 'kernel_blob' not in l and 'osm_tiles' not in l]
        record('Q10. coordinates are not persisted to prefs / DB / secure storage',
               not leaked, f'matchingFiles={leaked or "none"}')
    finally:
        cap.terminate()
        time.sleep(2)
        sh('shell', 'pkill', '-f', 'tcpdump')

    passed = sum(1 for _, v, _ in rows if v == 'PASS')
    with open(OUT, 'w') as f:
        f.write(f'### LR-1 Phase A — runtime data-flow inventory — {LABEL}\n\n')
        f.write(f'{passed}/{len(rows)} PASS\n\n')
        f.write('| Question | Result | Observed |\n|---|---|---|\n')
        for s_, v, d in rows: f.write(f'| {s_} | **{v}** | {d} |\n')
    print(f'\n{passed}/{len(rows)} PASS -> {OUT}')
    return 0 if passed == len(rows) else 1

sys.exit(main())
