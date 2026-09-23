#!/usr/bin/env python3
"""Real Windows Semeru archive installation, Java compilation and cache replay."""
import json, os, subprocess, sys, tempfile
from pathlib import Path
assert os.name=='nt','Windows-only acceptance'
binary=str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix='hap-windows-jdk-') as td:
    home=Path(td)/'user 中文 space';home.mkdir()
    env=dict(os.environ,HOME=str(home),USERPROFILE=str(home))
    def install(version, allow_path_rejection=False):
        p=subprocess.run([binary,'get','jdk','--provider','semeru','--version',version,'--no-activate'],
            env=env,capture_output=True,text=True,errors='replace',timeout=900)
        result=json.loads(p.stdout)
        if allow_path_rejection and result.get('status')=='jdk-path-encoding-unsupported':
            assert p.returncode!=0 and result['stage']=='jdk-path-preflight' and result['nextAction']
            assert not (home/'.hap').exists(), 'rejected path wrote installation files'
            return None
        assert p.returncode==0 and result['ok'],(p.returncode,result,p.stderr)
        assert result['nativeToolsVerified'] and result['verificationLevel']=='native-probe'
        assert result['target']=='windows-amd64' and not result['activated'] and not result['shellStartupChanged']
        assert Path(result['finalRoot'],'env.ps1').exists()
        return result
    first=install('17',allow_path_rejection=True)
    unicode_result='native-compile-run-verified' if first else 'preflight-rejected-unsupported-encoding'
    if first is None:
        home=Path(td)/'user space';home.mkdir()
        env.update(HOME=str(home),USERPROFILE=str(home))
        first=install('17')
    assert first['checksumVerified'] and not first['cacheHit']
    cached=install(first['resolvedVersion']);assert cached['cacheHit']
    assert cached['sha256']==first['sha256'] and cached['finalRoot']==first['finalRoot']
    assert not (home/'.hap/env-jdk.ps1').exists()
    print(json.dumps({'test':'real-windows-semeru-install','version':first['resolvedVersion'],
        'sha256':first['sha256'],'observedVersion':first['observedVersion'],'nativeCompileRun':True,'cacheReplay':True,'unicodePath':unicode_result}))
