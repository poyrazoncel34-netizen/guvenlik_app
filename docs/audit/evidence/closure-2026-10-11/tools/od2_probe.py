#!/usr/bin/env python3
"""OD-2 fresh-install runtime proof on the REAL app (closure 2026-10-11).

usage: ANDROID_SERIAL=<serial> od2_probe.py <apk> <label> <out.md>

Walks the sequence the owner decision asks for, on a clean install, with the
exact-alarm special access LEFT AT ITS ANDROID DEFAULT (denied on API 33+):

  onboarding -> does the "Arka Plan Koruması" step appear and say it is off?
  -> tap the CTA -> does Android open THIS package's own alarms screen?
  -> come back without granting -> still off? -> finish onboarding -> does the
  home card refuse to claim "Kurulum tamam"? -> grant -> reopen -> does it read
  FULLY READY? -> arm a real Check-In -> are the exact alarms really there?
  -> revoke -> are they gone, is the stale READY gone, is the session degraded?

Nothing is asserted from a return value: every state is read back from the
device (appops, dumpsys alarm, the native session record, the rendered UI).
"""
import os, re, subprocess, sys, time
TOOLS = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', '..', 'chaos-2026-10-08', 'tools',
)
sys.path.insert(0, os.path.normpath(TOOLS))
APK, LABEL, OUT = sys.argv[1:4]
# runtime_matrix parses sys.argv at import time (apk, pkg, label, out).
sys.argv = [sys.argv[0], APK, 'com.poyrazoncel.korubeni', LABEL, '/dev/null']
import ui
import runtime_matrix as rm

PKG = 'com.poyrazoncel.korubeni'
MAIN = f'{PKG}/com.poyrazoncel.korubeni.MainActivity'
SESSION = f'/data/user_de/0/{PKG}/shared_prefs/korubeni_emergency_session_v1.xml'
PIN = '2468'
rows = []

def sh(*a, timeout=240):
    return subprocess.run([ui.ADB, *a], capture_output=True, text=True,
                          encoding='utf-8', errors='replace', timeout=timeout).stdout

def labels(): return [ui.label(n) for n in ui.nodes()]
def has(text, tries=8, wait=1.0):
    for _ in range(tries):
        if any(text in l for l in labels()): return True
        time.sleep(wait)
    return False
def tap(text, exact=False, clickable=False, tries=5):
    for _ in range(tries):
        if ui.tap(text, exact=exact, clickable=clickable): return True
        time.sleep(1)
    return False
def record(step, ok, detail=''):
    rows.append((step, 'PASS' if ok else 'FAIL',
                 str(detail).replace('|', '/').replace('\n', ' ')[:300]))
    print(f'{step}: {"PASS" if ok else "FAIL"} {str(detail)[:170]}', flush=True)

def sdk(): return int(sh('shell', 'getprop', 'ro.build.version.sdk').strip() or 0)
def appops_exact():
    return (sh('shell', 'cmd', 'appops', 'get', PKG, 'SCHEDULE_EXACT_ALARM').strip()
            or '(empty)')
def granted(): return 'allow' in appops_exact().lower()
def focus():
    m = re.search(r'mCurrentFocus=Window\{[^ ]+ \S+ ([^}]*)\}',
                  sh('shell', 'dumpsys', 'window'))
    return m.group(1) if m else '?'
def exact_alarm_count():
    """(session alarms, of which exact) from `dumpsys alarm`.

    Block-aware on purpose. The tag and the window are on DIFFERENT lines:

        tag=*walarm*:com.poyrazoncel.korubeni.EMERGENCY_SESSION_DISPATCH
        type=ELAPSED_WAKEUP origWhen=+29m33s window=+23m3s702ms ...

    so a per-line grep for 'window=0' matches nothing and reports 0 exact
    alarms whatever the real state is -- which is exactly what an earlier
    version of this probe did. A window of 0 is how AlarmManager records an
    exact alarm; a non-zero window is the inexact backup this app always
    schedules alongside it.
    """
    lines = sh('shell', 'dumpsys', 'alarm').splitlines()
    tag = re.compile(r'tag=\*walarm\*:' + re.escape(PKG) +
                     r'\.EMERGENCY_SESSION_(?:GRACE|DISPATCH|PRE_WARNING)')
    total = exact = 0
    in_history = False
    for i, line in enumerate(lines):
        if re.search(r'App Alarm history|Past-due|LazyAlarmStore stats', line):
            in_history = True
        if in_history:
            continue
        if not tag.search(line):
            continue
        total += 1
        # How far below the tag `window=` sits is version-dependent: API 36
        # puts it on the next line, API 29 on the one after that. Scan forward
        # to the end of this alarm's block instead of assuming an offset -- the
        # assumption cost a false "0 exact alarms" on API 29.
        for nxt in lines[i + 1:i + 5]:
            if tag.search(nxt) or 'operation=' in nxt:
                break
            m = re.search(r'\bwindow=(\S+)', nxt)
            if m:
                if m.group(1) == '0':
                    exact += 1
                break
    return total, exact

def revoke_reason_logged():
    """Android's own record that it deleted the exact alarms on revoke."""
    return 'exact_alarm_permission_revoked' in sh('shell', 'dumpsys', 'alarm')
def session_state():
    m = re.search(r'name="session_long_lifecycleState">(\w+)<',
                  sh('shell', 'cat', SESSION))
    return m.group(1) if m else 'none'
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
def back(): sh('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(3)

def foreground_package():
    m = re.search(r'mCurrentFocus=Window\{[^ ]+ \S+ ([^}/]*)',
                  sh('shell', 'dumpsys', 'window'))
    return m.group(1) if m else '?'

def wait_for_app_ui(timeout_s=90):
    """Block until this app is foreground AND has drawn something tappable.

    Returning from the system Settings screen can RESTART the app, and on a
    slower image (API 35 here: no GMS) it takes many seconds to come back --
    reappearing at onboarding page 1, having lost its place. A fixed sleep was
    not enough: one run spent 25 attempts tapping a button that had not been
    drawn yet, then reported six cascading FAILs that said nothing about the
    app. Wait for the UI to exist instead of guessing how long it needs.
    """
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if PKG in foreground_package():
            drawn = [l for l in labels() if l.strip()]
            if drawn and any(n.get('clickable') == 'true' for n in ui.nodes()):
                time.sleep(2)
                return True
        else:
            sh('shell', 'am', 'start', '-n', MAIN)
        time.sleep(3)
    return False

def scroll_collect(down=True, rounds=3):
    """Labels across a scroll: a step's content can sit under the fold."""
    seen = set(labels())
    a, b = ('1500', '900') if down else ('900', '1500')
    for _ in range(rounds):
        sh('shell', 'input', 'swipe', '540', a, '540', b, '300'); time.sleep(1)
        seen.update(labels())
    return seen

def consent_and_carousel():
    sh('shell', 'am', 'start', '-n', MAIN); time.sleep(9)
    if not has('Kurulum ve Onay', tries=12): return False
    age = ui.find('18 yaşından büyüğüm')
    if age:
        x1, y1, x2, y2 = age['_b']
        sh('shell', 'input', 'tap', str(x2 - 120), str((y1 + y2) // 2))
    for _ in range(5):
        for n in ui.nodes():
            if n.get('checkable') == 'true' and n.get('checked') != 'true' and '_b' in n:
                x, y = ui.center(n)
                if 200 < y < 2050: sh('shell', 'input', 'tap', str(x), str(y))
        sh('shell', 'input', 'swipe', '540', '1600', '540', '800', '400'); time.sleep(0.8)
    tap('Devam Et ve Kurulumu'); time.sleep(4)
    return True

def complete_onboarding():
    """Remaining steps (contact + PIN) to reach Home."""
    # After a Settings round-trip the app can reappear at page 1, so allow a
    # full walk of the carousel rather than the two or three steps that suffice
    # when the flow was never interrupted.
    wait_for_app_ui()
    for _ in range(10):
        if has('Acil kişinizi ekleyin', tries=2): break
        tap('İleri', exact=True, tries=3); time.sleep(2.5)
    if not has('Acil kişinizi ekleyin', tries=5): return False
    for idx, text in ((0, 'Annem'), (1, '05551234567')):
        fields = [n for n in ui.nodes() if 'EditText' in n.get('class', '')]
        if len(fields) <= idx: return False
        x, y = ui.center(fields[idx])
        sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(0.6)
        sh('shell', 'input', 'text', text); time.sleep(0.6)
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
    return has('Hoş Geldiniz', tries=8)

def background_note_shown():
    """The home card renders this note only while backgroundAlertReady is false.

    A precise observable for the ONE capability OD-2 is about. The card's
    headline also counts location and contacts, so "Kurulum tamam" alone cannot
    tell you whether the exact-alarm chip specifically went green.
    """
    for _ in range(5):
        if any('zamanlayıcılar gecikebilir' in l for l in labels()): return True
        sh('shell', 'input', 'swipe', '540', '700', '540', '1700', '300'); time.sleep(1.2)
    return False

def home_headline():
    """The readiness card's headline, scrolled into view if necessary."""
    for _ in range(5):
        found = [l for l in labels()
                 if 'Kurulum' in l or 'Hazırlık durumu' in l]
        if found: return ' / '.join(found)[:200]
        sh('shell', 'input', 'swipe', '540', '700', '540', '1700', '300'); time.sleep(1.5)
    return '(headline not found) ' + ' / '.join(labels()[:4])[:160]

def start_check_in():
    for _ in range(6):
        if tap('Kontrol Noktası', tries=1): break
        sh('shell', 'input', 'swipe', '540', '1700', '540', '600', '400'); time.sleep(1.2)
    else:
        return False
    time.sleep(4)
    tap('30 dk', tries=3); time.sleep(3)
    if has('Bilgilendirme', tries=4): tap('Anladım, devam et', tries=4)
    time.sleep(9)
    return True

def main():
    prep()
    api = sdk()
    sh('uninstall', PKG)
    sh('install', '-r', '-t', APK, timeout=900)
    # The two runtime permissions onboarding needs -- and DELIBERATELY NOT
    # SCHEDULE_EXACT_ALARM, which is the whole point of OD-2.
    for p in ('CALL_PHONE', 'POST_NOTIFICATIONS',
              'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'):
        sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')

    record(f'1-3. clean install, exact-alarm access at Android default (API {api})',
           not granted() if api >= 31 else True,
           f'appops={appops_exact()}')

    if not consent_and_carousel():
        record('onboarding reachable', False, ' / '.join(labels()[:4]))
        return finish()

    # 4. 'Atla' must land ON the new step, not past it.
    tap('Atla', exact=True); time.sleep(5)
    on_step = has('Arka Plan Koruması', tries=6)
    says_off = any('Alarm ve hatırlatıcı erişimi kapalı.' in l for l in labels())
    has_cta = any('Arka plan korumasını aç' in l for l in labels())
    if api >= 31:
        # NOT asserted here: the body paragraph and the skip note. Both are
        # rendered (screenshot) and both ARE in Flutter's semantics tree, but
        # `uiautomator dump` omits them on API 36, so checking them from this
        # probe would report a defect that does not exist. They are asserted
        # against the semantics tree itself in
        # test/screens/od2_background_protection_step_test.dart
        # ("TalkBack reads the whole step, explanation included").
        record('4. Skip lands on a visible "Arka Plan Koruması" step that says it is OFF',
               on_step and says_off and has_cta,
               f'onStep={on_step} saysOff={says_off} cta={has_cta}')
    else:
        record(f'4. API {api}: no such access exists, step reports it as ON (no regression)',
               on_step and not has_cta,
               f'onStep={on_step} cta={has_cta} '
               f'lines={[l for l in labels() if "Alarm ve" in l or "Arka plan" in l]}')

    if api >= 31:
        # 5-6. CTA opens THIS package's own alarms screen, not the generic list.
        before_focus = focus()
        tap('Arka plan korumasını aç'); time.sleep(7)
        after_focus = focus()
        settings_screen = ' / '.join(l for l in labels() if l.strip())[:300]
        left_app = PKG not in after_focus and after_focus != before_focus
        is_settings = 'settings' in after_focus.lower()
        names_app = 'KoruBeni' in settings_screen
        record('5-6. CTA opens the system alarms-and-reminders screen FOR THIS APP',
               left_app and is_settings and names_app,
               f'focus {before_focus} -> {after_focus} :: {settings_screen}')

        # 7. Come back WITHOUT granting.
        back()
        wait_for_app_ui()
        if has('Uygulama kilidi', tries=2): ui.pin(PIN); time.sleep(3)
        record('7. returning without granting leaves the access off',
               not granted(),
               f'appops={appops_exact()} backOnStep={has("Arka Plan Koruması", tries=3)}')
    else:
        record(f'5-7. API {api} has no exact-alarm special access to request',
               True, 'skipped by OS')

    # 8a. The step must not have blocked completion -- it is skippable.
    finished = complete_onboarding()
    record('8a. the background step did not block onboarding completion',
           finished, f'reachedHome={finished}')

    if api >= 31:
        # 8b. With the access still denied, home must NOT claim readiness.
        headline = home_headline()
        note = background_note_shown()
        record('8b. with the access still off, home does not claim readiness',
               not granted() and 'Kurulum tamam' not in headline and note,
               f'appops={appops_exact()} headline={headline} backgroundNoteShown={note}')

        # 9-11. Grant it. The system toggle's layout differs per OEM and API, so
        # the grant is written through appops -- the SAME app-op bit the toggle
        # writes -- and that substitution is recorded here rather than implied.
        sh('shell', 'cmd', 'appops', 'set', PKG, 'SCHEDULE_EXACT_ALARM', 'allow')
        record('9-11. access granted (via appops: the same bit the system toggle writes)',
               granted(), f'appops={appops_exact()}')

        # 12-13. The app must notice on its own next start/resume.
        sh('shell', 'am', 'force-stop', PKG)
        open_app(); time.sleep(4)
        headline = home_headline()
        note = background_note_shown()
        record('12-13. after returning, readiness reads FULLY READY',
               'Kurulum tamam' in headline and not note,
               f'headline={headline} backgroundNoteShown={note}')
    else:
        record(f'8b-13. API {api}: nothing to grant', True, 'skipped by OS')

    # 14-16. Arm a REAL session and prove the exact alarms exist.
    rm.inject_pro()
    for p in ('CALL_PHONE', 'POST_NOTIFICATIONS',
              'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'):
        sh('shell', 'pm', 'grant', PKG, f'android.permission.{p}')
    if api >= 31:
        sh('shell', 'cmd', 'appops', 'set', PKG, 'SCHEDULE_EXACT_ALARM', 'allow')
    open_app(); time.sleep(3)
    opened = start_check_in()
    state = session_state()
    total, exact = exact_alarm_count()
    record('14-16. a real Check-In arms natively and its exact alarms exist',
           opened and state == 'armed' and exact > 0,
           f'opened={opened} native={state} pending={total} exact(window=0)={exact}')

    if api >= 31:
        # 17-19. Revoke while the session is live.
        sh('shell', 'cmd', 'appops', 'set', PKG, 'SCHEDULE_EXACT_ALARM', 'deny')
        time.sleep(5)
        after_total, after_exact = exact_alarm_count()
        logged = revoke_reason_logged()
        record('17-19. revoking the access removes the exact alarms',
               after_exact < exact and after_exact == 0 and logged,
               f'exact {exact} -> {after_exact} (session alarms {total} -> {after_total}) '
               f'native={session_state()} androidLoggedReason={logged}')

        # 20-21. No stale READY on reopen.
        open_app(); time.sleep(5)
        headline = home_headline()
        record('20-21. reopening after a revoke shows no stale READY',
               'Kurulum tamam' not in headline, f'headline={headline}')

        # 22. The live session must warn rather than look fully protected.
        opened2 = False
        for _ in range(6):
            if tap('Kontrol Noktası', tries=1): opened2 = True; break
            sh('shell', 'input', 'swipe', '540', '1700', '540', '600', '400'); time.sleep(1.2)
        time.sleep(6)
        screen = ' / '.join(l for l in labels() if l.strip())
        warned = any(k in screen for k in (
            'Arka plan koruması', 'arka plan korumasını', 'gecikebilir',
            'Sınırlı', 'sınırlı',
        ))
        record('22. the live session shows a degraded warning, not full protection',
               opened2 and warned, f'opened={opened2} screen={screen[:240]}')

    return finish()

def finish():
    passed = sum(1 for _, v, _ in rows if v == 'PASS')
    with open(OUT, 'w') as f:
        f.write(f'### OD-2 fresh-install runtime proof — {LABEL}\n\n')
        f.write(f'{passed}/{len(rows)} PASS\n\n')
        f.write('| Step | Result | Observed |\n|---|---|---|\n')
        for s, v, d in rows: f.write(f'| {s} | **{v}** | {d} |\n')
    print(f'\n{passed}/{len(rows)} PASS -> {OUT}')
    return 0 if passed == len(rows) else 1

sys.exit(main())
