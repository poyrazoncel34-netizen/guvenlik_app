#!/usr/bin/env python3
"""Chaos-audit uiautomator helper (2026-10-08). ls | tap <q> [idx] | tapx <exact> | pin <digits> | panic."""
import subprocess, sys, re, time, os, html
ADB = os.path.expanduser('~/Library/Android/sdk/platform-tools/adb')
def sh(*a):
    return subprocess.run([ADB, *a], capture_output=True, text=True, encoding='utf-8', errors='replace').stdout
def dump():
    for _ in range(4):
        out = sh('exec-out', 'uiautomator', 'dump', '/dev/tty')
        if '<hierarchy' in out:
            return out[out.index('<hierarchy'):out.rindex('</hierarchy>') + 12]
        time.sleep(0.5)
    return ''
NODE = re.compile(r'<node ([^>]*?)/?>'); ATTR = re.compile(r'(\S+?)="(.*?)"')
def nodes(xml=None):
    xml = xml if xml is not None else dump(); res = []
    for m in NODE.finditer(xml):
        a = {k: html.unescape(v) for k, v in ATTR.findall(m.group(1))}
        b = re.findall(r'\d+', a.get('bounds', ''))
        if len(b) == 4: a['_b'] = tuple(map(int, b))
        res.append(a)
    return res
def label(n): return (n.get('text') or '') + ('|' + n['content-desc'] if n.get('content-desc') else '')
def find(q, idx=0, exact=False, clickable=False):
    hits = []
    for n in nodes():
        if '_b' not in n: continue
        if clickable and n.get('clickable') != 'true': continue
        ok = (q == n.get('text') or q == n.get('content-desc')) if exact else (q.lower() in label(n).lower())
        if ok: hits.append(n)
    return hits[idx] if len(hits) > idx else None
def center(n): x1, y1, x2, y2 = n['_b']; return (x1 + x2) // 2, (y1 + y2) // 2
def tap(q, idx=0, exact=False, clickable=False):
    n = find(q, idx, exact, clickable)
    if not n: print('NOTFOUND', q); return False
    x, y = center(n); sh('shell', 'input', 'tap', str(x), str(y)); print('TAP', q, x, y); return True
def pin(digits, delay=0.15):
    pos = {}
    for _ in range(8):
        pos = {}
        for n in nodes():
            d = n.get('content-desc') or n.get('text') or ''
            if d in list('0123456789') and '_b' in n and n.get('clickable') == 'true': pos.setdefault(d, center(n))
        if all(c in pos for c in digits): break
        time.sleep(0.6)
    for ch in digits:
        if ch not in pos: print('NOPAD', ch); return False
        x, y = pos[ch]; sh('shell', 'input', 'tap', str(x), str(y)); time.sleep(delay)
    print('PIN', digits); return True
def _sos():
    # 'Kilitli SOS butonu' while the offline Pro anchor is not loaded yet (Y-03)
    return find('Panik Butonu') or find('SOS butonu')
def panic(hold_ms=3600):
    n = _sos()
    for i in range(12):
        if n: break
        # first scroll towards the top, then towards the bottom
        a, b = ('700', '1700') if i < 4 else ('1400', '1000')
        sh('shell', 'input', 'swipe', '540', a, '540', b, '300'); time.sleep(0.7); n = _sos()
    if not n: print('NO_SOS'); return False
    x, y = center(n); sh('shell', 'input', 'swipe', str(x), str(y), str(x), str(y), str(hold_ms))
    print('PANIC_RELEASED', time.strftime('%H:%M:%S')); return True
if __name__ == '__main__':
    c = sys.argv[1]
    if c == 'ls':
        for n in nodes():
            l = label(n)
            if l.strip():
                f = ''.join(k for k, a in (('C', 'clickable'), ('K', 'checkable'), ('X', 'checked'), ('F', 'focused')) if n.get(a) == 'true')
                print(f"{l!r} {n.get('_b')} {f}")
    elif c == 'tap': tap(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 0)
    elif c == 'tapc': tap(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 0, clickable=True)
    elif c == 'tapx': tap(sys.argv[2], exact=True)
    elif c == 'pin': pin(sys.argv[2])
    elif c == 'panic': panic()
