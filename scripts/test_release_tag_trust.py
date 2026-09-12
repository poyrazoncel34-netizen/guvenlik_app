"""Synthetic disposable SSH tag fixture; no release tag/key or network changes."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

VERIFIER = Path(__file__).resolve().with_name('verify_release_tag.sh')

class TagTrustTest(unittest.TestCase):
    def test_clean_runner_trust_and_negative_controls(self):
        with tempfile.TemporaryDirectory(prefix='korubeni-tag-fixture-') as path:
            root = Path(path)
            env = {**os.environ, 'GIT_CONFIG_NOSYSTEM': '1',
                   'GIT_CONFIG_GLOBAL': str(root / 'empty-config')}
            def run(*args, check=True, extra=None):
                return subprocess.run(args, cwd=root, env={**env, **(extra or {})},
                                      text=True, capture_output=True, check=check)
            run('git', 'init', '-q')
            run('git', 'config', 'user.name', 'Synthetic fixture')
            run('git', 'config', 'user.email', 'fixture@example.invalid')
            run('git', 'commit', '--allow-empty', '-qm', 'fixture')
            for name in ('trusted', 'untrusted'):
                run('ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(root / name))
            run('git', '-c', 'gpg.format=ssh', '-c', f'user.signingkey={root / "trusted"}',
                'tag', '-s', 'synthetic-fixture', '-m', 'fixture only')
            base = {'RELEASE_TAG_GPG_PUBLIC_KEYS': '', 'RELEASE_TAG_SSH_ALLOWED_SIGNERS': ''}
            missing = run('bash', str(VERIFIER), 'synthetic-fixture', check=False, extra=base)
            self.assertNotEqual(missing.returncode, 0)
            for key, success in [('trusted', True), ('untrusted', False)]:
                allowed = 'fixture@example.invalid ' + (root / f'{key}.pub').read_text()
                result = run('bash', str(VERIFIER), 'synthetic-fixture', check=False,
                             extra={**base, 'RELEASE_TAG_SSH_ALLOWED_SIGNERS': allowed})
                self.assertEqual(result.returncode == 0, success, result.stderr)
            signed = run('git', 'cat-file', 'tag', 'refs/tags/synthetic-fixture').stdout
            corrupted = signed.replace('fixture only', 'altered text')
            obj = subprocess.run(['git', 'hash-object', '-t', 'tag', '-w', '--stdin'],
                                 cwd=root, env=env, input=corrupted, text=True,
                                 capture_output=True, check=True).stdout.strip()
            run('git', 'update-ref', 'refs/tags/tampered-fixture', obj)
            allowed = 'fixture@example.invalid ' + (root / 'trusted.pub').read_text()
            invalid = run('bash', str(VERIFIER), 'tampered-fixture', check=False,
                          extra={**base, 'RELEASE_TAG_SSH_ALLOWED_SIGNERS': allowed})
            self.assertNotEqual(invalid.returncode, 0)
            run('git', 'tag', '-a', 'unsigned-fixture', '-m', 'unsigned')
            self.assertNotEqual(run('bash', str(VERIFIER), 'unsigned-fixture',
                                    check=False, extra=base).returncode, 0)

if __name__ == '__main__':
    unittest.main()
