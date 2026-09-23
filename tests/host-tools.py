#!/usr/bin/env python3
"""Public-command transactions, hostile archives and real TLS enrollment tests."""
import base64
import concurrent.futures
import getpass
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time

binary=str(Path(sys.argv[1]).resolve())
count=0

def call(args,env,ok=True,input=None):
    global count
    p=subprocess.run([binary,*args],env=env,input=input,text=True,capture_output=True,timeout=30)
    d=json.loads(p.stdout)
    assert (p.returncode==0)==ok,(args[:3],p.returncode,d,p.stderr)
    assert d['ok']==ok,d
    count+=1;return d

def port():
    with socket.socket() as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]

with tempfile.TemporaryDirectory(prefix='hap-host-tests-') as td:
    root=Path(td).resolve();home=root/'home';home.mkdir(mode=0o700)
    env=dict(os.environ,HOME=str(home),USERPROFILE=str(home));env['PYTHONDONTWRITEBYTECODE']='1'
    for args in [['get','nsis','--version','3.12','--sha256','a'*64,'--plan'],['get','wix','--version','6.0','--sha256','b'*64,'--plan'],['get','ssh','--server','--plan']]:
        assert call(args,env)['status']=='planned'
    assert not (home/'.hap').exists()
    for args in [['get','nsis','--version','../evil','--sha256','a'*64,'--plan'],['get','nsis','--version','3.12','--sha256','BAD','--plan'],['get','ssh','--port','70000','--plan'],['ssh','conn','--evil']]:
        p=subprocess.run([binary,*args],env=env,text=True,capture_output=True);assert p.returncode!=0;count+=1
    pack=root/'pack';pack.mkdir()
    for name in ['COPYING','Stubs/x','Include/x','Contrib/x','Plugins/x']:
        p=pack/name;p.parent.mkdir(exist_ok=True,parents=True);p.write_text('fixture')
    exe=pack/('makensis.exe' if os.name=='nt' else 'makensis')
    if os.name=='nt':
        compiler_env=dict(env,HAP_TEST_COMPILER=str(exe))
        subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-Command',
            'Add-Type -TypeDefinition \'public class Entry { public static void Main() { System.Console.Write("v3.12"); } }\' -OutputAssembly $env:HAP_TEST_COMPILER -OutputType ConsoleApplication'],
            env=compiler_env,check=True,capture_output=True)
    else:
        exe.write_text('#!/bin/sh\nprintf v3.12\n');exe.chmod(0o755)
    import platform
    host={'Darwin':'darwin','Linux':'linux','Windows':'win32'}[platform.system()]+'-'+{'aarch64':'arm64','amd64':'x86_64'}.get(platform.machine().lower(),platform.machine().lower())
    def seal():
        files={p.relative_to(pack).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in pack.rglob('*') if p.is_file() and p.name!='engine.json'}
        (pack/'engine.json').write_text(json.dumps({'schema':'chui.installer-engine.v1','version':'3.12','host':host,'files':files}))
    def archive():
        path=root/'pack.tar.gz'
        with tarfile.open(path,'w:gz') as tar:
            for p in pack.iterdir():tar.add(p,arcname=p.name)
        return path,hashlib.sha256(path.read_bytes()).hexdigest()
    seal();archive_path,sha=archive();install=root/'中文 空格'/'engines'
    args=['get','nsis','--version','3.12','--archive',str(archive_path),'--sha256',sha,'--install-root',str(install)]
    r=call(args,env);assert r['inventoryVerified'] and not r['cacheHit']
    assert r['verifiedTargets']==[] and r['declaredTargets']==[] and r['verificationLevel']=='inventory+native-probe'
    r2=call(['get','nsis','--version','3.12','--sha256',sha,'--install-root',str(install),'--offline'],env);assert r2['cacheHit']
    call(['installer','inspect','--engine','nsis','--bundle',r['bundleRoot']],env)
    call(['installer','inspect','--engine','nsis','--bundle',r['bundleRoot'],'--version','3.1'],env,False)
    call(args[:args.index('--sha256')]+['--sha256','0'*64,'--install-root',str(install)],env,False)
    assert Path(r['bundleRoot']).is_dir()
    (Path(r['bundleRoot'])/'Include/x').write_text('tampered');call(args,env,False)
    for kind in ['traversal','symlink','hardlink','case','parent-file']:
        bad=root/(kind+'.tar.gz')
        with tarfile.open(bad,'w:gz') as tar:
            for name in (['A','a'] if kind=='case' else ['x','x/y'] if kind=='parent-file' else ['../escape'] if kind=='traversal' else ['evil']):
                info=tarfile.TarInfo(name)
                if kind in ['symlink','hardlink']:info.type=tarfile.SYMTYPE if kind=='symlink' else tarfile.LNKTYPE;info.linkname='../outside'
                else:info.size=1
                tar.addfile(info,io.BytesIO(b'x'))
        call(['get','nsis','--version','3.12','--archive',str(bad),'--sha256',hashlib.sha256(bad.read_bytes()).hexdigest(),'--install-root',str(install)],env,False)
    assert not list(install.glob('.stage-*')) and not (install/'.install-lock').exists()
    # Real TLS and SSH signatures with independent local homes. No system service changes.
    serverhome=root/'server';clienthome=root/'client'
    for h in [serverhome,clienthome]:h.mkdir(mode=0o700)
    se=dict(env,HOME=str(serverhome),USERPROFILE=str(serverhome),ProgramData=str(serverhome/'programdata'));ce=dict(env,HOME=str(clienthome),USERPROFILE=str(clienthome))
    privileged=['--allow-privileged'] if os.name=='nt' else []
    key=root/'hostkey'
    subprocess.run(['ssh-keygen','-q','-t','ed25519','-N','','-f',str(key)],check=True)
    pair_port=port()
    server=subprocess.Popen([binary,'ssh','--pair','--listen','127.0.0.1','--pair-port',str(pair_port),'--host-key',str(key)+'.pub','--show-code','--preauthorize','--ttl','30',*privileged],env=se,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
        first=json.loads(server.stdout.readline());assert first['status']=='pairing-listening',first
        code=first['code']
        data=json.loads(base64.urlsafe_b64decode(code[8:]+'='*(-len(code[8:])%4)))
        def encode(d):return 'hapssh1.'+base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip('=')
        expired=dict(data,expires=int(time.time())-1)
        call(['ssh','conn','--code-stdin','--no-connect'],ce,False,input=encode(expired)+'\n')
        wrong=dict(data,secret='0'*64)
        call(['ssh','conn','--code-stdin','--no-connect'],ce,False,input=encode(wrong)+'\n')
        # A different self-signed certificate must fail before the secret is sent.
        alt=root/'alt.pem';altkey=root/'alt.key'
        subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=wrong','-addext','subjectAltName=IP:127.0.0.1','-keyout',str(altkey),'-out',str(alt)],check=True,capture_output=True)
        import ssl
        pinwrong=dict(data,cert=base64.b64encode(ssl.PEM_cert_to_DER_cert(alt.read_text())).decode())
        call(['ssh','conn','--code-stdin','--no-connect'],ce,False,input=encode(pinwrong)+'\n')
        # Possession of the code alone cannot register a public key without its signature.
        api={'__name__':'hap_pair_test'}
        hostdir=Path(__file__).resolve().parents[1]/'tools/host'
        exec((hostdir/'common.py').read_text()+'\n'+(hostdir/'ssh_pair.py').read_text(),api)
        ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT);ctx.load_verify_locations(cadata=ssl.DER_cert_to_PEM_cert(base64.b64decode(data['cert'])))
        with socket.create_connection(('127.0.0.1',pair_port),timeout=5) as tcp:
            with ctx.wrap_socket(tcp,server_hostname='127.0.0.1') as conn:
                api['read_frame'](conn)
                pub=api['public_key']((root/'hostkey.pub').read_text())
                api['send_frame'](conn,{'session':data['id'],'secret':data['secret'],'publicKey':pub,'signature':base64.b64encode(b'invalid').decode()})
                assert conn.recv(1)==b''
        count+=1
        # Failed redemption has not consumed the code.
        def redeem():
            return subprocess.run([binary,'ssh','conn','--code-stdin','--save','lab','--no-connect'],env=ce,input=code+'\n',text=True,capture_output=True,timeout=20)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(lambda _:redeem(),range(2)))
        assert sum(p.returncode==0 for p in results)==1,[(p.returncode,p.stdout) for p in results]
        paired=json.loads(next(p.stdout for p in results if p.returncode==0));assert paired['pairReady'];count+=2
        rest=server.communicate(timeout=15);assert server.returncode==0,rest
        assert code not in rest[0]+rest[1] and data['secret'] not in rest[0]+rest[1]
        call(['ssh','conn','--code-stdin','--no-connect'],ce,False,input=code+'\n')
        peer=paired['peerId'];auth=serverhome/'programdata/ssh/administrators_authorized_keys' if os.name=='nt' else serverhome/'.ssh/authorized_keys';before=auth.read_text();assert 'hap-'+peer in before
        # Preserve an unrelated key while removing exact peer authorization.
        with auth.open('a') as f:f.write('# keep unrelated authorization\n# '+before.split('ssh-ed25519 ')[1].split()[0]+'\n')
        revoked=call(['ssh','revoke',peer],se);assert revoked['serverKeyRemoved']
        assert 'hap-'+peer not in auth.read_text() and '# keep unrelated' in auth.read_text()
        assert call(['ssh','peers'],se)['peers'][0]['status']=='revoked'
        call(['ssh','forget','lab'],ce)
        assert not (clienthome/'.hap/ssh/alias-lab.json').exists()
        assert not list((serverhome/'.hap/ssh').glob('.pair-*'))
    finally:
        if server.poll() is None:server.terminate();server.wait(timeout=10)
print('host tools:',count,'public-command checks passed; real TLS enrollment and server key removal verified')
