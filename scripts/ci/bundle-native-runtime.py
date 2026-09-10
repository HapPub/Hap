#!/usr/bin/env python3
"""Carry vendor runtime files required by older native Cangjie builds."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dependencies(path):
    lines = subprocess.check_output(['otool', '-L', str(path)], text=True).splitlines()[1:]
    return [line.strip().split(' (', 1)[0] for line in lines]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', required=True)
    parser.add_argument('--sdk-root', type=Path, required=True)
    parser.add_argument('--binary', type=Path, required=True)
    args = parser.parse_args()
    binary = args.binary.resolve()
    sdk = args.sdk_root.resolve()
    files = {}
    if args.target.startswith('darwin-'):
        platform = 'darwin_aarch64_cjnative' if args.target.endswith('arm64') else 'darwin_x86_64_cjnative'
        pending = [binary]
        while pending:
            for dep in dependencies(pending.pop()):
                if dep.startswith(('/usr/lib/', '/System/Library/')):
                    continue
                if not dep.startswith('@rpath/'):
                    raise SystemExit(f'unsupported non-system runtime dependency: {dep}')
                name = Path(dep).name
                if name in files:
                    continue
                candidates = [sdk / 'runtime/lib' / platform / name, sdk / 'lib' / platform / name]
                source = next((path for path in candidates if path.is_file()), None)
                if source is None:
                    raise SystemExit(f'missing SDK runtime library: {name}')
                files[name] = source
                pending.append(source)
        if files:
            identity = hashlib.sha256(''.join(name + digest(path) for name, path in sorted(files.items())).encode()).hexdigest()[:24]
            destination = binary.parent / '.hap-runtime' / identity
            destination.mkdir(parents=True)
            for name, path in files.items():
                shutil.copy2(path, destination / name)
            shutil.copy2(sdk / 'LICENSE', destination / 'LICENSE-CANGJIE')
            subprocess.run(['install_name_tool', '-add_rpath', '@loader_path/.hap-runtime/' + identity, str(binary)], check=True)
            subprocess.run(['codesign', '--force', '--sign', '-', str(binary)], check=True)
    elif args.target == 'windows-amd64':
        # Windows resolves imported DLLs beside the executable. Keep the official
        # target runtime together; do not depend on the build SDK remaining in PATH.
        runtime = sdk / 'runtime/lib/windows_x86_64_cjnative'
        for path in sorted(runtime.glob('*.dll')):
            shutil.copy2(path, binary.parent / path.name)
            files[path.name] = path
        if files:
            shutil.copy2(sdk / 'LICENSE', binary.parent / 'LICENSE-CANGJIE')
    print(f'Bundled {len(files)} native runtime libraries for {args.target}')


if __name__ == '__main__':
    main()
