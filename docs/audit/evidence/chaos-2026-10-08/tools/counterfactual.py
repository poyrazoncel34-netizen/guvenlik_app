#!/usr/bin/env python3
"""Counterfactual mutation runner for the closure ledger.

Each mutant replaces one exact, unique snippet in a source file, runs the
named tests and must make them FAIL. The original bytes are restored after
every mutant and the restore is proven by hash, so a run can never leave a
mutant behind (see memory: mutasyon-kesinti-kalinti-mutant).

Usage: counterfactual.py SPEC.json LOG.txt
SPEC: [{"id", "file", "old", "new" | "edits": [[old, new], ...], "tests": [...],
        "kind": "flutter"|"gradle",
        optional "gradle_tests": "--tests X"}]
"""
import hashlib, json, subprocess, sys, time, pathlib

def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()

def head():
    return subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True,
                          text=True).stdout.strip()

def run_tests(m):
    if m.get('kind', 'flutter') == 'gradle':
        cmd = ['./gradlew', ':app:testPlayDebugUnitTest', '--offline']
        for t in m['tests']:
            cmd += ['--tests', t]
        r = subprocess.run(cmd, cwd='android', capture_output=True, text=True)
        failed = [l for l in (r.stdout + r.stderr).splitlines()
                  if ' > ' in l and l.rstrip().endswith('FAILED')]
        return r.returncode, '\n'.join(failed[:3]) or (r.stdout + r.stderr).strip().splitlines()[-1]
    else:
        r = subprocess.run(['flutter', 'test', '--no-pub', *m['tests']],
                           capture_output=True, text=True)
    tail = '\n'.join((r.stdout + r.stderr).strip().splitlines()[-3:])
    return r.returncode, tail

def main():
    spec = json.load(open(sys.argv[1]))
    log = open(sys.argv[2], 'a')
    def out(line):
        print(line); log.write(line + '\n'); log.flush()
    out(f'# counterfactual run {time.strftime("%Y-%m-%dT%H:%M:%S")} HEAD={head()}')
    survivors = 0
    for m in spec:
        path = pathlib.Path(m['file'])
        original = path.read_bytes()
        before = sha(path)
        text = original.decode()
        edits = m.get('edits') or [[m['old'], m['new']]]
        bad = [o for o, _ in edits if text.count(o) != 1]
        if bad:
            out(f"{m['id']}: SPEC-ERROR snippet count={text.count(bad[0])}")
            survivors += 1
            continue
        for o, n in edits:
            text = text.replace(o, n)
        try:
            path.write_text(text)
            mutated = sha(path)
            code, tail = run_tests(m)
        finally:
            path.write_bytes(original)
        restored = sha(path)
        assert restored == before, f'restore failed for {path}'
        verdict = 'KILLED' if code != 0 else 'SURVIVED'
        if code == 0:
            survivors += 1
        out(f"{m['id']}: {verdict} file={path} sha_orig={before[:16]} "
            f"sha_mut={mutated[:16]} restored={restored == before}")
        out('    ' + tail.replace('\n', '\n    '))
    code, tail = run_tests({'tests': sorted({t for m in spec if m.get('kind','flutter')=='flutter' for t in m['tests']})}) if any(m.get('kind','flutter')=='flutter' for m in spec) else (0, 'n/a')
    out(f'# baseline after restore: exit={code} :: {tail.splitlines()[-1] if tail else ""}')
    out(f'# survivors={survivors}')
    sys.exit(1 if survivors or code else 0)

if __name__ == '__main__':
    main()
