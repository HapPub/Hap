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
        if p.returncode and result.get('stage')=='jdk-version':
            # Controlled native-launcher diagnostic: fixed public archive, no Java
            # option environment, and no credentials in the version-only command.
            import hashlib, urllib.request, zipfile
            archive=Path(td)/'diagnostic.zip'
            urllib.request.urlretrieve('https://github.com/ibmruntimes/semeru17-binaries/releases/download/jdk-17.0.20.10/ibm-semeru-open-jdk_x64_windows_17.0.20.10.zip',archive)
            assert hashlib.sha256(archive.read_bytes()).hexdigest()=='6af6f222e11134032ec469d00b9f052b76abc28029c6c319bc86582c0f33ff2e'
            diagnostic=home/'diagnostic'
            with zipfile.ZipFile(archive) as z:z.extractall(diagnostic)
            java=next(diagnostic.rglob('bin/java.exe'))
            clean=dict(env)
            for key in ('JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','JDK_JAVA_OPTIONS'):clean.pop(key,None)
            api={'__name__':'native_jdk_diagnostic'}
            source=Path(__file__).resolve().parents[1]/'tools/host'
            exec((source/'common.py').read_text()+'\n'+(source/'windows_sdk.py').read_text(),api)
            for label,program in [('long',java),('short',api['windows_java_path'](java))]:
                probe=subprocess.run([str(program),'-version'],env=clean,capture_output=True,timeout=20)
                print(json.dumps({'jdkDiagnostic':label,'path':str(program),'exit':probe.returncode,'stdout':probe.stdout.decode('utf-8','replace'),'stderr':probe.stderr.decode('utf-8','replace')}),flush=True)
        assert p.returncode==0 and result['ok'],(p.returncode,result,p.stderr)
        assert result['nativeToolsVerified'] and result['verificationLevel']=='native-probe'
        assert result['target']=='windows-amd64' and not result['activated'] and not result['shellStartupChanged']
        assert Path(result['finalRoot'],'env.ps1').exists()
        return result
    first=install('17',allow_path_rejection=True)
    unicode_result='native-compile-run-verified' if first else 'preflight-rejected-no-compatible-short-name'
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
