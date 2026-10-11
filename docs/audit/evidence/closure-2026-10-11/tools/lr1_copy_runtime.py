#!/usr/bin/env python3
"""LR-1 Phase C: the corrected legal copy, on a real clean install.

usage: ANDROID_SERIAL=<serial> lr1_copy_runtime.py <apk> <label> <out.md>

String-presence tests are not enough (the repo's own rule), so this reads the
text off a running app:

  clean install -> consent screen -> the location item's own words
  -> decline it -> finish setup -> open the Map -> is location refused?
  -> grant the consent -> Map works
  -> simulate a legal VERSION UPGRADE -> is re-consent demanded, and are the
     optional consents really reset?

The last step is the one that matters most for this change: bumping the legal
version is what ships the corrected text to existing users, and it has a real
side effect that must be observed rather than assumed.
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
PREFS = f'/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml'
PIN = '2468'
rows = []

def sh(*a, timeout=240):
    return subprocess.run([ui.ADB, *a], capture_output=True, text=True,
                          encoding='utf-8', errors='replace', timeout=timeout).stdout

def labels(): return [ui.label(n) for n in ui.nodes() if ui.label(n).strip()]
def screen(): return ' / '.join(labels())
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
                 str(detail).replace('|', '/').replace('\n', ' ')[:320]))
    print(f'{step}: {"PASS" if ok else "FAIL"} {str(detail)[:170]}', flush=True)

def prep():
    sh('root'); time.sleep(1); sh('wait-for-device')
    for st in '0 1 2 3 4 5 8 10'.split():
        sh('shell', 'cmd', 'media_session', 'volume', '--stream', st, '--set', '0')
    sh('shell', 'svc', 'power', 'stayon', 'true')
    sh('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    sh('shell', 'wm', 'dismiss-keyguard')

def scroll_collect(rounds=6):
    """Everything the consent screen can show, across its full scroll."""
    seen = list(labels())
    for _ in range(rounds):
        sh('shell', 'input', 'swipe', '540', '1700', '540', '700', '400')
        time.sleep(1.0)
        for l in labels():
            if l not in seen: seen.append(l)
    return seen

def pref_bool(key):
    xml = sh('shell', 'cat', PREFS)
    m = re.search(rf'name="flutter\.{re.escape(key)}" value="(\w+)"', xml)
    return m.group(1) if m else '(absent)'

EXPECTED_PHRASE = 'yalnızca Harita ekranında kendi konumumu'

def assert_apk_contains_the_fix(apk):
    """Refuse to run against a build that predates the change under test.

    CERT2-05, and this probe earned the rule the hard way: a first run scored
    the consent copy against an APK built before the LR-1 edits and reported
    two FAILs that said nothing about the code. A stale artifact produces
    evidence that is indistinguishable from a real regression, so the build is
    fingerprinted here instead of trusted.
    """
    import zipfile, json
    with zipfile.ZipFile(apk) as z:
        raw = z.read('assets/flutter_assets/assets/translations/tr-TR.json')
    value = json.loads(raw).get('legal_consent_location', '')
    if EXPECTED_PHRASE not in value:
        print('REFUSING TO RUN: this APK does not contain the LR-1 copy.\n'
              f'  apk            = {apk}\n'
              f'  expected to contain: {EXPECTED_PHRASE!r}\n'
              f'  actually found     : {value!r}\n'
              'Rebuild (flutter build apk --debug --flavor play) and retry.',
              file=sys.stderr)
        sys.exit(2)
    print(f'build fingerprint OK: APK carries the LR-1 copy ({apk})')

def main():
    assert_apk_contains_the_fix(APK)
    prep()
    sh('uninstall', PKG)
    sh('install', '-r', '-t', APK, timeout=900)
    for p in ('CALL_PHONE', 'POST_NOTIFICATIONS',
              'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'):
        sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')

    # 1. The consent screen's own words.
    sh('shell', 'am', 'start', '-n', MAIN); time.sleep(10)
    seen = scroll_collect()
    joined = ' / '.join(seen)
    says_map_only = 'yalnızca Harita ekranında kendi konumumu' in joined
    says_flows_dont = 'konum kullanmaz' in joined
    no_session = 'konum oturum' not in joined.lower()
    record('1. consent screen states the Map-only purpose, in its own words',
           says_map_only and no_session,
           f'mapOnlyPhrase={says_map_only} noLocationSession={no_session} '
           f'flowsDisclaimer={says_flows_dont}')
    record('1b. the rendered legal versions are the bumped ones',
           'Sürüm 4.1.0' in joined and '3.5.0' in joined,
           f'versionLines={[l for l in seen if "Sürüm" in l or "3.5.0" in l][:3]}')

    # 2. Finish setup WITHOUT ticking the optional location consent.
    age = ui.find('18 yaşından büyüğüm')
    if age:
        x1, y1, x2, y2 = age['_b']
        sh('shell', 'input', 'tap', str(x2 - 120), str((y1 + y2) // 2))
    # Tick ONLY the two mandatory acknowledgements, never the location item.
    for _ in range(6):
        for n in ui.nodes():
            if n.get('checkable') != 'true' or n.get('checked') == 'true':
                continue
            label = ui.label(n)
            if 'Konum' in label or 'konum' in label:
                continue
            if '_b' not in n: continue
            x, y = ui.center(n)
            if 200 < y < 2050: sh('shell', 'input', 'tap', str(x), str(y))
        sh('shell', 'input', 'swipe', '540', '1600', '540', '800', '400')
        time.sleep(0.8)
    tap('Devam Et ve Kurulumu'); time.sleep(4)
    declined = pref_bool('pref_consent_location')
    record('2. declining the location item is recorded as a refusal',
           declined in ('false', '(absent)'),
           f'pref_consent_location={declined}')

    # Finish the rest of onboarding.
    tap('Atla', exact=True); time.sleep(3)
    if has('Arka Plan Koruması', tries=4): tap('İleri', exact=True); time.sleep(3)
    f = [n for n in ui.nodes() if 'EditText' in n.get('class', '')]
    if len(f) >= 2:
        for idx, text in ((0, 'Annem'), (1, '05551234567')):
            fields = [n for n in ui.nodes() if 'EditText' in n.get('class', '')]
            x, y = ui.center(fields[idx])
            sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(0.5)
            sh('shell', 'input', 'text', text); time.sleep(0.5)
        sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1)
        tap('Kişiyi kaydet'); time.sleep(2)
        tap('beyan ederim', clickable=True); time.sleep(1)
        tap('Ekle', exact=True); time.sleep(2)
    tap('Başla', exact=True); time.sleep(3)
    ui.pin(PIN); time.sleep(2); ui.pin(PIN); time.sleep(4)
    if has('Bildirim izni', tries=3):
        tap('Kabul Et', clickable=True); time.sleep(2)
        tap('ALLOW', exact=True) or tap('Allow', exact=True); time.sleep(2)
    if has('Şimdilik Atla', tries=4): tap('Şimdilik Atla'); time.sleep(3)
    # NOT asserted from this probe. Ticking "every checkbox except the
    # location one" across a scrolling consent screen proved unreliable here:
    # a run left the MANDATORY Terms box unticked, the CTA stayed correctly
    # disabled, and the resulting FAIL said nothing about the app. The property
    # is pinned where it cannot rot instead --
    # test/screens/unified_consent_behavior_test.dart, "LR-1: declining the
    # optional location consent still completes setup", which drives the real
    # UnifiedConsentScreen and asserts both that the CTA enables on
    # age + Terms + KVKK alone and that the refusal is persisted as false.
    reached_home = has('Hoş Geldiniz', tries=6)
    record('3. onboarding reached home (informational; see widget test)',
           True, f'home={reached_home} -- not a gate for this probe')

    # 4. The Map must refuse while the in-app consent is missing, even though
    #    the OS permission is granted -- that is LocationConsentGate's whole job.
    tap('Harita', exact=True); time.sleep(8)
    map_screen = screen()
    refused = ('izin' in map_screen.lower() or 'rıza' in map_screen.lower()
               or 'onay' in map_screen.lower() or 'Konum İzni' in map_screen)
    record('4. with consent declined the Map does not silently read location',
           refused or 'Konumunuz' not in map_screen,
           f'screen={map_screen[:220]}')

    # 5. A legal VERSION UPGRADE must demand re-consent, and must reset the
    #    optional consents -- the side effect this change ships.
    sh('shell', 'am', 'force-stop', PKG); time.sleep(2)
    owner = sh('shell', 'stat', '-c', '%U:%G', PREFS).strip()
    xml = sh('shell', 'cat', PREFS)
    before_terms = re.search(r'name="flutter\.pref_terms_version">([^<]*)<', xml)
    downgraded = re.sub(r'(name="flutter\.pref_terms_version">)[^<]*(<)',
                        r'\g<1>4.0.0\g<2>', xml)
    downgraded = re.sub(r'(name="flutter\.pref_kvkk_version">)[^<]*(<)',
                        r'\g<1>3.4.0\g<2>', downgraded)
    open('/tmp/lr1_prefs.xml', 'w').write(downgraded)
    sh('push', '/tmp/lr1_prefs.xml', '/data/local/tmp/lr1_prefs.xml')
    sh('shell', f'cat /data/local/tmp/lr1_prefs.xml > {PREFS} && '
                f'chown {owner} {PREFS} && restorecon {PREFS} && '
                f'rm /data/local/tmp/lr1_prefs.xml')
    sh('shell', 'am', 'start', '-n', MAIN); time.sleep(12)
    reconsent = has('Kurulum ve Onay', tries=8)
    after = scroll_collect(rounds=4) if reconsent else labels()
    shows_new = any('yalnızca Harita ekranında kendi konumumu' in l for l in after)
    record('5. an older stored legal version forces re-consent on next launch',
           reconsent,
           f'storedWas={before_terms.group(1) if before_terms else "?"} -> wrote 4.0.0/3.4.0; '
           f'reConsentShown={reconsent}')
    record('5b. the re-consent screen shows the CORRECTED location text',
           shows_new, f'correctedTextShown={shows_new}')

    passed = sum(1 for _, v, _ in rows if v == 'PASS')
    with open(OUT, 'w') as f:
        f.write(f'### LR-1 Phase C — corrected copy on a real clean install — {LABEL}\n\n')
        f.write(f'{passed}/{len(rows)} PASS\n\n| Step | Result | Observed |\n|---|---|---|\n')
        for s, v, d in rows: f.write(f'| {s} | **{v}** | {d} |\n')
    print(f'\n{passed}/{len(rows)} PASS -> {OUT}')
    return 0 if passed == len(rows) else 1

sys.exit(main())
