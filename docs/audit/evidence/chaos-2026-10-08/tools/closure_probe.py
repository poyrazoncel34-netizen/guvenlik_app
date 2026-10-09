#!/usr/bin/env python3
"""Shared setup for closure runtime probes: reuses the matrix helpers.

usage: ANDROID_SERIAL=<serial> closure_probe.py setup <apk>
       ANDROID_SERIAL=<serial> closure_probe.py <step> ...
Prints what the screen shows; every probe is recorded in the ledger by hand
with the installed build's sha1 + lastUpdateTime.
"""
import os, re, sys, time
_args = sys.argv[1:]
sys.argv = [sys.argv[0], _args[1] if len(_args) > 1 else 'x.apk',
            'com.poyrazoncel.korubeni', 'probe', '/dev/null']
sys.path.insert(0, os.path.dirname(__file__))
import runtime_matrix as rm
import ui

PKG = rm.PKG

def fingerprint():
    out = rm.sh('shell', 'dumpsys', 'package', PKG)
    m = re.search(r'lastUpdateTime=(\S+ \S+)', out)
    return m.group(1) if m else '?'

def screen():
    return ' / '.join(l for l in rm.labels() if l.strip())[:900]

def setup(apk):
    rm.sh('uninstall', PKG)
    print('install:', rm.sh('install', apk, timeout=300).strip()[-40:])
    print('lastUpdateTime', fingerprint())
    rm.onboarding(); rm.inject_pro(); rm.grant_all(); rm.open_app()
    print('home:', rm.home())

if __name__ == '__main__':
    step = _args[0]
    if step == 'setup': setup(_args[1])
    elif step == 'screen': print(screen())
    elif step == 'fingerprint': print(fingerprint())
    elif step == 'panic':
        rm.home(); ui.panic(); time.sleep(float(_args[1]) if len(_args) > 1 else 2.5)
        if rm.has('Anladım, devam et', tries=1):
            rm.tap('Anladım, devam et'); time.sleep(2); ui.panic(); time.sleep(2.5)
        print(screen())
    elif step == 'cancel': rm.cancel_countdown('panic', 'probe cancel'); print(rm.rows[-1])
    elif step == 'tap': print(rm.tap(_args[1], exact='--exact' in _args)); time.sleep(2); print(screen())
    elif step == 'state': print(rm.state(_args[1]))
