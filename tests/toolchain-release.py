#!/usr/bin/env python3
"""Require complete native assets and matching compiler provenance per release."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {'darwin-arm64':'mac-aarch64','linux-amd64':'linux-x64',
           'linux-arm64':'linux-aarch64','windows-amd64':'windows-x64'}
VERSION = '0.3.0'
SHA = 'a' * 40


def write_json(path, data):
    path.write_text(json.dumps(data))


with tempfile.TemporaryDirectory(prefix='hap-toolchain-release-') as td:
    dist = Path(td)
    (dist/'hapup.sh').write_text('fixture')
    (dist/f'hap-{VERSION}-source.tar.gz').write_text('source fixture')
    for target, platform in TARGETS.items():
        archive = dist/f'hap-{VERSION}-{target}.{"zip" if target.startswith("windows") else "tar.gz"}'
        archive.write_text(target)
        write_json(dist/f'hap-{VERSION}-{target}.runtime-portability.json', {
            'schema':'happub-hap-native-runtime-portability-receipt-v1',
            'ok':True,'status':'sdk-independent-runtime-smoke-verified','target':target,'version':VERSION,
            'inheritedSdkEnvironment':False,'environmentMode':'empty-inherited-environment-with-minimal-os-baseline',
            'allowedEnvironmentVariables':['HOME','PATH'],
            'clearedEnvironmentVariables':['CANGJIE_HOME','CANGJIE_STDX_PATH','CJC_HOME','CJPM_HOME','LD_LIBRARY_PATH','DYLD_LIBRARY_PATH','LIBRARY_PATH','SDKROOT'],
            'archive':{'name':archive.name,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()},
            'binary':{'name':'hap.exe' if target.startswith('windows') else 'hap','sha256':'a'*64},
            'smoke':{'command':'hap version','expectedVersion':VERSION,'actualVersion':VERSION,'exitCode':0}})

    def provenance(sdk):
        for target, platform in TARGETS.items():
            write_json(dist/f'hap-{VERSION}-{target}.cangjie-sdk-resolution.json', {
                'schema':'happub-hapcli-cangjie-mirror-bootstrap-receipt-v1','status':'verified-and-installed',
                'sdkTag':sdk,'sdkPlatform':platform,'sdkName':f'cangjie-sdk-{platform}-{sdk}',
                'sdkUrl':'https://github.com/HapPub/CangjieSDK-Mirror/releases/download/'+sdk+'/fixture',
                'sdkSha256':'b'*64,'checksumAuthority':'mirror-computed-sha256','installRoot':'/runner/temporary/sdk'})

    def render(sdk, tag=None, ok=True):
        result = subprocess.run(['python3',str(ROOT/'scripts/ci/render-release-manifest.py'),
            '--dist',str(dist),'--version',VERSION,'--tag',tag or f'v{VERSION}-cangjie-{sdk}',
            '--repository','HapPub/Hap','--sdk-version',sdk,'--source-revision',SHA,
            '--output',str(dist/'manifest.json'),'--notes-output',str(dist/'notes.md')],capture_output=True,text=True)
        assert (result.returncode==0)==ok,(result.stdout,result.stderr)
        return json.loads((dist/'manifest.json').read_text()) if ok else None

    for sdk in ('1.0.5','1.1.3'):
        provenance(sdk)
        data=render(sdk)
        assert data['buildToolchain']['version']==sdk and data['sourceRevision']==SHA
        binaries=[a for a in data['downloadableAssets'] if a['kind']=='flagship-binary']
        assert {a['target'] for a in binaries}==set(TARGETS)
        assert next(a for a in binaries if a['target']=='windows-amd64')['name'].endswith('.zip')
        assert all('installRoot' not in p.read_text() for p in dist.glob('*.cangjie-sdk-resolution.json'))
    render('1.1.3',tag='v0.3.0-cangjie-1.0.5',ok=False)
    windows=dist/f'hap-{VERSION}-windows-amd64.zip'
    windows.rename(dist/'saved.zip');render('1.1.3',ok=False);(dist/'saved.zip').rename(windows)
    path=dist/f'hap-{VERSION}-windows-amd64.cangjie-sdk-resolution.json'
    data=json.loads(path.read_text());data['sdkTag']='1.0.5';write_json(path,data)
    render('1.1.3',ok=False)
    provenance('1.1.3')
    windows.write_text('tampered');render('1.1.3',ok=False)
print('dual-toolchain release contract tests passed: 2 positive, 4 rejection scenarios')
