#!/usr/bin/env python3
"""Exercise the CLI in an isolated HOME, using pinned completion-marker fixtures.
Real archive SHA rejection is covered by the package installer transaction tests.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix='hap-toolchain-get-') as td:
    home = Path(td)
    env = dict(os.environ, HOME=td)
    root = home / '.hap/toolchains'
    def run(*args, success=True):
        p = subprocess.run([binary, 'get', 'cangjie', *args], env=env, text=True, capture_output=True)
        data = json.loads(p.stdout)
        assert (p.returncode == 0) == success, (p.returncode, data, p.stderr)
        assert data['ok'] == success, data
        return data
    plan = run('--version', 'sts', '--plan')
    assert not root.exists(), 'plan wrote files'
    assert plan['sdk']['assetVersion'] == '1.1.3'
    assert plan['stdx']['assetVersion'] == '1.1.3.1'
    run('--version', 'sts', '--version=1.1.3', '--plan', success=False)
    run('--version=', '--plan', success=False)
    run('--version=1.1.3', '--target=macos-amd64', '--plan', success=False)
    sdk = Path(plan['sdk']['finalRoot'])
    stdx = Path(plan['stdx']['finalRoot'])
    platform = 'darwin_aarch64_cjnative' if plan['sdk']['target'] == 'macos-arm64' else {
        'linux-amd64': 'linux_x86_64_cjnative', 'linux-arm64': 'linux_aarch64_cjnative'
    }[plan['sdk']['target']]
    for part, dst in [('sdk', sdk), ('stdx', stdx)]:
        dst.mkdir(parents=True)
        # The existing completion-marker format is version + hash on separate lines.
        (dst / '.hap-complete').write_text(plan[part]['assetVersion'] + '\n' + plan[part]['sha256'] + '\n')
    (sdk / 'cangjie/bin').mkdir(parents=True)
    (sdk / 'cangjie/tools/bin').mkdir(parents=True)
    (sdk / 'cangjie/envsetup.sh').write_text('exit 99 # vendor setup must not execute during activation\n')
    cjc = sdk / 'cangjie/bin/cjc'
    cjc.write_text('#!/bin/sh\nif [ "$1" = --version ]; then echo 1.1.3; exit 0; fi\nprintf "#!/bin/sh\\nexit 0\\n" > "$3"\nchmod +x "$3"\n')
    cjc.chmod(0o755)
    cjpm = sdk / 'cangjie/tools/bin/cjpm'
    cjpm.write_text('#!/bin/sh\necho 1.1.3\n')
    cjpm.chmod(0o755)
    active = home / '.hap/env.sh'
    active.write_text('# previous selection\n')
    # SDK success nested inside a stdx failure must still exit nonzero.
    failed = run('--version=sts', success=False)
    assert failed['status'] == 'stdx-install-failed', failed
    assert active.read_text() == '# previous selection\n'
    for mode in ['static', 'dynamic']:
        (stdx / platform / mode / 'stdx').mkdir(parents=True)
    (home / 'zshrc-source').write_text('# personal config\n')
    (home / '.zshrc').symlink_to(home / 'zshrc-source')
    (home / '.bash_profile').write_text('# login config\n')
    installed = run('--version=1.1.3')
    assert installed['activated']
    assert 'CANGJIE_STDX_PATH_DYNAMIC' in active.read_text()
    assert (home / '.zshrc.hap-backup').read_text() == '# personal config\n'
    assert (home / '.zshrc').is_symlink(), 'dotfile symlink replaced'
    assert 'HapCLI' in (home / '.bash_profile').read_text()
    rc = (home / '.zshrc').read_text()
    run('--version=sts')
    assert (home / '.zshrc').read_text() == rc, 'duplicate activation hook'
    old_env = active.read_text()
    cjc.write_text('#!/bin/sh\nexit 19\n')
    failed = run('--version=sts', success=False)
    assert failed['status'] == 'toolchain-smoke-failed', failed
    assert active.read_text() == old_env, 'failed smoke changed selection'
    installed = run('--version=sts', '--no-activate')
    assert installed['status'] == 'installed' and not installed['activated']
    assert active.read_text() == old_env
    assert not (root / '.toolchain-get-lock').exists()
print('cangjie toolchain get integration tests passed')
