#!/usr/bin/env python3
"""Native CLI transaction tests using checksum-bound archives and vendor-command fixtures.
These are integration regressions, not proof of upstream assets or cross-host execution.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import zipfile

BINARY = str(Path(sys.argv[1]).resolve())


def script(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    path.chmod(0o755)


def archive_tree(tree, archive):
    if archive.suffix == '.zip':
        with zipfile.ZipFile(archive, 'w') as bundle:
            for path in sorted(tree.rglob('*')):
                bundle.write(path, str(path.relative_to(tree)))
    else:
        with tarfile.open(archive, 'w:gz') as bundle:
            for path in sorted(tree.iterdir()):
                bundle.add(path, arcname=path.name)
    return hashlib.sha256(archive.read_bytes()).hexdigest()


with tempfile.TemporaryDirectory(prefix='hap-sdk-get-') as temporary:
    tmp = Path(temporary)
    home = tmp / 'home'; home.mkdir()
    fixture = tmp / 'jdk-fixture'
    script(fixture / 'jdk/bin/java', '''#!/bin/sh
if [ "$1" = -version ]; then echo 'openjdk version "17.0.20"' >&2; else printf hap-sdk-ok; fi
''')
    script(fixture / 'jdk/bin/javac', '#!/bin/sh\nexit 0\n')
    (fixture / 'jdk/release').write_text('JAVA_VERSION="17.0.20"\nIMPLEMENTOR="IBM Corporation"\n')
    jdk_archive = tmp / 'jdk.tar.gz'; jdk_sha = archive_tree(fixture, jdk_archive)
    active = home / '.hap/env.sh'
    env = dict(os.environ, HOME=str(home))
    count = 0

    def run(subject, *args, ok=True, process_env=None):
        global count
        result = subprocess.run([BINARY, 'get', subject, *args], env=process_env or env,
                                text=True, capture_output=True, timeout=60)
        try:
            data = json.loads(result.stdout)
        except Exception:
            raise AssertionError((result.returncode, result.stdout, result.stderr))
        assert (result.returncode == 0) == ok and data['ok'] == ok, (data, result.stderr)
        count += 1
        return data

    def local_jdk(*args, **kwargs):
        return run('jdk', '--version', '17', '--archive', str(jdk_archive), '--sha256', jdk_sha, *args, **kwargs)

    for subject in ['jdk', 'semeru', 'android', 'ohos', 'openharmony', 'harmonyos']:
        planned = run(subject, '--plan')
        assert planned['status'] == 'planned' and not planned['catalogActionTaken']
    assert not (home / '.hap').exists(), 'plan wrote to HOME'
    for options in [('--version', '../17'), ('--version', '17', '--version=21'),
                    ('--plan=true',), ('--provider', 'unknown'), ('--profile', 'unknown'),
                    ('--bogus', 'x'), ('--archive', str(jdk_archive)),
                    ('--url', 'http://example.invalid/jdk.zip', '--sha256', jdk_sha),
                    ('--install-root', '/usr/local/hap'), ('--version', '')]:
        run('jdk', *options, '--plan', ok=False)
    run('android', '--version', 'latest', '--plan', ok=False)
    run('android', ok=False)  # no acceptance, before download or writes
    run('harmonyos', ok=False)
    assert not (home / '.hap').exists()
    run('jdk', '--target', 'windows-amd64', ok=False)
    local_jdk('--no-activate')
    assert not active.exists()
    # Shell configuration symlinks survive. Existing provider block is retained.
    active.write_text('# existing Cangjie\nexport CANGJIE_HOME=/preserved\n')
    (home / 'zshrc-source').write_text('# user config\n')
    (home / '.zshrc').symlink_to(home / 'zshrc-source')
    installed = local_jdk()
    assert installed['cacheHit'] and installed['activated']
    assert installed['observedVersion'] == '17.0.20'
    assert 'CANGJIE_HOME=/preserved' in active.read_text() and 'JAVA_HOME' in active.read_text()
    assert (home / '.zshrc').is_symlink()
    assert (home / '.zshrc.hap-backup').read_text() == '# user config\n'
    old = active.read_text(); old_rc = (home / '.zshrc').read_text()
    local_jdk()
    assert active.read_text() == old and (home / '.zshrc').read_text() == old_rc
    # A cached receipt cannot turn a broken toolchain into success.
    jdk_home = Path(installed['finalRoot']) / 'payload/jdk'
    script(jdk_home / 'bin/javac', '#!/bin/sh\nexit 19\n')
    local_jdk(ok=False)
    assert active.read_text() == old
    script(jdk_home / 'bin/javac', '#!/bin/sh\nexit 0\n')
    run('jdk', '--version', '21', '--archive', str(jdk_archive), '--sha256', jdk_sha, ok=False)
    assert active.read_text() == old
    run('jdk', '--version', '17', '--archive', str(jdk_archive), '--sha256', 'a' * 64, ok=False)
    assert active.read_text() == old
    # Symlinked private-looking roots resolving outside private storage fail closed.
    escaped = home / '.hap/escape'; escaped.symlink_to('/usr/local')
    local_jdk('--install-root', str(escaped / 'hap-test'), ok=False)
    # Tar traversal, special files, link chains, and zip symlinks never escape.
    for case in ['traversal', 'link-chain', 'fifo']:
        bad = tmp / (case + '.tar.gz')
        with tarfile.open(bad, 'w:gz') as bundle:
            if case == 'traversal':
                member = tarfile.TarInfo('../escape'); member.size = 1; bundle.addfile(member, io.BytesIO(b'x'))
            elif case == 'fifo':
                member = tarfile.TarInfo('fifo'); member.type = tarfile.FIFOTYPE; bundle.addfile(member)
            else:
                for name, target in [('top/a', '..'), ('top/x', 'a/../../escape')]:
                    member = tarfile.TarInfo(name); member.type = tarfile.SYMTYPE; member.linkname = target; bundle.addfile(member)
        sha = hashlib.sha256(bad.read_bytes()).hexdigest()
        run('jdk', '--version', '17', '--archive', str(bad), '--sha256', sha, ok=False)
        assert active.read_text() == old
    bad_zip = tmp / 'links.zip'
    with zipfile.ZipFile(bad_zip, 'w') as bundle:
        member = zipfile.ZipInfo('link'); member.create_system = 3; member.external_attr = 0o120777 << 16
        bundle.writestr(member, '/tmp/escape')
    run('jdk', '--version', '17', '--archive', str(bad_zip), '--sha256', hashlib.sha256(bad_zip.read_bytes()).hexdigest(), ok=False)
    # A legal relative JDK link is accepted.
    (fixture / 'jdk/lib').mkdir()
    (fixture / 'jdk/lib/java-link').symlink_to('../bin/java')
    linked_archive = tmp / 'linked.tar.gz'; linked_sha = archive_tree(fixture, linked_archive)
    linked = run('semeru', '--version', '17', '--archive', str(linked_archive), '--sha256', linked_sha)
    assert linked['activated']
    # Exercise GitHub discovery, exact release binding, digest authority and transfer.
    catalog = tmp / 'release.json'
    release_url = 'https://github.com/ibmruntimes/semeru17-binaries/releases/download/jdk-17.0.20.10/ibm-semeru-open-jdk_aarch64_mac_17.0.20.10.tar.gz'
    target = installed['target']
    arch = 'aarch64' if target.endswith('arm64') else 'x64'
    host = 'mac' if target.startswith('macos-') else 'linux'
    name = f'ibm-semeru-open-jdk_{arch}_{host}_17.0.20.10.tar.gz'
    release_url = 'https://github.com/ibmruntimes/semeru17-binaries/releases/download/jdk-17.0.20.10/' + name
    metadata = {'tag_name': 'jdk-17.0.20.10', 'draft': False, 'prerelease': False, 'assets': [
        {'name': name + '.json', 'browser_download_url': release_url + '.json'},
        {'name': name, 'uploader': {'login': 'vendor'}, 'digest': 'sha256:' + jdk_sha, 'browser_download_url': release_url}]}
    catalog.write_text(json.dumps(metadata))
    fake_bin = tmp / 'commands'
    script(fake_bin / 'curl', '#!/usr/bin/env python3\nimport sys,shutil\nfrom pathlib import Path\na=sys.argv[1:]\nif "--output" in a: shutil.copyfile(' + repr(str(jdk_archive)) + ',a[a.index("--output")+1])\nelse: print(Path(' + repr(str(catalog)) + ').read_text())\n')
    fake_env = dict(env, PATH=str(fake_bin) + os.pathsep + env['PATH'])
    discovered = run('jdk', '--provider', 'semeru', '--version', '17', '--no-activate', process_env=fake_env)
    assert discovered['resolvedVersion'] == 'jdk-17.0.20.10' and discovered['sha256'] == jdk_sha
    metadata['assets'][1]['browser_download_url'] = 'https://example.invalid/other.tar.gz'
    catalog.write_text(json.dumps(metadata))
    run('jdk', '--version', '17', process_env=fake_env, ok=False)
    metadata['assets'][1]['browser_download_url'] = release_url
    metadata['prerelease'] = True
    catalog.write_text(json.dumps(metadata))
    run('jdk', '--version', '17', process_env=fake_env, ok=False)
    # Native OpenHarmony is delivered as nested component zips.
    native_fixture = tmp / 'native-fixture'
    native = native_fixture / 'native'
    (native / 'sysroot').mkdir(parents=True)
    (native / 'build/cmake').mkdir(parents=True)
    (native / 'build/cmake/ohos.toolchain.cmake').write_text('# fixture\n')
    (native / 'oh-uni-package.json').write_text(json.dumps({'apiVersion': '20', 'version': '6.0.0.47'}))
    script(native / 'llvm/bin/clang', '''#!/bin/sh
if [ "$1" = --version ]; then echo clang; exit 0; fi
while [ "$#" -gt 0 ]; do if [ "$1" = -o ]; then shift; touch "$1"; fi; shift; done
''')
    script(native_fixture / 'toolchains/hdc', '#!/bin/sh\nexit 0\n')
    outer = tmp / 'outer'; outer.mkdir()
    archive_tree(native_fixture, outer / 'native-darwin-linux.zip')
    ohos_archive = tmp / 'ohos.tar.gz'; ohos_sha = archive_tree(outer, ohos_archive)
    ohos = run('ohos', '--profile', 'native', '--archive', str(ohos_archive), '--sha256', ohos_sha)
    assert ohos['apiVersion'] == '20' and ohos['nativeToolsVerified']
    assert '/components/20/native' in active.read_text()
    assert '# hap:begin:jdk' in active.read_text()
    # Android manager fixture validates fixed argv and creates requested components.
    android_fixture = tmp / 'android-fixture'
    manager = android_fixture / 'cmdline-tools/bin/sdkmanager'
    script(manager, '''#!/usr/bin/env python3
import os,sys
from pathlib import Path
args=sys.argv[1:]
assert Path(os.environ['JAVA_HOME'],'bin/java').exists()
root=Path(next((a.split('=',1)[1] for a in args if a.startswith('--sdk_root=')), os.environ.get('ANDROID_HOME','.')))
if '--version' in args: print('20.0'); sys.exit(0)
if '--licenses' in args: sys.exit(0)
for package in args:
 if package=='platform-tools': paths=['platform-tools/adb']
 elif package.startswith('platforms;'): paths=[package.replace(';','/')+'/android.jar']
 elif package.startswith('build-tools;'): paths=[package.replace(';','/')+'/aapt2']
 elif package.startswith('ndk;'): paths=[package.replace(';','/')+'/build/cmake/android.toolchain.cmake',package.replace(';','/')+'/toolchains/llvm/bin/clang']
 elif package.startswith('cmake;'): paths=[package.replace(';','/')+'/bin/cmake']
 else: continue
 for name in paths:
  path=root/name; path.parent.mkdir(parents=True,exist_ok=True); path.write_text('#!/bin/sh\\nexit 0\\n'); path.chmod(0o755)
''')
    android_archive = tmp / 'android.zip'; android_sha = archive_tree(android_fixture, android_archive)
    android = run('android', '--archive', str(android_archive), '--sha256', android_sha,
                  '--java-home', str(jdk_home), '--accept-licenses', '--ndk', '26.3.11579264', '--cmake', '3.22.1')
    assert android['installed'] and android['apiVersion'] == '36'
    selected = active.read_text()
    assert all('# hap:begin:' + key in selected for key in ['jdk', 'ohos', 'android'])
    # Harmony CLT validates bundled tools, private Java/Node, SDK and native compiler.
    harmony_fixture = tmp / 'harmony-fixture'
    import shutil
    shutil.copytree(fixture / 'jdk', harmony_fixture / 'clt/tool/jdk', symlinks=False)
    shutil.copytree(native, harmony_fixture / 'clt/sdk/default/openharmony/native')
    for tool in ['node', 'ohpm', 'hvigorw', 'hdc']:
        script(harmony_fixture / 'clt/tool' / tool / 'bin' / tool, '#!/bin/sh\nexit 0\n')
    harmony_archive = tmp / 'harmony.zip'; harmony_sha = archive_tree(harmony_fixture, harmony_archive)
    harmony = run('harmonyos', '--version', 'test-release', '--archive', str(harmony_archive), '--sha256', harmony_sha, '--accept-licenses')
    assert harmony['installed'] and harmony['observedVersion'] == '6.0.0.47'
    assert '/clt/sdk\"' not in active.read_text() # shell values are quoted
    assert '/clt/sdk\'' in active.read_text()
    assert all('# hap:begin:' + key in active.read_text() for key in ['jdk', 'ohos', 'android', 'harmonyos'])
    replay = run('harmonyos', '--version', 'test-release', '--archive', str(harmony_archive), '--sha256', harmony_sha, '--accept-licenses')
    assert replay['cacheHit']
    replay = run('android', '--archive', str(android_archive), '--sha256', android_sha,
                 '--java-home', str(jdk_home), '--accept-licenses', '--ndk', '26.3.11579264', '--cmake', '3.22.1')
    assert replay['cacheHit']
    # Sourcing repeatedly does not grow PATH; wrappers bind private Java.
    shell = subprocess.run(['sh', '-c', '. "$HOME/.hap/env.sh"; first="$PATH"; . "$HOME/.hap/env.sh"; test "$first" = "$PATH"; sdkmanager --version; hvigorw --version'], env=env, text=True, capture_output=True)
    assert shell.returncode == 0, shell.stderr
    # Preserve a pre-existing interrupted staging directory for review.
    marker_root = home / '.hap/toolchains/jdk/17' / installed['target'] / ('full-' + 'b' * 12 + '.staging')
    marker_root.mkdir(parents=True)
    (marker_root / 'owner-evidence').write_text('preserve')
    run('jdk', '--version', '17', '--archive', str(jdk_archive), '--sha256', 'b' * 64, ok=False)
    assert (marker_root / 'owner-evidence').read_text() == 'preserve'
    shutil.rmtree(marker_root)
    assert not list((home / '.hap/toolchains').glob('.*-install-lock'))
    assert not list((home / '.hap/toolchains').rglob('*.staging'))
    print(f'{count} SDK toolchain CLI integration cases passed')
