#!/usr/bin/env python3
"""Replay routing, slow transfers, corrupt mirrors and authority boundaries."""
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tarfile
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='hapup-routes-') as tmp:
    work = Path(tmp)
    mock = work / 'mock'; mock.mkdir()
    home = work / 'home'; home.mkdir()
    binary = work / 'hap'; binary.write_text('#!/bin/sh\necho 0.3.0\n'); binary.chmod(0o755)
    archive = work / 'hap.tar.gz'
    with tarfile.open(archive, 'w:gz') as tf:
        tf.add(binary, arcname='bin/hap')
    target = ('darwin' if platform.system() == 'Darwin' else 'linux') + '-' + ('arm64' if platform.machine() in ['arm64', 'aarch64'] else 'amd64')
    base = 'https://github.com/HapPub/Hap/releases/download/v0.3.0'
    manifest = work / 'manifest.v0.json'
    manifest.write_text(json.dumps({'downloadableAssets': [{
        'id': 'hap-' + target, 'kind': 'flagship-binary', 'target': target,
        'url': base + '/hap.tar.gz', 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'downloadable': True
    }]}, indent=2))
    (work / 'manifest.v0.json.sha256').write_text(hashlib.sha256(manifest.read_bytes()).hexdigest() + '  manifest.v0.json\n')
    (work / 'latest.json').write_text('{"tag_name":"v0.3.0"}')
    log = work / 'calls.jsonl'
    (mock / 'curl').write_text('''#!/usr/bin/env python3
import json, os, pathlib, shutil, sys
args=sys.argv[1:]; url=next(x for x in args if x.startswith('https://'))
route='ghfast' if url.startswith('https://ghfast.top/') else 'ghproxy' if url.startswith('https://ghproxy.link/') else 'direct'
probe='-fsSLI' in args or '--range' in args; mode=os.environ['MODE']
with open(os.environ['CALLS'],'a') as f: f.write(json.dumps({'route':route,'url':url,'probe':probe,'args':args})+'\\n')
assert args[0]=='--disable' and args[args.index('--proto-redir')+1]=='=https'
if probe:
 if mode=='head-fail': sys.exit(22)
 if '--range' in args:
  assert args[args.index('--max-filesize')+1]=='65536'
  speed={'direct':'10000','ghfast':'90000','ghproxy':'50000'}
  if mode=='throughput': speed['ghproxy']='999999'
  print(speed[route])
 else: print({'direct':'0.300','ghfast':'0.010','ghproxy':'0.100'}[route])
 sys.exit(0)
assert '--speed-limit' in args and '--speed-time' in args and '--retry' not in args
name='latest.json' if url.endswith('/latest') else url.rsplit('/',1)[1]
if name.endswith('.sha256') or name=='latest.json': assert route=='direct', 'authority was proxied'
is_archive=name=='hap.tar.gz'
if is_archive and (mode=='all-fail' or mode=='slow' and route=='ghfast'): sys.exit(28)
out=pathlib.Path(args[args.index('-o')+1])
if is_archive and mode=='corrupt' and route=='ghfast': out.write_bytes(b'wrong archive'); sys.exit(0)
shutil.copyfile(pathlib.Path(os.environ['FIXTURE'])/name,out)
''')
    (mock / 'curl').chmod(0o755)
    env = dict(os.environ, HOME=str(home), PATH=str(mock)+':'+os.environ['PATH'], FIXTURE=str(work), CALLS=str(log), HAPUP_REGION='auto', HAPUP_ROUTE='auto')
    def run(mode, *args, success=True, env_extra=None):
        log.write_text('')
        p = subprocess.run(['sh', str(root/'release/hapup.sh'), 'install', '--no-path', *args],
                           env=dict(env, MODE=mode, **(env_extra or {})), capture_output=True, text=True)
        assert (p.returncode==0)==success, (mode,p.returncode,p.stdout,p.stderr)
        calls=[json.loads(line) for line in log.read_text().splitlines()]
        if success:
            receipt=json.loads((home/'.local/bin/hap-install-receipt.json').read_text())
            return receipt['download'],calls
        return p,calls
    d,c=run('normal'); assert d=={'region':'auto','route':'ghfast','attempts':1}
    assert {x['route'] for x in c if x['probe']}=={'direct','ghfast','ghproxy'}
    d,c=run('throughput'); assert d['route']=='ghproxy', 'archive throughput must beat metadata latency'
    d,c=run('slow'); assert d['route']=='ghproxy' and d['attempts']==2
    d,c=run('corrupt'); assert d['route']=='ghproxy' and d['attempts']==2
    d,c=run('head-fail'); assert d['route']=='direct', d
    d,c=run('normal','--region','global'); assert d['route']=='direct' and not any(x['probe'] for x in c)
    d,c=run('normal','--region=zh-cn'); assert d['region']=='zh-cn' and d['route']=='ghfast'
    d,c=run('normal','--route','direct'); assert d['route']=='direct' and not any(x['probe'] for x in c)
    d,c=run('normal','--route=ghproxy'); assert d['route']=='ghproxy' and not any(x['probe'] for x in c)
    old=(home/'.local/bin/hap').read_bytes()
    p,c=run('slow','--route=ghfast',success=False)
    assert not any(x['route']!='ghfast' for x in c if x['url'].endswith('hap.tar.gz'))
    run('all-fail',success=False); assert (home/'.local/bin/hap').read_bytes()==old
    for args in [('--route=nope',),('--region','bad'),('--region=global','--route=ghproxy')]:
        p,c=run('normal',*args,success=False); assert not c
    d,c=run('normal','--region=auto',env_extra={'HAPUP_REGION':'global'})
    assert d['route']=='ghfast', 'CLI must override environment'
    # Unknown hosts and credential-shaped query URLs must never be accelerated.
    env['MODE']='normal'
    for url in ['https://example.invalid/hap.tar.gz',base+'/hap.tar.gz?token=private']:
        # The fake transport will reject the unknown basename after recording;
        # only its routing is being inspected here.
        log.write_text('')
        subprocess.run(['sh',str(root/'release/hapup.sh'),'install-flagship','--asset',url,
                        '--sha256',hashlib.sha256(archive.read_bytes()).hexdigest(),
                        '--install-dir',str(home/'.local/bin'),'--review-token','fixture'],env=env,capture_output=True)
        assert all(json.loads(x)['route']=='direct' for x in log.read_text().splitlines())
    # A corrupt authoritative checksum blocks installation across every route.
    (work/'manifest.v0.json.sha256').write_text('f'*64+'  manifest.v0.json\n')
    run('normal',success=False); assert (home/'.local/bin/hap').read_bytes()==old
print('hapup adaptive download tests passed: 18 routing, fallback and authority scenarios')
