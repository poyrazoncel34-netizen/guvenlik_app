#!/usr/bin/env python3
"""Poll uiautomator; on the FIRST dump that shows the panic countdown pad
('saniye kaldı' + clickable digits), tap the PIN from that same dump."""
import sys, time; sys.path.insert(0, __import__('os').path.dirname(__file__)); import ui
pin = sys.argv[1] if len(sys.argv) > 1 else '2468'
t0 = time.time()
while time.time() - t0 < 15:
    ns = ui.nodes()
    if any('saniye kaldı' in ui.label(n) for n in ns):
        pos = {}
        for n in ns:
            d = n.get('content-desc') or n.get('text') or ''
            if d in list('0123456789') and '_b' in n and n.get('clickable') == 'true': pos.setdefault(d, ui.center(n))
        if all(c in pos for c in pin):
            cmd = ';'.join(f'input tap {pos[c][0]} {pos[c][1]}' for c in pin)
            ui.sh('shell', cmd); print('LIVEPIN', time.strftime('%H:%M:%S'), [ui.label(n) for n in ns if 'saniye kaldı' in ui.label(n)][0][:40]); sys.exit(0)
print('NOPAD'); sys.exit(1)
