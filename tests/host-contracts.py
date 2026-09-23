#!/usr/bin/env python3
"""Cross-host command outcomes, private roots, diagnostics and lock ownership."""
import json, os, subprocess, sys, tempfile
from pathlib import Path

binary=str(Path(sys.argv[1]).resolve())
source=Path(__file__).resolve().parents[1]/'tools/host'
api={'__name__':'hap_contract_tests'}
exec((source/'common.py').read_text()+'\n'+(source/'ssh_pair.py').read_text(),api)
with tempfile.TemporaryDirectory(prefix='hap-contracts-') as td:
    root=Path(td).resolve(); home=root/'home';home.mkdir(mode=0o700)
    env=dict(os.environ,HOME=str(home),USERPROFILE=str(home))
    failures=[['env','apply'],['env','print'],['get','cangjie-sdk','--target','linux-amd64','--legacy-plan'],
              ['get','cangjie-stdx','--legacy-plan'],['fetch','reviewed-recipe'],['graph','apply-normalize']]
    for args in failures:
        p=subprocess.run([binary,*args],env=env,capture_output=True,text=True,timeout=15)
        result=json.loads(p.stdout)
        assert result.get('ok') is False and p.returncode!=0,(args,p.returncode,result)
    assert not list(home.iterdir()),'invalid commands wrote to HOME'
    for args in [['get','cangjie','--version','sts','--target','linux-amd64','--no-activate','--plan'],['get','ssh','--plan']]:
        p=subprocess.run([binary,*args],env=env,capture_output=True,text=True,timeout=15)
        assert p.returncode==0,(args,p.stdout,p.stderr)
    assert not list(home.iterdir()),'plans wrote to HOME'
    # Native child failures retain only known codes, never arbitrary stderr or argv.
    secret='private-pairing-secret-do-not-log'
    try:
        api['command']([sys.executable,'-c','import sys;sys.stderr.write("port-in-use '+secret+'");sys.exit(4)'])
        raise AssertionError('child failure accepted')
    except api['HostCommandError'] as error:
        assert error.status=='port-in-use' and error.code==4 and secret not in str(error)
        assert error.next_action and error.retryable
    try:
        api['command']([sys.executable,'-c','import time;time.sleep(10)'],timeout=.1)
        raise AssertionError('timeout accepted')
    except api['HostCommandError'] as error:
        assert error.status=='command-timeout'
    with api['lock'](root,'.lock'):
        owner=json.loads((root/'.lock/owner.json').read_text())
        assert owner['pid']==os.getpid() and owner['createdAt']>0
        try:
            with api['lock'](root,'.lock'):raise AssertionError('concurrent lock accepted')
        except ValueError:pass
        assert (root/'.lock/owner.json').exists()
    assert not (root/'.lock').exists()
    if os.name!='nt':
        (root/'linked').symlink_to(home,target_is_directory=True)
        try:api['safe_root'](root/'linked/subdir');raise AssertionError('user symlink accepted')
        except ValueError:pass
    if sys.platform=='darwin':
        assert api['safe_root']('/tmp/hap-test')==Path('/private/tmp/hap-test')
    for part in (['space path','中文','percent%h'] if os.name=='nt' else ['space path','中文','percent%h','quote"path','back\\slash']):
        path=root/part/'known'
        parsed=subprocess.run([api['ssh_tool']('ssh'),'-G','-F','NUL' if os.name=='nt' else '/dev/null',
            '-o','UserKnownHostsFile='+api['ssh_config_path'](path),'127.0.0.1'],capture_output=True,text=True,timeout=10)
        assert parsed.returncode==0,(part,parsed.stderr)
        assert ('userknownhostsfile '+str(path)) in parsed.stdout,parsed.stdout
print('host contracts passed: failure exits, read-only plans, safe diagnostics, timeout, lock ownership and SSH path parsing')
