#!/usr/bin/env python3
"""Replay official-release bootstrap with a deterministic HTTPS transport fixture."""
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tarfile
import tempfile

root = Path(__file__).resolve().parents[1]
hapup = root / 'release/hapup.sh'
with tempfile.TemporaryDirectory(prefix="hapup-install-'quoted-") as tmp:
    work = Path(tmp)
    home = work / 'home'
    home.mkdir()
    mock = work / 'mock'
    mock.mkdir()
    payload = work / 'payload'
    payload.mkdir()
    (payload / 'hap').write_text('#!/bin/sh\necho "HapCLI fixture"\n')
    (payload / 'hap').chmod(0o755)
    archive = work / 'hap.tar.gz'
    with tarfile.open(archive, 'w:gz') as tf:
        tf.add(payload / 'hap', arcname='bin/hap')
    target = ('darwin' if platform.system() == 'Darwin' else 'linux') + '-' + ('arm64' if platform.machine() in ['arm64', 'aarch64'] else 'amd64')
    base = 'https://github.com/HapPub/Hap/releases/download/v0.2.0'
    manifest = work / 'manifest.v0.json'
    manifest.write_text(json.dumps({'downloadableAssets': [{
        'id': 'hap-' + target, 'kind': 'flagship-binary', 'target': target,
        'url': base + '/hap.tar.gz', 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
        'downloadable': True
    }]}, indent=2))
    checksum = work / 'manifest.v0.json.sha256'
    checksum.write_text(hashlib.sha256(manifest.read_bytes()).hexdigest() + '  manifest.v0.json\n')
    (work / 'latest.json').write_text(json.dumps({'tag_name': 'v0.2.0'}))
    (mock / 'curl').write_text('''#!/usr/bin/env python3
import os, pathlib, shutil, sys
args=sys.argv[1:]
url=next(x for x in args if x.startswith('https://'))
assert url.startswith('https://github.com/HapPub/Hap/releases/download/v0.2.0/') or url == 'https://api.github.com/repos/HapPub/Hap/releases/latest', url
name='latest.json' if url.endswith('/latest') else url.rsplit('/',1)[1]
shutil.copyfile(pathlib.Path(os.environ['FIXTURE'])/name, args[args.index('-o')+1])
''')
    (mock / 'curl').chmod(0o755)
    env = dict(os.environ, HOME=str(home), PATH=str(mock) + ':' + os.environ['PATH'], FIXTURE=str(work))
    def run(*args, success=True):
        p = subprocess.run(['sh', str(hapup), *args], env=env, text=True, capture_output=True)
        assert (p.returncode == 0) == success, (p.returncode, p.stdout, p.stderr)
        return p
    (home / 'zshrc-source').write_text('# personal config\n')
    (home / '.zshrc').symlink_to(home / 'zshrc-source')
    (home / '.bash_profile').write_text('# login config\n')
    run()  # no-argument bootstrap resolves latest once, then uses the pinned tag
    installed = home / '.local/bin/hap'
    assert installed.is_file() and (home / '.local/bin/hapup').is_file()
    assert (home / '.zshrc.hap-backup').read_text() == '# personal config\n'
    assert (home / '.zshrc').is_symlink(), 'dotfile symlink replaced'
    assert 'HapCLI' in (home / '.bash_profile').read_text()
    rc = (home / '.zshrc').read_text()
    shell = subprocess.run(['sh', '-c', '. "$HOME/.profile"; command -v hap'], env=env, text=True, capture_output=True, check=True)
    assert Path(shell.stdout.strip()).resolve() == installed.resolve(), shell
    run('install', '--version', '0.2.0')
    assert (home / '.zshrc').read_text() == rc
    run('install', '--version=../../bad', success=False)
    old = installed.read_bytes()
    manifest.write_text(manifest.read_text() + ' ')
    run('install', '--version=0.2.0', success=False)
    assert installed.read_bytes() == old
    assert (home / '.zshrc').read_text() == rc
print('hapup release install integration tests passed')
